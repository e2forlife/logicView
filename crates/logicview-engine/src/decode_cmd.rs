//! Decoder instances on a session.
//!
//! Sample decoders run after the capture settles, and again when one is added.
//! The EEPROM stack reads I2C annotations rather than the wires.

use std::collections::BTreeMap;
use std::sync::atomic::AtomicBool;

use logicview_decode::{
    catalog, export_csv, export_text, run, search_annotations, Annotation, DecodeRequest,
    DecoderSchema,
};

use super::{AnnotationRow, DecoderInfo, DecoderInst, Engine, EngineError, Slot};

impl Engine {
    /// Returns protocol schemas so clients can offer compatible analyzer inputs and output classes.
    pub async fn decoder_catalog(&self) -> Vec<DecoderSchema> {
        catalog()
    }

    /// Resolves channel and stack bindings, installs an analyzer, and refreshes session
    /// annotations.
    pub async fn add_decoder(
        &self,
        session: Option<&str>,
        protocol: &str,
        channels: &BTreeMap<String, String>,
        options: &BTreeMap<String, String>,
        region: Option<(u64, u64)>,
        stack_on: Option<&str>,
    ) -> Result<DecoderInfo, EngineError> {
        let schema = catalog()
            .into_iter()
            .find(|item| item.id == protocol)
            .ok_or_else(|| EngineError::Decode(format!("unknown decoder {protocol}")))?;
        let mut state = self.shared.state.lock().await;
        let id = self.resolve(&state, session)?;
        let slot = state.slot_mut(&id)?;
        let stack = if schema.stack_on.is_some() {
            Some(resolve_stack(slot, stack_on)?)
        } else if stack_on.is_some() {
            return Err(EngineError::Decode(format!(
                "{protocol} does not stack on another decoder"
            )));
        } else {
            None
        };
        let mut resolved = BTreeMap::new();
        for name in schema.channels {
            let spec = channels
                .get(*name)
                .ok_or_else(|| EngineError::Decode(format!("{protocol} needs a {name} channel")))?;
            resolved.insert((*name).to_string(), resolve_channel(slot, spec)?);
        }
        let instance_id = format!("{protocol}-{}", slot.next_decoder);
        slot.next_decoder += 1;
        slot.decoders.push(DecoderInst {
            id: instance_id.clone(),
            protocol: protocol.to_string(),
            channels: resolved.clone(),
            options: options.clone(),
            region,
            stack_on: stack.clone(),
        });
        rerun(slot);
        Ok(DecoderInfo {
            id: instance_id,
            protocol: protocol.to_string(),
            channels: resolved,
            options: options.clone(),
            stack_on: stack,
        })
    }

    /// Removes an analyzer and its direct dependents, then refreshes the remaining results.
    pub async fn remove_decoder(
        &self,
        session: Option<&str>,
        decoder_id: &str,
    ) -> Result<(), EngineError> {
        let mut state = self.shared.state.lock().await;
        let id = self.resolve(&state, session)?;
        let slot = state.slot_mut(&id)?;
        let before = slot.decoders.len();
        slot.decoders.retain(|decoder| {
            decoder.id != decoder_id && decoder.stack_on.as_deref() != Some(decoder_id)
        });
        if slot.decoders.len() == before {
            return Err(EngineError::Decode(format!("unknown decoder {decoder_id}")));
        }
        rerun(slot);
        Ok(())
    }

    /// Replaces analyzer bindings and options and reruns decoding on the current capture.
    pub async fn update_decoder(
        &self,
        session: Option<&str>,
        decoder_id: &str,
        channels: &BTreeMap<String, String>,
        options: &BTreeMap<String, String>,
        stack_on: Option<&str>,
    ) -> Result<DecoderInfo, EngineError> {
        let mut state = self.shared.state.lock().await;
        let id = self.resolve(&state, session)?;
        let slot = state.slot_mut(&id)?;
        let protocol = slot
            .decoders
            .iter()
            .find(|decoder| decoder.id == decoder_id)
            .map(|decoder| decoder.protocol.clone())
            .ok_or_else(|| EngineError::Decode(format!("unknown decoder {decoder_id}")))?;
        let schema = catalog()
            .into_iter()
            .find(|item| item.id == protocol)
            .ok_or_else(|| EngineError::Decode(format!("unknown decoder {protocol}")))?;
        let mut resolved = BTreeMap::new();
        for name in schema.channels {
            let spec = channels
                .get(*name)
                .ok_or_else(|| EngineError::Decode(format!("{protocol} needs a {name} channel")))?;
            resolved.insert((*name).to_string(), resolve_channel(slot, spec)?);
        }
        let stack = if schema.stack_on.is_some() {
            Some(if stack_on.is_some() {
                resolve_stack(slot, stack_on)?
            } else {
                slot.decoders
                    .iter()
                    .find(|decoder| decoder.id == decoder_id)
                    .and_then(|decoder| decoder.stack_on.clone())
                    .ok_or_else(|| EngineError::Decode(format!("unknown decoder {decoder_id}")))?
            })
        } else if stack_on.is_some() {
            return Err(EngineError::Decode(format!(
                "{protocol} does not stack on another decoder"
            )));
        } else {
            None
        };
        if let Some(decoder) = slot
            .decoders
            .iter_mut()
            .find(|decoder| decoder.id == decoder_id)
        {
            decoder.channels = resolved;
            decoder.options = options.clone();
            decoder.stack_on = stack;
        } else {
            return Err(EngineError::Decode(format!("unknown decoder {decoder_id}")));
        }
        rerun(slot);
        Ok(slot
            .decoders
            .iter()
            .find(|decoder| decoder.id == decoder_id)
            .map(info_of)
            .ok_or_else(|| EngineError::Decode(format!("unknown decoder {decoder_id}")))?)
    }

    /// Lists configured analyzer instances for the requested or selected session.
    pub async fn list_decoders(
        &self,
        session: Option<&str>,
    ) -> Result<Vec<DecoderInfo>, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, session)?;
        Ok(state.slot(&id)?.decoders.iter().map(info_of).collect())
    }

    /// Returns a bounded page of decoded events filtered by analyzer, time range, and search query.
    pub async fn read_annotations(
        &self,
        session: Option<&str>,
        decoder: Option<&str>,
        query: Option<&str>,
        start: Option<u64>,
        end: Option<u64>,
        offset: usize,
        limit: usize,
    ) -> Result<Vec<AnnotationRow>, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, session)?;
        let rows = filtered(state.slot(&id)?, decoder, query, start, end);
        let limit = limit.clamp(1, 5_000);
        Ok(rows.into_iter().skip(offset).take(limit).collect())
    }

    /// Returns the first page of annotation matches across the session's analyzers.
    pub async fn search_annotations(
        &self,
        session: Option<&str>,
        query: &str,
    ) -> Result<Vec<AnnotationRow>, EngineError> {
        self.read_annotations(session, None, Some(query), None, None, 0, 500)
            .await
    }

    /// Exports filtered decoded events as CSV or tab-separated text, grouped by analyzer.
    pub async fn export_annotations(
        &self,
        session: Option<&str>,
        format: &str,
        query: Option<&str>,
    ) -> Result<String, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, session)?;
        let rows = filtered(state.slot(&id)?, None, query, None, None);
        let mut out = String::new();
        let groups = group_rows(&rows);
        match format {
            "text" => {
                for (decoder, anns) in groups {
                    out.push_str(&export_text(&decoder, &anns));
                }
            }
            "csv" | "" => {
                let mut first = true;
                for (decoder, anns) in groups {
                    let csv = export_csv(&decoder, &anns);
                    if first {
                        out.push_str(&csv);
                        first = false;
                    } else if let Some(body) = csv.split_once('\n') {
                        out.push_str(body.1);
                    }
                }
                if first {
                    out.push_str("start_sample,end_sample,decoder,class,text,fields\n");
                }
            }
            other => {
                return Err(EngineError::Decode(format!(
                    "annotation export format {other} is not csv or text"
                )))
            }
        }
        Ok(out)
    }
}

/// Replaces session annotations by decoding the currently retained original samples.
pub(crate) fn rerun(slot: &mut Slot) {
    if slot.decoders.is_empty() {
        slot.annotations.clear();
        return;
    }
    let len = slot.session.store.len();
    let mut packed = Vec::with_capacity(slot.session.store.channel_count());
    for index in 0..slot.session.store.channel_count() {
        match slot.session.store.channel_bytes(index) {
            Ok(bytes) => packed.push(bytes.to_vec()),
            Err(_) => packed.push(Vec::new()),
        }
    }
    slot.annotations = decode_all(&slot.decoders, &packed, len);
}

/// Runs signal decoders before stacked decoders and merges their events into time order.
///
/// The current implementation treats a failed decoder run as an empty result,
/// so absent rows do not by themselves establish that the bus was inactive.
fn decode_all(decoders: &[DecoderInst], packed: &[Vec<u8>], len: u64) -> Vec<AnnotationRow> {
    let mut produced: BTreeMap<String, Vec<Annotation>> = BTreeMap::new();
    let mut rows = Vec::new();
    let mut order: Vec<usize> = (0..decoders.len())
        .filter(|index| decoders[*index].stack_on.is_none())
        .collect();
    order.extend((0..decoders.len()).filter(|index| decoders[*index].stack_on.is_some()));
    for index in order {
        let inst = &decoders[index];
        let lower = inst
            .stack_on
            .as_ref()
            .and_then(|parent| produced.get(parent))
            .cloned()
            .unwrap_or_default();
        let names: Vec<String> = inst.channels.keys().cloned().collect();
        let bytes: Vec<&[u8]> = inst
            .channels
            .values()
            .map(|channel| packed.get(*channel).map(Vec::as_slice).unwrap_or(&[]))
            .collect();
        let pairs: Vec<(&str, &[u8])> = names
            .iter()
            .zip(bytes.iter())
            .map(|(name, bytes)| (name.as_str(), *bytes))
            .collect();
        let options: Vec<(String, String)> = inst
            .options
            .iter()
            .map(|(key, value)| (key.clone(), value.clone()))
            .collect();
        let region = match inst.region {
            Some((start, end)) => start..end,
            None => 0..len,
        };
        let output = run(
            &DecodeRequest {
                protocol: &inst.protocol,
                channels: &pairs,
                options: &options,
                region,
                sample_len: len,
                lower: &lower,
            },
            &AtomicBool::new(false),
        );
        let annotations = output.map(|item| item.annotations).unwrap_or_default();
        for annotation in &annotations {
            rows.push(AnnotationRow {
                decoder: inst.id.clone(),
                protocol: inst.protocol.clone(),
                start_sample: annotation.start_sample,
                end_sample: annotation.end_sample,
                class: annotation.class.clone(),
                text: annotation.text.clone(),
                fields: annotation.fields.clone(),
            });
        }
        produced.insert(inst.id.clone(), annotations);
    }
    rows.sort_by(|left, right| {
        left.start_sample
            .cmp(&right.start_sample)
            .then(left.end_sample.cmp(&right.end_sample))
            .then(left.decoder.cmp(&right.decoder))
    });
    rows
}

/// Finds an unambiguous I2C parent for the supported EEPROM decoder stack.
fn resolve_stack(slot: &Slot, stack_on: Option<&str>) -> Result<String, EngineError> {
    if let Some(id) = stack_on {
        let parent = slot
            .decoders
            .iter()
            .find(|decoder| decoder.id == id)
            .ok_or_else(|| EngineError::Decode(format!("no decoder {id} to stack on")))?;
        if parent.protocol != "i2c" {
            return Err(EngineError::Decode(
                "eeprom24 stacks on an I2C decoder".into(),
            ));
        }
        return Ok(parent.id.clone());
    }
    let i2c: Vec<_> = slot
        .decoders
        .iter()
        .filter(|decoder| decoder.protocol == "i2c")
        .collect();
    match i2c.as_slice() {
        [only] => Ok(only.id.clone()),
        [] => Err(EngineError::Decode(
            "add an I2C decoder before the EEPROM stack".into(),
        )),
        _ => Err(EngineError::Decode(
            "name the I2C decoder to stack on".into(),
        )),
    }
}

/// Resolves a channel index, unique label, or device-qualified label to a captured stream.
fn resolve_channel(slot: &Slot, spec: &str) -> Result<usize, EngineError> {
    if let Ok(index) = spec.parse::<usize>() {
        if index < slot.channel_names.len() {
            return Ok(index);
        }
    }
    if let Some((device, name)) = spec.split_once('/') {
        if let Some(index) = slot
            .origins
            .iter()
            .zip(slot.channel_names.iter())
            .position(|(origin, channel)| origin.device_id == device && channel == name)
        {
            return Ok(index);
        }
    }
    let matches: Vec<usize> = slot
        .channel_names
        .iter()
        .enumerate()
        .filter_map(|(index, name)| (name == spec).then_some(index))
        .collect();
    match matches.as_slice() {
        [index] => Ok(*index),
        [] => Err(EngineError::Decode(format!("no channel matches {spec}"))),
        _ => Err(EngineError::Decode(format!(
            "channel {spec} is on more than one device; use device/name"
        ))),
    }
}

/// Copies an analyzer's configuration into its client-facing description.
fn info_of(decoder: &DecoderInst) -> DecoderInfo {
    DecoderInfo {
        id: decoder.id.clone(),
        protocol: decoder.protocol.clone(),
        channels: decoder.channels.clone(),
        options: decoder.options.clone(),
        stack_on: decoder.stack_on.clone(),
    }
}

/// Filters annotations while matching byte sequences within each analyzer's own event stream.
fn filtered(
    slot: &Slot,
    decoder: Option<&str>,
    query: Option<&str>,
    start: Option<u64>,
    end: Option<u64>,
) -> Vec<AnnotationRow> {
    let mut rows: Vec<AnnotationRow> = slot
        .annotations
        .iter()
        .filter(|row| decoder.is_none_or(|id| row.decoder == id))
        .filter(|row| start.is_none_or(|sample| row.end_sample > sample))
        .filter(|row| end.is_none_or(|sample| row.start_sample < sample))
        .cloned()
        .collect();
    if let Some(query) = query.filter(|query| !query.trim().is_empty()) {
        let mut groups: Vec<Vec<usize>> = Vec::new();
        let mut decoder_slots: BTreeMap<String, usize> = BTreeMap::new();
        for (index, row) in rows.iter().enumerate() {
            if let Some(slot) = decoder_slots.get(&row.decoder) {
                groups[*slot].push(index);
            } else {
                decoder_slots.insert(row.decoder.clone(), groups.len());
                groups.push(vec![index]);
            }
        }
        let mut hits = Vec::new();
        for indices in groups {
            let bare: Vec<Annotation> = indices
                .iter()
                .map(|index| {
                    let row = &rows[*index];
                    Annotation::new(
                        row.start_sample,
                        row.end_sample,
                        row.class.clone(),
                        row.text.clone(),
                        row.fields.clone(),
                    )
                })
                .collect();
            for hit in search_annotations(&bare, query) {
                hits.push(rows[indices[hit]].clone());
            }
        }
        rows = hits;
    }
    rows
}

/// Groups tagged rows into the per-analyzer annotation lists used by export writers.
fn group_rows(rows: &[AnnotationRow]) -> Vec<(String, Vec<Annotation>)> {
    let mut groups: Vec<(String, Vec<Annotation>)> = Vec::new();
    for row in rows {
        let annotation = Annotation::new(
            row.start_sample,
            row.end_sample,
            row.class.clone(),
            row.text.clone(),
            row.fields.clone(),
        );
        if let Some((_, bucket)) = groups.iter_mut().find(|(id, _)| id == &row.decoder) {
            bucket.push(annotation);
        } else {
            groups.push((row.decoder.clone(), vec![annotation]));
        }
    }
    groups
}
