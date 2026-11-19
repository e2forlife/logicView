const wave = document.getElementById("wave");
const ruler = document.getElementById("ruler");
const overview = document.getElementById("overview");
const gutter = document.getElementById("gutter");
const tabsEl = document.getElementById("tabs");
const statusEl = document.getElementById("status");
const hoverEl = document.getElementById("hover");
const sideBody = document.getElementById("side-body");
const runBtn = document.getElementById("run");
const stopBtn = document.getElementById("stop");

const TIME_DIVS = [
  1e-12, 2e-12, 5e-12, 1e-11, 2e-11, 5e-11,
  1e-10, 2e-10, 5e-10, 1e-9, 2e-9, 5e-9,
  1e-8, 2e-8, 5e-8, 1e-7, 2e-7, 5e-7,
  1e-6, 2e-6, 5e-6, 1e-5, 2e-5, 5e-5, 1e-4, 2e-4, 5e-4,
  1e-3, 2e-3, 5e-3, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1,
];
const MARKER_COLORS = ["#5aa2ff", "#ff8a5b", "#3dcc8e", "#e2b340", "#c58bff", "#ff6b8a"];
const CHANNEL_COLORS = [
  "#e2b340", "#3dcc8e", "#5aa2ff", "#c58bff", "#ff8a5b", "#f2f2f2",
  "#7dcea0", "#f1948a", "#ff5c8a", "#46d6c8", "#f0d060", "#8b9cff",
];

const state = {
  sessions: [],
  active: null,
  phase: "idle",
  error: null,
  total: 0,
  rate: 1_000_000,
  durationMs: 2000,
  channels: [],
  analog: [],
  triggerSample: null,
  hidden: new Set(),
  tiles: {},
  overviewCols: null,
  overviewSnap: null,
  req: 0,
  hoverText: "",
  hoverSequence: 0,
  hoverBounds: null,
  hoverSnap: null,
  hoverX: null,
  hoverChannel: 0,
  hoverKey: null,
  lastMeasure: null,
  tab: "device",
  tool: null,
  menu: null,
  cursors: [null, null],
  devices: [],
  probes: [],
  edgeChannel: null,
  annotations: [],
  waveformAnnotations: [],
  decoders: [],
  decoderCatalog: [],
  selectedDecoder: null,
  decodeQuery: "",
  decoderProtocol: "",
  spiView: {},
  decodeView: {},
  gutterSig: "",
  nextMarker: 1,
  nextMeasure: 1,
  channelGroup: 0,
  channelsAllDisabled: false,
  tileView: null,
  planned: 0,
  captureStarted: 0,
  waitKind: "",
  deviceList: [],
  profiles: [],
};

const settings = {
  rate: 1_000_000,
  durationNs: 2_000_000_000,
  trigger: false,
  percent: 10,
  depth: "buffer",
  run: "single",
  repeatMs: 500,
  rle: false,
  threshold: 1.6,
  filter: false,
  extClock: false,
  clockFalling: false,
  discard: false,
  triggerKind: "rising",
  triggerChannel: 0,
  triggerSteps: [],
  pattern: "10",
  device: "demo",
  deviceName: "Demo",
  channelEnable: 0,
};

const views = {};
let socket = null;
let tileFlight = false;
let tileAgain = false;
let commandBusy = false;
let hoverTimer = null;
let pointer = null;
let zoomAnchor = null;
let zoomAnchorTimer = null;
const touchPoints = new Map();
let pinch = null;

function view() {
  const id = state.active || "pending";
  if (!views[id]) {
    let order = null;
    let colors = {};
    try {
      const raw = sessionStorage.getItem("lv-order:" + id);
      if (raw) order = JSON.parse(raw);
      const storedColors = sessionStorage.getItem("lv-colors:" + id);
      if (storedColors) colors = JSON.parse(storedColors);
    } catch (_) { /* keep the natural order and server colors */ }
    views[id] = {
      start: 0,
      spp: 1,
      userNavigated: false,
      order,
      markers: [],
      measures: [],
      buses: [],
      nextBus: 1,
      selection: [],
      anchor: null,
      selected: null,
      names: {},
      colors,
      modes: {},
    };
  }
  return views[id];
}

function isLive(phase) {
  return phase === "running" || phase === "arming" || phase === "waiting_trigger" || phase === "stopping";
}

async function api(body) {
  const res = await fetch("/api/command", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  if (!json.ok) throw new Error(json.error || "command failed");
  return json.data;
}

function logicRowModel(channel, decoderId, lane) {
  const index = channel.index;
  const tileKey = "logic:" + index;
  return {
    key: decoderId ? "logic:" + index + "@" + decoderId + (lane ? ":" + lane : "") : tileKey,
    tileKey,
    kind: "logic",
    channel: index,
    name: channel.name,
    color: storedColor(tileKey, channel.color),
    device: channel.device_name || "",
    decoderId: decoderId || "",
    lane: lane || "",
  };
}

function storedColor(key, fallback) {
  const colors = view().colors;
  return (colors && colors[key]) || fallback;
}

function colorKey(row) {
  if (row.kind === "logic") return row.tileKey || ("logic:" + row.channel);
  if (row.kind === "analog") return "analog:" + row.channel;
  return row.key;
}

function persistColors() {
  try {
    sessionStorage.setItem("lv-colors:" + (state.active || "pending"), JSON.stringify(view().colors || {}));
  } catch (_) { /* the in-memory color still lasts for this session */ }
}

function sessionContainers() {
  const list = view().buses;
  if (!Array.isArray(list)) {
    view().buses = [];
    return view().buses;
  }
  for (const bus of list) normalizeContainerInPlace(bus);
  return list;
}

function normalizeContainerInPlace(raw) {
  if (!raw || typeof raw !== "object") return raw;
  raw.type = raw.type === "group" ? "group" : "bus";
  if (!Array.isArray(raw.members)) {
    const channels = Array.isArray(raw.channels) ? raw.channels : [];
    raw.members = channels.map((index) => ({ kind: "channel", index: Number(index) })).filter((member) => Number.isFinite(member.index));
  } else {
    raw.members = raw.members.map((member) => {
      if (!member || typeof member !== "object") return null;
      if (member.kind === "group") return { kind: "group", id: Number(member.id) };
      return { kind: "channel", index: Number(member.index) };
    }).filter((member) => member && (member.kind === "group" ? Number.isFinite(member.id) : Number.isFinite(member.index)));
  }
  if (!raw.radix) raw.radix = raw.analog ? "analog" : "hex";
  if (raw.radix === "analog") raw.analog = true;
  else if (typeof raw.analog !== "boolean") raw.analog = false;
  if (typeof raw.msbFirst !== "boolean") raw.msbFirst = false;
  if (typeof raw.folded !== "boolean") raw.folded = false;
  raw.channels = raw.members.filter((member) => member.kind === "channel").map((member) => member.index);
  return raw;
}

function nestedContainerIds() {
  const ids = new Set();
  for (const container of sessionContainers()) {
    for (const member of container.members || []) {
      if (member.kind === "group") ids.add(Number(member.id));
    }
  }
  return ids;
}

function parentContainer(id) {
  const wanted = Number(id);
  for (const container of sessionContainers()) {
    if ((container.members || []).some((member) => member.kind === "group" && Number(member.id) === wanted)) return container;
  }
  return null;
}

function descendantChannels(container, guard = 0) {
  if (!container || guard > 32) return [];
  const out = [];
  for (const member of container.members || []) {
    if (member.kind === "channel") out.push(Number(member.index));
    else if (member.kind === "group") {
      const child = sessionContainers().find((item) => Number(item.id) === Number(member.id));
      if (child) out.push(...descendantChannels(child, guard + 1));
    }
  }
  return out;
}

function containerDepth(container, guard = 0) {
  if (!container || guard > 32) return 0;
  const parent = parentContainer(container.id);
  return parent ? containerDepth(parent, guard + 1) + 1 : 0;
}

function directParentOfChannel(index) {
  const wanted = Number(index);
  for (const container of sessionContainers()) {
    if ((container.members || []).some((member) => member.kind === "channel" && Number(member.index) === wanted)) return container;
  }
  return null;
}

function ownedChannelSet() {
  const owned = new Set();
  for (const container of sessionContainers()) {
    for (const member of container.members || []) {
      if (member.kind === "channel") owned.add(Number(member.index));
    }
  }
  return owned;
}

function containerHeaderRow(container, depth) {
  const type = container.type === "group" ? "group" : "bus";
  return {
    key: "bus:" + container.id,
    kind: type,
    channel: (container.channels || [])[0] ?? 0,
    name: container.name,
    color: storedColor("bus:" + container.id, "#d5deea"),
    device: "",
    bus: container,
    containerId: container.id,
    depth: depth || 0,
    header: true,
  };
}

function sourceRows() {
  const rows = [];
  for (const channel of state.channels) rows.push(logicRowModel(channel, ""));
  for (const channel of state.analog) {
    rows.push({
      key: "analog:" + channel.index,
      tileKey: "analog:" + channel.index,
      kind: "analog",
      channel: channel.index,
      name: channel.name,
      color: storedColor("analog:" + channel.index, channel.color),
      device: "",
    });
  }
  const nested = nestedContainerIds();
  for (const bus of sessionContainers()) {
    if (nested.has(Number(bus.id))) continue;
    rows.push(containerHeaderRow(bus, 0));
  }
  return rows;
}

function decoderIndexes(decoder) {
  const seen = new Set();
  const indexes = [];
  for (const value of Object.values(decoder.channels || {})) {
    const index = Number(value);
    if (!Number.isFinite(index) || seen.has(index)) continue;
    seen.add(index);
    indexes.push(index);
  }
  return indexes;
}

function indexesInOrder(indexes, source) {
  const wanted = new Set(indexes);
  const ordered = [];
  for (const row of source) {
    if (row.kind === "logic" && wanted.has(row.channel) && !ordered.includes(row.channel)) ordered.push(row.channel);
  }
  for (const index of indexes) {
    if (!ordered.includes(index)) ordered.push(index);
  }
  return ordered;
}

function decodeShownAnalog(id) {
  return decodeFormat(id) === "analog" || !!(state.spiView[id] && state.spiView[id].analog);
}

function signalModes() {
  const v = view();
  if (!v.modes || typeof v.modes !== "object") v.modes = {};
  return v.modes;
}

function signalMode(key) {
  return signalModes()[key] === "analog" ? "analog" : "digital";
}

function setSignalMode(key, mode) {
  if (!key) return;
  const modes = signalModes();
  if (mode === "analog") modes[key] = "analog";
  else delete modes[key];
}

function rowShowsAnalog(row) {
  if (!row) return false;
  if (row.kind === "analog") return true;
  if (row.kind === "logic") return signalMode(row.key) === "analog";
  if (row.kind === "bus" || row.kind === "group") {
    if (!row.bus) return false;
    if (row.bus.decode) return decodeShownAnalog(row.bus.decode);
    return !!(row.bus.analog || row.bus.radix === "analog");
  }
  if (row.kind === "condense" || row.kind === "decode") {
    if (row.bus && row.bus.analog) return true;
    return row.decoderId ? decodeShownAnalog(row.decoderId) : false;
  }
  return false;
}

function laneColor(channel, fallback) {
  const signal = state.channels.find((item) => item.index === Number(channel));
  if (!signal) return fallback;
  return storedColor("logic:" + signal.index, signal.color || fallback);
}

function isSpiProtocol(protocol) {
  return protocol === "spi";
}

function decoderLaneSpecs(decoder) {
  return (state.decoderCatalog || []).find((item) => item.id === decoder.protocol)?.lanes || [];
}

function decodeLanes(decoder, fallbackChannel) {
  const channels = decoder.channels || {};
  const specs = decoderLaneSpecs(decoder);
  if (specs.length) {
    return specs.filter((lane) => channels[lane.channel] != null && channels[lane.channel] !== "" && Number.isFinite(Number(channels[lane.channel])))
      .map((lane) => ({ ...lane, channel: Number(channels[lane.channel]) }));
  }
  return [{ id: "", name: protocolLabel(decoder.protocol), channel: fallbackChannel }];
}

function decodeBusRow(decoder, lane, header) {
  const analog = decodeShownAnalog(decoder.id);
  const channel = Number.isFinite(Number(lane.channel)) ? Number(lane.channel) : 0;
  const key = lane.id ? "decode:" + decoder.id + ":" + lane.id : "decode:" + decoder.id;
  return {
    key,
    kind: "decode",
    channel,
    name: lane.name,
    color: storedColor(key, laneColor(channel, analog ? "#7dcea0" : "#8eb6ff")),
    device: "",
    decoderId: decoder.id,
    header: !!header,
    lane: lane.id || "",
    bus: {
      id: key,
      name: lane.name,
      channels: [],
      analog,
      decode: decoder.id,
    },
  };
}

function groupRows(decoder, source, depth = 0) {
  const indexes = indexesInOrder(decoderIndexes(decoder), source);
  const channel = indexes.length ? indexes[0] : 0;
  const lanes = decodeLanes(decoder, channel);
  const byIndex = new Map(state.channels.map((item) => [item.index, item]));
  const rows = [];
  for (const [position, lane] of lanes.entries()) {
    const header = decodeBusRow(decoder, lane, position === 0);
    header.depth = depth;
    header.child = depth > 0;
    rows.push(header);
    if (decoderCondensed(decoder.id, lane.id)) continue;
    const channels = decoder.channels || {};
    const laneIndexes = lane.id ? lane.channels.map((name) => channels[name]) : indexes;
    const seen = new Set();
    for (const value of laneIndexes) {
      if (value == null || value === "") continue;
      const index = Number(value);
      if (!Number.isFinite(index) || seen.has(index)) continue;
      seen.add(index);
      const signal = byIndex.get(index);
      if (!signal) continue;
      const row = logicRowModel(signal, decoder.id, lane.id);
      row.child = true;
      row.depth = depth + 1;
      rows.push(row);
    }
  }
  return rows;
}

function isStackChild(decoder) {
  return !!(decoder.stack_on && (state.decoders || []).some((item) => item.id === decoder.stack_on));
}

function clusterDecoders(root) {
  const out = [root];
  const walk = (id) => {
    for (const decoder of state.decoders || []) {
      if (decoder.stack_on === id && !out.includes(decoder)) {
        out.push(decoder);
        walk(decoder.id);
      }
    }
  };
  walk(root.id);
  return out;
}

function clusterChannels(root) {
  const indexes = new Set();
  for (const decoder of clusterDecoders(root)) {
    for (const index of decoderIndexes(decoder)) indexes.add(index);
  }
  return indexes;
}

function deepestContainerFor(indexes) {
  if (!indexes.length) return null;
  let best = null;
  let bestDepth = -1;
  for (const container of sessionContainers()) {
    const owned = new Set(descendantChannels(container));
    if (!indexes.every((index) => owned.has(index))) continue;
    const depth = containerDepth(container);
    if (depth >= bestDepth) {
      best = container;
      bestDepth = depth;
    }
  }
  return best;
}

function topLevelSource() {
  const nested = nestedContainerIds();
  const owned = ownedChannelSet();
  const out = [];
  for (const row of orderedSourceRows()) {
    if (row.kind === "logic" && owned.has(row.channel)) continue;
    if ((row.kind === "bus" || row.kind === "group") && row.bus && nested.has(Number(row.bus.id))) continue;
    out.push(row);
  }
  return out;
}

function renderCluster(root, source, depth, containerId) {
  const cluster = clusterDecoders(root);
  const groups = cluster.map((decoder) => ({
    id: decoder.id,
    stackOn: decoder.stack_on && cluster.some((item) => item.id === decoder.stack_on) ? decoder.stack_on : "",
    rows: groupRows(decoder, source, depth),
  }));
  const out = [];
  const placed = new Set();
  const waiting = (group) => group.stackOn && groups.some((item) => item.id === group.stackOn && !placed.has(item.id));
  const place = (group) => {
    if (placed.has(group.id)) return;
    for (const row of group.rows) {
      const copy = Object.assign({}, row);
      if (containerId != null) copy.containerId = containerId;
      out.push(copy);
    }
    placed.add(group.id);
    for (const child of groups) {
      if (!placed.has(child.id) && child.stackOn === group.id) place(child);
    }
  };
  const rootGroup = groups.find((group) => group.id === root.id);
  if (rootGroup) place(rootGroup);
  for (const group of groups) {
    if (!placed.has(group.id) && !waiting(group)) place(group);
  }
  return out;
}

function renderContainer(container, depth, blocked, seen) {
  const visiting = seen || new Set();
  if (!container || visiting.has(Number(container.id))) return [];
  visiting.add(Number(container.id));
  const rows = [];
  const header = containerHeaderRow(container, depth);
  header.child = depth > 0;
  rows.push(header);
  if (container.folded) return rows;
  const blockedChannels = blocked || new Set();
  const roots = (state.decoders || []).filter((decoder) => {
    if (isStackChild(decoder)) return false;
    const owner = deepestContainerFor(decoderIndexes(decoder));
    return owner && Number(owner.id) === Number(container.id);
  });
  const localClaimed = new Set(blockedChannels);
  for (const root of roots) {
    for (const index of clusterChannels(root)) localClaimed.add(index);
  }
  const emitted = new Set();
  const source = orderedSourceRows();
  const emitRoot = (root) => {
    if (!root || emitted.has(root.id)) return;
    emitted.add(root.id);
    rows.push(...renderCluster(root, source, depth + 1, container.id));
  };
  for (const member of container.members || []) {
    if (member.kind === "group") {
      const child = sessionContainers().find((item) => Number(item.id) === Number(member.id));
      if (!child) continue;
      const childChannels = new Set(descendantChannels(child));
      const root = roots.find((decoder) => !emitted.has(decoder.id) && [...clusterChannels(decoder)].some((index) => childChannels.has(index)));
      if (root) emitRoot(root);
      rows.push(...renderContainer(child, depth + 1, localClaimed, visiting));
      continue;
    }
    const index = Number(member.index);
    if (blockedChannels.has(index)) continue;
    const root = roots.find((decoder) => !emitted.has(decoder.id) && clusterChannels(decoder).has(index));
    if (root) {
      emitRoot(root);
      continue;
    }
    if (localClaimed.has(index)) continue;
    const signal = state.channels.find((item) => item.index === index);
    if (!signal) continue;
    const row = logicRowModel(signal, "");
    row.child = true;
    row.depth = depth + 1;
    row.containerId = container.id;
    rows.push(row);
  }
  for (const root of roots) emitRoot(root);
  return rows;
}

function displayRows() {
  const source = topLevelSource();
  const decoders = state.decoders || [];
  const topDecoders = decoders.filter((decoder) => {
    if (isStackChild(decoder)) return false;
    return !deepestContainerFor(decoderIndexes(decoder));
  });
  const groups = topDecoders.map((decoder) => {
    const indexes = clusterChannels(decoder);
    let anchor = -1;
    source.forEach((row, index) => {
      if (anchor >= 0) return;
      if (row.kind === "logic" && indexes.has(row.channel)) anchor = index;
    });
    return {
      id: decoder.id,
      anchor,
      rows: renderCluster(decoder, orderedSourceRows(), 0, null),
    };
  });
  const claimed = new Set();
  for (const decoder of topDecoders) {
    for (const index of clusterChannels(decoder)) claimed.add(index);
  }
  const nestedClaims = new Set();
  for (const decoder of decoders) {
    if (isStackChild(decoder)) continue;
    if (!deepestContainerFor(decoderIndexes(decoder))) continue;
    for (const index of clusterChannels(decoder)) nestedClaims.add(index);
  }
  const out = [];
  const placed = new Set();
  const placeGroup = (group) => {
    if (placed.has(group.id)) return;
    out.push(...group.rows);
    placed.add(group.id);
  };
  source.forEach((row, index) => {
    for (const group of groups) {
      if (group.anchor !== index || placed.has(group.id)) continue;
      placeGroup(group);
    }
    if (row.kind === "logic" && (claimed.has(row.channel) || nestedClaims.has(row.channel))) return;
    if ((row.kind === "bus" || row.kind === "group") && row.bus) {
      out.push(...renderContainer(row.bus, 0, claimed));
      return;
    }
    out.push(row);
  });
  for (const group of groups) {
    if (!placed.has(group.id)) placeGroup(group);
  }
  return out;
}

function probeForRow(row) {
  return (state.probes || []).find((probe) => {
    if (probe.name !== row.name) return false;
    if (!row.device) return true;
    return probe.device_id === row.device || probe.device_name === row.device;
  });
}

function maskBit(index) {
  return 1n << BigInt(index);
}

function channelIsEnabled(index) {
  if (state.channelsAllDisabled) return false;
  if (!settings.channelEnable) return true;
  return (BigInt(settings.channelEnable) & maskBit(index)) !== 0n;
}

function rowEnabled(row) {
  if (row.kind === "lane" || row.kind === "condense" || row.kind === "decode") return true;
  if (row.kind === "bus" || row.kind === "group") {
    if (row.bus && row.bus.decode) return true;
    const indexes = row.bus ? descendantChannels(row.bus) : [];
    if (!indexes.length) return true;
    return indexes.some((index) => channelIsEnabled(index));
  }
  if (row.kind === "analog") return state.analog.length > 0;
  const probe = probeForRow(row);
  return channelIsEnabled(probe ? probe.index : row.channel);
}

function orderedSourceRows() {
  const rows = sourceRows();
  const order = view().order;
  if (!order || !order.length) return rows;
  const map = new Map(rows.map((row) => [row.key, row]));
  const out = [];
  for (const key of order) {
    const row = map.get(key);
    if (row) {
      out.push(row);
      map.delete(key);
    }
  }
  for (const row of map.values()) out.push(row);
  return out;
}

function orderedRows() {
  return displayRows();
}

function layoutRows() {
  return orderedRows().filter((row) => rowEnabled(row) && !rowHiddenByDecoder(row));
}

function visibleRows() {
  return layoutRows().filter((row) => !state.hidden.has(row.key));
}

function triggerOrigin() {
  // A requested pre-trigger percentage is only a target; the capture reports
  // the position that belongs to its samples. Do not invent a trigger marker
  // before that position is available.
  return typeof state.triggerSample === "number" && state.triggerSample >= 0
    ? state.triggerSample : 0;
}

function sampleSeconds(sample) {
  return (sample - triggerOrigin()) / Math.max(1, state.rate);
}

function persistOrder(keys) {
  view().order = keys;
  try {
    sessionStorage.setItem("lv-order:" + state.active, JSON.stringify(keys));
  } catch (_) { /* the in-memory order still lasts for this session */ }
}

function applyStatus(status, fromLive) {
  const previous = state.phase;
  state.phase = status.phase;
  if ("error" in status) state.error = status.error;
  state.rate = status.sample_rate_hz || state.rate;
  state.durationMs = status.duration_ms || state.durationMs;
  if (status.channels) state.channels = status.channels;
  if (status.probes) state.probes = status.probes;
  if (typeof status.channel_enable === "number") settings.channelEnable = status.channel_enable;
  if (status.analog) state.analog = status.analog;
  const channelSig = (state.channels || []).map((channel) => channel.name).join("|");
  if (channelSig !== state.channelSig) {
    state.channelSig = channelSig;
    view().customHeights = false;
    view().heights = {};
    state.gutterSig = "";
    if (state.tab === "device" || state.tab === "triggers") selectTab(state.tab);
  }
  if (status.devices) {
    state.devices = status.devices;
    settings.deviceName = status.devices.map((device) => device.name).join(" + ") || settings.deviceName;
    syncDeviceSelect();
  }
  if ("trigger_sample" in status) state.triggerSample = status.trigger_sample;
  const grew = status.sample_count !== state.total;
  if (typeof status.sample_count === "number") state.total = status.sample_count;
  if (!view().userNavigated) fitView();
  renderChrome();
  if (grew || !fromLive) {
    scheduleTiles();
    refreshOverview();
  } else {
    drawOverview();
  }
  if (status.phase === "stopped" && previous !== "stopped") loadAnnotations();
  paintWait();
}

function fitSpp() {
  const width = Math.max(1, wave.clientWidth || 1);
  if (state.total <= 0) return 1;
  return state.total / width;
}

function fitView() {
  const v = view();
  if (state.total <= 0) {
    v.start = 0;
    v.spp = 1;
    return;
  }
  v.start = 0;
  v.spp = fitSpp();
}

function clampView() {
  const v = view();
  const width = Math.max(1, wave.clientWidth || 1);
  if (state.total <= 0) {
    v.start = 0;
    return;
  }
  const fit = fitSpp();
  if (!(v.spp > 0) || v.spp > fit) v.spp = fit;
  const span = width * v.spp;
  if (span >= state.total) {
    v.start = 0;
    v.spp = fit;
    return;
  }
  if (v.start < 0) v.start = 0;
  if (v.start + span > state.total) v.start = state.total - span;
}

function traceEndX(width) {
  if (state.total <= 0) return 0;
  const v = view();
  if (!(v.spp > 0)) return 0;
  return Math.max(0, Math.min(width, (state.total - v.start) / v.spp));
}

function pastCapture(index) {
  return view().start + index * view().spp >= state.total;
}

function renderChrome() {
  paintStatus();
  renderTabs();
  renderGutter();
  renderMarkerList();
  renderMeasureList();
  drawRuler();
  syncTimebaseLabel();
  syncTriggerToolbar();
}

function paintRunIcon() {
  const icon = runBtn.querySelector(".run-icon");
  if (!icon) return;
  const mode = settings.run === "repeat" || settings.run === "loop"
    ? settings.run
    : (settings.depth === "stream" ? "stream" : "single");
  icon.dataset.mode = mode;
  const titles = {
    single: "Run capture. Right-click to choose repeat or loop.",
    stream: "Run capture. Right-click to choose repeat or loop.",
    repeat: "Repeat capture. Right-click to change run mode.",
    loop: "Loop capture. Right-click to change run mode.",
  };
  runBtn.title = titles[mode] || titles.single;
}

function paintStatus() {
  const live = isLive(state.phase);
  runBtn.disabled = live || commandBusy;
  stopBtn.disabled = !live || commandBusy;
  paintRunIcon();
  const name = document.getElementById("device-name");
  if (name) name.textContent = settings.deviceName;
  if (state.error) {
    statusEl.textContent = `Error: ${state.error}`;
    statusEl.title = state.error;
    return;
  }
  statusEl.title = "";
  if (state.decoderBusy) {
    statusEl.textContent = "Applying decoder annotations...";
    return;
  }
  const count = state.total.toLocaleString();
  const trigger = state.triggerSample == null ? "" : ` · trigger @ ${state.triggerSample}`;
  const hover = state.hoverText ? ` · ${state.hoverText}` : "";
  const captured = state.total > 0 ? ` | ${formatSeconds(state.total / Math.max(1, state.rate))} captured` : "";
  statusEl.textContent = `${state.phase} | ${count} samples | ${formatHz(state.rate)}${captured}${trigger}${hover}`;
}

let sessionRename = null;
let pendingCloseSession = null;

function renderTabs() {
  if (sessionRename) return;
  tabsEl.replaceChildren();
  for (const session of state.sessions) {
    const button = document.createElement("div");
    button.setAttribute("role", "button");
    button.tabIndex = 0;
    button.addEventListener("keydown", (ev) => {
      if (ev.target === button && (ev.key === "Enter" || ev.key === " ")) { ev.preventDefault(); selectSession(session.id); }
    });
    button.className = "tab" + (session.id === state.active ? " active" : "");
    const label = document.createElement("span");
    label.textContent = session.name;
    const close = document.createElement("button");
    close.type = "button";
    close.className = "tab-close";
    close.setAttribute("aria-label", `Close ${session.name}`);
    close.addEventListener("click", (ev) => {
      ev.stopPropagation();
      pendingCloseSession = session.id;
      document.getElementById("close-capture-dialog").showModal();
    });
    close.addEventListener("dblclick", (ev) => ev.stopPropagation());
    button.append(label, close);
    button.title = "Double-click to rename";
    button.addEventListener("click", (ev) => {
      if (ev.detail > 1) return;
      selectSession(session.id);
    });
    button.addEventListener("dblclick", (ev) => {
      ev.preventDefault();
      ev.stopPropagation();
      startSessionRename(session, button);
    });
    tabsEl.appendChild(button);
  }
}

function startSessionRename(session, button) {
  const input = document.createElement("input");
  input.className = "rename";
  input.value = session.name;
  input.setAttribute("aria-label", "Capture name");
  sessionRename = session.id;
  button.replaceWith(input);
  input.focus();
  input.select();
  let done = false;
  const finish = async (commit) => {
    if (done) return;
    done = true;
    const next = input.value.trim();
    if (commit && next && next !== session.name) {
      try {
        await api({ cmd: "rename_session", id: session.id, name: next });
      } catch (err) {
        statusEl.textContent = err.message;
      }
    }
    sessionRename = null;
    await refreshSessions();
  };
  input.addEventListener("keydown", (ev) => {
    ev.stopPropagation();
    if (ev.key === "Enter") {
      ev.preventDefault();
      finish(true);
    } else if (ev.key === "Escape") {
      ev.preventDefault();
      finish(false);
    }
  });
  input.addEventListener("blur", () => finish(true));
  input.addEventListener("mousedown", (ev) => ev.stopPropagation());
  input.addEventListener("click", (ev) => ev.stopPropagation());
}

function ensureSelection() {
  const v = view();
  if (!Array.isArray(v.selection)) {
    v.selection = v.selected ? [v.selected] : [];
    if (v.anchor == null) v.anchor = v.selected || null;
  }
  return v;
}

function applySelection(key, ev) {
  const v = ensureSelection();
  const keys = layoutRows().map((row) => row.key);
  if (ev.shiftKey && v.anchor && keys.includes(v.anchor) && keys.includes(key)) {
    const start = keys.indexOf(v.anchor);
    const end = keys.indexOf(key);
    const [lo, hi] = start < end ? [start, end] : [end, start];
    v.selection = keys.slice(lo, hi + 1);
  } else if (ev.ctrlKey || ev.metaKey) {
    const next = new Set(v.selection);
    if (next.has(key)) next.delete(key);
    else next.add(key);
    v.selection = [...next];
    v.anchor = key;
  } else {
    v.selection = [key];
    v.anchor = key;
  }
  v.selected = v.anchor || v.selection[0] || null;
  state.gutterSig = "";
  renderGutter();
  refreshOverview();
}

function selectOnly(key) {
  applySelection(key, { shiftKey: false, ctrlKey: false, metaKey: false });
}

function selectedAncestorCovers(row, selected) {
  let container = null;
  if (row.kind === "logic" && row.containerId != null) {
    container = sessionContainers().find((item) => Number(item.id) === Number(row.containerId)) || null;
  } else if (containerHeader(row)) {
    container = parentContainer(row.bus.id);
  }
  let guard = 0;
  while (container && guard++ < 32) {
    if (selected.has("bus:" + container.id)) return true;
    container = parentContainer(container.id);
  }
  return false;
}

function selectedGroupMembers() {
  const selected = new Set(ensureSelection().selection);
  const members = [];
  const seenChannels = new Set();
  const seenGroups = new Set();
  for (const row of layoutRows()) {
    if (!selected.has(row.key) || selectedAncestorCovers(row, selected)) continue;
    if (row.kind === "logic") {
      const index = Number(row.channel);
      if (!Number.isFinite(index) || seenChannels.has(index)) continue;
      seenChannels.add(index);
      members.push({ kind: "channel", index });
      continue;
    }
    if (!containerHeader(row)) continue;
    const id = Number(row.bus.id);
    if (!Number.isFinite(id) || seenGroups.has(id)) continue;
    seenGroups.add(id);
    members.push({ kind: "group", id });
  }
  return members;
}

function memberLeafChannels(members) {
  const out = [];
  for (const member of members || []) {
    if (member.kind === "channel") out.push(Number(member.index));
    else if (member.kind === "group") {
      const child = sessionContainers().find((item) => Number(item.id) === Number(member.id));
      if (child) out.push(...descendantChannels(child));
    }
  }
  return out;
}

function memberCurrentParent(member) {
  if (!member) return null;
  if (member.kind === "channel") return directParentOfChannel(member.index);
  return parentContainer(member.id);
}

function memberMatches(member, item) {
  if (!member || !item) return false;
  if (item.kind === "channel") return member.kind === "channel" && Number(member.index) === Number(item.index);
  return member.kind === "group" && Number(member.id) === Number(item.id);
}

let channelDrag = null;
let suppressChannelClick = false;
document.addEventListener("click", (ev) => {
  if (!suppressChannelClick || !gutter.contains(ev.target)) return;
  ev.preventDefault();
  ev.stopPropagation();
  suppressChannelClick = false;
}, true);

function channelKeyAt(clientY) {
  const nodes = [...gutter.querySelectorAll(".ch")];
  if (!nodes.length) return null;
  for (const node of nodes) {
    const rect = node.getBoundingClientRect();
    if (clientY >= rect.top && clientY <= rect.bottom) return node.dataset.key;
  }
  const first = nodes[0].getBoundingClientRect();
  if (clientY < first.top) return nodes[0].dataset.key;
  return nodes[nodes.length - 1].dataset.key;
}

function highlightChannel(key) {
  for (const node of gutter.querySelectorAll(".ch")) {
    node.classList.toggle("drop", !!key && node.dataset.key === key);
  }
}

function finishChannelDrag() {
  if (!channelDrag) return;
  window.removeEventListener("mousemove", channelDrag.move);
  window.removeEventListener("mouseup", channelDrag.up);
  window.removeEventListener("pointermove", channelDrag.move);
  window.removeEventListener("pointerup", channelDrag.up);
  const drag = channelDrag;
  channelDrag = null;
  highlightChannel(null);
  if (drag.moved) {
    suppressChannelClick = true;
    setTimeout(() => { suppressChannelClick = false; }, 0);
  } else if (drag.selectOnClick) selectOnly(drag.key);
}

function startChannelDrag(key, startY, selectOnClick = true) {
  if (channelDrag) finishChannelDrag();
  const move = (e) => {
    if (!channelDrag) return;
    if (Math.abs(e.clientY - channelDrag.startY) > 4) channelDrag.moved = true;
    const target = channelKeyAt(e.clientY);
    if (channelDrag.moved && target && target !== channelDrag.key) {
      moveChannel(channelDrag.key, target);
    }
    highlightChannel(target && target !== channelDrag.key ? target : null);
  };
  const up = (e) => {
    if (!channelDrag) return;
    const y = e && Number.isFinite(e.clientY) ? e.clientY : null;
    const target = y == null ? null : channelKeyAt(y);
    const dy = y == null ? 0 : Math.abs(y - channelDrag.startY);
    if (target && target !== channelDrag.key && (channelDrag.moved || dy > 4)) {
      moveChannel(channelDrag.key, target);
      channelDrag.moved = true;
    }
    finishChannelDrag();
  };
  channelDrag = { key, startY, moved: false, move, up, selectOnClick };
  window.addEventListener("mousemove", move);
  window.addEventListener("mouseup", up);
  window.addEventListener("pointermove", move);
  window.addEventListener("pointerup", up);
}

function rowMetrics() {
  const rows = layoutRows();
  const stage = document.querySelector(".wave-stage");
  const viewport = Math.max(1, stage ? stage.clientHeight : 1);
  const v = view();
  const laneH = 26;
  const flexRows = rows.filter((row) => row.kind !== "lane");
  const laneCount = rows.length - flexRows.length;
  if (!v.heights) v.heights = {};
  if (!v.customHeights) {
    const count = Math.max(1, flexRows.length);
    const room = Math.max(28, viewport - laneCount * laneH);
    const base = Math.floor(room / count);
    let used = 0;
    flexRows.forEach((row, index) => {
      const height = index === flexRows.length - 1 ? Math.max(28, room - used) : Math.max(28, base);
      v.heights[row.key] = height;
      used += Math.max(28, base);
    });
  } else {
    for (const row of flexRows) {
      if (!v.heights[row.key]) v.heights[row.key] = 64;
    }
  }
  let top = 0;
  const layout = rows.map((row) => {
    const height = row.kind === "lane" ? laneH : Math.max(28, v.heights[row.key] || 64);
    const item = { row, top, height };
    top += height;
    return item;
  });
  return { layout, total: Math.max(1, top), viewport, lanes: [], laneH, laneBlock: 0 };
}

function startRowResize(key, startY) {
  const v = view();
  v.customHeights = true;
  const start = v.heights[key] || 64;
  const move = (ev) => {
    const y = ev.clientY;
    v.heights[key] = Math.max(28, Math.min(420, Math.round(start + (y - startY))));
    state.gutterSig = "";
    renderGutter();
    drawWave();
  };
  const up = () => {
    window.removeEventListener("mousemove", move);
    window.removeEventListener("mouseup", up);
    window.removeEventListener("pointermove", move);
    window.removeEventListener("pointerup", up);
  };
  window.addEventListener("mousemove", move);
  window.addEventListener("mouseup", up);
  window.addEventListener("pointermove", move);
  window.addEventListener("pointerup", up);
}

let foldAnim = null;

function rowFolded(row) {
  if (row.kind === "decode") return decoderCondensed(row.decoderId, row.lane);
  if ((row.kind === "bus" || row.kind === "group") && row.bus && !row.bus.decode) return !!row.bus.folded;
  return false;
}

function foldButton(row, folded) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "fold";
  button.title = folded ? "Show waveform channels" : "Hide waveform channels";
  button.setAttribute("aria-expanded", folded ? "false" : "true");
  button.setAttribute("aria-label", button.title);
  button.innerHTML = `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 6l6 6-6 6"></path></svg>`;
  const animate = foldAnim === row.key;
  if (animate) {
    button.classList.add("anim");
    if (folded) button.classList.add("open");
    foldAnim = null;
  } else if (!folded) {
    button.classList.add("open");
  }
  button.addEventListener("pointerdown", (ev) => ev.stopPropagation());
  button.addEventListener("click", (ev) => {
    ev.stopPropagation();
    foldAnim = row.key;
    if ((row.kind === "bus" || row.kind === "group") && row.bus && !row.bus.decode) {
      row.bus.folded = !row.bus.folded;
      state.gutterSig = "";
      renderGutter();
      drawWave();
      scheduleTiles();
      refreshOverview();
      return;
    }
    const pref = decodePref(row.decoderId);
    if (row.lane) {
      if (!pref.lanes) pref.lanes = {};
      pref.lanes[row.lane] = !folded;
    } else pref.condensed = !folded;
    state.gutterSig = "";
    renderGutter();
    drawWave();
    scheduleTiles();
    refreshOverview();
  });
  if (animate) {
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        button.classList.toggle("open", !folded);
      });
    });
  }
  return button;
}

function foldSpacer() {
  const spacer = document.createElement("span");
  spacer.className = "fold-spacer";
  spacer.setAttribute("aria-hidden", "true");
  return spacer;
}

// A container header is followed by its visible descendants until the next
// row at the same or shallower depth. Folded groups therefore frame one row.
function groupRanges(layout) {
  const ranges = [];
  for (let i = 0; i < layout.length; i++) {
    const row = layout[i].row;
    if (!row.header || !row.bus || row.bus.decode || (row.kind !== "group" && row.kind !== "bus")) continue;
    const depth = row.depth || 0;
    let end = i;
    while (end + 1 < layout.length && (layout[end + 1].row.depth || 0) > depth) end++;
    ranges.push({ start: i, end });
  }
  return ranges;
}

function renderGutter() {
  const metrics = rowMetrics();
  const selected = new Set(ensureSelection().selection);
  const sig = [...selected].join(",") + "#" + metrics.layout.map((item) => item.row.key + signalName(item.row) + item.row.color + item.height + (state.hidden.has(item.row.key) ? "0" : "1") + (rowFolded(item.row) ? "c" : "") + (item.row.child ? "g" : "") + (item.row.depth || 0) + (selected.has(item.row.key) ? "s" : "") + ((item.row.bus && item.row.bus.radix) || "") + ((item.row.bus && item.row.bus.analog) ? "a" : "") + ((item.row.bus && item.row.bus.msbFirst) ? "m" : "") + (rowShowsAnalog(item.row) ? "A" : "D")).join("|");
  if (sig === state.gutterSig) return;
  state.gutterSig = sig;
  gutter.replaceChildren();
  const ranges = groupRanges(metrics.layout);
  for (const [index, item] of metrics.layout.entries()) {
    const row = item.row;
    const folded = rowFolded(row);
    const dim = state.hidden.has(row.key);
    const el = document.createElement("div");
    el.className = "ch" + (row.child ? " child" : "") + (selected.has(row.key) ? " selected" : "") + (dim ? " dim" : "");
    el.dataset.key = row.key;
    if (ranges.some((range) => range.start <= index && index <= range.end)) el.classList.add("group-frame");
    if (ranges.some((range) => range.start === index)) el.classList.add("group-frame-top");
    if (ranges.some((range) => range.end === index)) el.classList.add("group-frame-bottom");
    if ((row.depth || 0) > 1) el.style.setProperty("--nest", ((row.depth - 1) * 14) + "px");
    el.style.height = item.height + "px";
    el.style.flex = "none";
    el.title = row.device ? `${signalName(row)} · ${row.device}` : signalName(row);
    const bar = document.createElement("span");
    bar.className = "bar";
    const shown = traceColor(row.color);
    el.style.setProperty("--channel-color", shown);
    bar.style.background = shown;
    bar.title = "Channel color";
    if (row.kind === "logic" && signalName(row) !== row.name) {
      bar.textContent = String(originalChannelNumber(row));
      bar.classList.add("numbered");
      bar.title = `Channel ${bar.textContent} color`;
    }
    bar.addEventListener("mousedown", (ev) => {
      ev.preventDefault();
    });
    bar.addEventListener("click", (ev) => {
      ev.preventDefault();
      ev.stopPropagation();
      openColorFlyout(row, bar);
    });
    const name = document.createElement("span");
    name.className = "name";
    name.textContent = signalName(row);

    if (row.kind === "logic" || ((row.kind === "group" || row.kind === "bus") && row.bus && !row.bus.decode)) {
      name.title = "Double-click to rename";
      name.addEventListener("dblclick", (ev) => {
        ev.preventDefault();
        ev.stopPropagation();
        startRename(row, name);
      });
    }
    const kind = document.createElement("span");
    kind.className = "kind";
    kind.textContent = rowKindLabel(row);
    const eye = document.createElement("button");
    eye.type = "button";
    eye.className = "eye";
    eye.title = dim ? "Show channel" : "Hide channel";
    eye.setAttribute("aria-pressed", String(!dim));
    eye.innerHTML = eyeIcon(dim);
    eye.addEventListener("pointerdown", (ev) => ev.stopPropagation());
    eye.addEventListener("click", (ev) => {
      ev.stopPropagation();
      if (state.hidden.has(row.key)) state.hidden.delete(row.key);
      else state.hidden.add(row.key);
      state.gutterSig = "";
      renderGutter();
      drawWave();
      scheduleTiles();
    });
    const handle = document.createElement("div");
    handle.className = "row-resize";
    handle.title = "Drag to resize this row";
    handle.addEventListener("mousedown", (ev) => {
      if (ev.button !== 0) return;
      ev.preventDefault();
      ev.stopPropagation();
      startRowResize(row.key, ev.clientY);
    });
    const foldable = row.kind === "decode" || ((row.kind === "bus" || row.kind === "group") && row.bus && !row.bus.decode);
    if (foldable) el.append(bar, foldButton(row, folded), name, kind, eye, handle);
    else el.append(bar, name, kind, eye, handle);
    el.addEventListener("mousedown", (ev) => {
      if (ev.button !== 0 || ev.target.closest(".row-resize, input")) return;
      const interactive = ev.target.closest("button, .bar");
      if (!interactive && (ev.shiftKey || ev.ctrlKey || ev.metaKey)) {
        ev.preventDefault();
        applySelection(row.key, ev);
        return;
      }
      startChannelDrag(row.key, ev.clientY, !interactive && !ev.target.closest(".name"));
    });
    el.addEventListener("contextmenu", (ev) => {
      ev.preventDefault();
      if ((row.kind === "bus" || row.kind === "decode") && row.bus && row.bus.decode) {
        openBusMenu(row.bus, ev.clientX, ev.clientY);
        return;
      }
      if ((row.kind === "bus" || row.kind === "group") && row.bus && !row.bus.decode) {
        openContainerMenu(row.bus, ev.clientX, ev.clientY);
        return;
      }
      if (!ensureSelection().selection.includes(row.key)) selectOnly(row.key);
      openSignalMenu(row, ev.clientX, ev.clientY);
    });
    gutter.appendChild(el);
  }
}

function signalName(row) {
  const names = view().names;
  return (names && names[row.key]) || row.name;
}

function originalChannelNumber(row) {
  const probes = state.probes || [];
  const probe = probeForRow(row);
  if (probe) return localProbeIndex(probes, probe);
  const physical = /(?:^|\s)D(\d+)$/i.exec(row.name || "");
  return physical ? Number(physical[1]) : row.channel;
}

function startRename(row, nameEl) {
  const input = document.createElement("input");
  input.className = "rename";
  input.value = signalName(row);
  input.setAttribute("aria-label", row.kind === "logic" ? "Signal name" : "Group name");
  nameEl.replaceWith(input);
  input.focus();
  input.select();
  let done = false;
  const finish = (commit) => {
    if (done) return;
    done = true;
    if (commit) {
      const next = input.value.trim();
      const names = view().names || (view().names = {});
      if (row.kind !== "logic" && row.bus && !row.bus.decode) {
        if (next) {
          row.bus.name = next;
          delete names[row.key];
        }
      } else if (!next || next === row.name) delete names[row.key];
      else names[row.key] = next;
    }
    state.gutterSig = "";
    renderGutter();
    if (row.kind !== "logic") drawWave();
  };
  input.addEventListener("keydown", (ev) => {
    if (ev.key === "Enter") {
      ev.preventDefault();
      finish(true);
    } else if (ev.key === "Escape") {
      ev.preventDefault();
      finish(false);
    }
  });
  input.addEventListener("blur", () => finish(true));
  input.addEventListener("mousedown", (ev) => ev.stopPropagation());
}

function eyeIcon(hidden) {
  const slash = hidden ? `<path d="M4 4l16 16"></path>` : "";
  return `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"></path><circle cx="12" cy="12" r="3"></circle>${slash}</svg>`;
}

function moveChannel(fromKey, toKey) {
  if (!fromKey || fromKey === toKey) return;
  const rows = orderedRows();
  const from = rows.find((row) => row.key === fromKey);
  const to = rows.find((row) => row.key === toKey);
  if (!from || !to) return;
  const parent = sharedMemberParent(from, to);
  if (parent) {
    reorderMembers(parent, from, to);
    state.gutterSig = "";
    renderGutter();
    drawWave();
    return;
  }
  const container = dropContainer(to);
  if (container && plainLogic(from)) {
    insertChannelInContainer(from, container, to);
    return;
  }
  if (container && containerHeader(from) && Number(container.id) !== Number(from.bus.id)) {
    insertGroupInContainer(from, container, to);
    return;
  }
  if (isTopLevelRow(from) && isTopLevelRow(to)) reorderTopLevel(fromKey, toKey);
}

function plainLogic(row) {
  return !!row && row.kind === "logic" && !row.decoderId;
}

function containerHeader(row) {
  return !!(row && row.header && row.bus && !row.bus.decode && (row.kind === "group" || row.kind === "bus"));
}

function dropContainer(row) {
  if (!row) return null;
  if ((row.kind === "group" || row.kind === "bus") && row.bus && !row.bus.decode) return row.bus;
  if (row.containerId == null) return null;
  const container = sessionContainers().find((item) => Number(item.id) === Number(row.containerId));
  return container && !container.decode ? container : null;
}

function detachChannel(index) {
  const wanted = Number(index);
  for (const container of sessionContainers()) {
    container.members = (container.members || []).filter((member) => !(member.kind === "channel" && Number(member.index) === wanted));
    container.channels = container.members.filter((member) => member.kind === "channel").map((member) => Number(member.index));
  }
}

function insertChannelInContainer(fromRow, container, toRow) {
  const index = Number(fromRow.channel);
  let at = 0;
  if (!(toRow.header && toRow.bus && Number(toRow.bus.id) === Number(container.id))) {
    const target = memberPosition(container, toRow);
    at = target >= 0 ? target : (container.members || []).length;
  }
  const fromAt = memberPosition(container, fromRow);
  if (fromAt >= 0 && fromAt < at) at -= 1;
  detachChannel(index);
  const members = container.members || (container.members = []);
  members.splice(Math.max(0, Math.min(at, members.length)), 0, { kind: "channel", index });
  container.channels = members.filter((member) => member.kind === "channel").map((member) => Number(member.index));
  deleteEmptyContainers();
  state.gutterSig = "";
  renderGutter();
  drawWave();
  scheduleTiles();
}

function groupContains(container, id, guard = 0) {
  if (!container || guard > 32) return false;
  const wanted = Number(id);
  if (Number(container.id) === wanted) return true;
  for (const member of container.members || []) {
    if (member.kind !== "group") continue;
    if (Number(member.id) === wanted) return true;
    const child = sessionContainers().find((item) => Number(item.id) === Number(member.id));
    if (child && groupContains(child, wanted, guard + 1)) return true;
  }
  return false;
}

function detachGroupMember(id) {
  const wanted = Number(id);
  for (const container of sessionContainers()) {
    const members = container.members || [];
    if (!members.some((member) => member.kind === "group" && Number(member.id) === wanted)) continue;
    container.members = members.filter((member) => !(member.kind === "group" && Number(member.id) === wanted));
    container.channels = container.members.filter((member) => member.kind === "channel").map((member) => Number(member.index));
  }
}

function forgetTopLevelKey(key) {
  const order = view().order;
  if (!order || !order.includes(key)) return;
  persistOrder(order.filter((item) => item !== key));
}

function insertGroupInContainer(fromRow, container, toRow) {
  const id = Number(fromRow.bus.id);
  if (!Number.isFinite(id) || !container || Number(container.id) === id) return;
  if (groupContains(fromRow.bus, container.id)) return;
  let at = 0;
  if (!(toRow.header && toRow.bus && Number(toRow.bus.id) === Number(container.id))) {
    const target = memberPosition(container, toRow);
    at = target >= 0 ? target : (container.members || []).length;
  }
  const fromAt = memberPosition(container, fromRow);
  if (fromAt >= 0 && fromAt < at) at -= 1;
  detachGroupMember(id);
  forgetTopLevelKey("bus:" + id);
  const members = container.members || (container.members = []);
  members.splice(Math.max(0, Math.min(at, members.length)), 0, { kind: "group", id });
  container.channels = members.filter((member) => member.kind === "channel").map((member) => Number(member.index));
  deleteEmptyContainers();
  state.gutterSig = "";
  renderGutter();
  drawWave();
  scheduleTiles();
}

function isTopLevelRow(row) {
  if (!row || row.decoderId) return false;
  if (row.child && !row.header) return false;
  return (row.depth || 0) === 0;
}

function rowMemberParent(row) {
  if (!row) return null;
  if (row.kind === "logic" && !row.decoderId && row.containerId != null && !row.header) {
    return sessionContainers().find((item) => Number(item.id) === Number(row.containerId)) || null;
  }
  if (row.header && row.bus && (row.depth || 0) > 0) return parentContainer(row.bus.id);
  return null;
}

function sharedMemberParent(from, to) {
  const parent = rowMemberParent(from);
  if (!parent || parent !== rowMemberParent(to)) return null;
  if (memberPosition(parent, from) < 0 || memberPosition(parent, to) < 0) return null;
  return parent;
}

function memberPosition(container, row) {
  if (!container || !row) return -1;
  if (row.kind === "logic" && !row.decoderId && Number(row.containerId) === Number(container.id)) {
    return container.members.findIndex((member) => member.kind === "channel" && Number(member.index) === Number(row.channel));
  }
  if (row.header && row.bus && parentContainer(row.bus.id) && Number(parentContainer(row.bus.id).id) === Number(container.id)) {
    return container.members.findIndex((member) => member.kind === "group" && Number(member.id) === Number(row.bus.id));
  }
  return -1;
}

function reorderMembers(container, fromRow, toRow) {
  const from = memberPosition(container, fromRow);
  const to = memberPosition(container, toRow);
  if (from < 0 || to < 0 || from === to) return;
  const [moved] = container.members.splice(from, 1);
  container.members.splice(to, 0, moved);
  container.channels = container.members.filter((member) => member.kind === "channel").map((member) => member.index);
}

function reorderTopLevel(fromKey, toKey) {
  const keys = topLevelSource().map((row) => row.key);
  const from = keys.indexOf(fromKey);
  const to = keys.indexOf(toKey);
  if (from < 0 || to < 0) return;
  const [moved] = keys.splice(from, 1);
  keys.splice(to, 0, moved);
  const keep = (view().order || []).filter((key) => !keys.includes(key));
  persistOrder([...keys, ...keep]);
  state.gutterSig = "";
  renderGutter();
  drawWave();
}

function prep(canvas, forceHeight) {
  const dpr = window.devicePixelRatio || 1;
  const w = Math.max(1, canvas.clientWidth);
  if (forceHeight) canvas.style.height = forceHeight + "px";
  const h = Math.max(1, forceHeight || canvas.clientHeight);
  const bw = Math.floor(w * dpr);
  const bh = Math.floor(h * dpr);
  if (canvas.width !== bw || canvas.height !== bh) {
    canvas.width = bw;
    canvas.height = bh;
  }
  const ctx = canvas.getContext("2d");
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  return { ctx, w, h };
}

function drawRuler() {
  const { ctx, w, h } = prep(ruler);
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "#10151c";
  ctx.fillRect(0, 0, w, h);
  ctx.strokeStyle = "#2a3342";
  ctx.beginPath();
  ctx.moveTo(0, h - 0.5);
  ctx.lineTo(w, h - 0.5);
  ctx.stroke();
  const v = view();
  if (state.total <= 0 || state.rate <= 0) return;
  const span = (w * v.spp) / state.rate;
  const step = niceStep(span, w);
  if (step && isFinite(step)) {
    const startSec = sampleSeconds(v.start);
    const first = Math.ceil(startSec / step) * step;
    ctx.fillStyle = "#9aa6b8";
    ctx.font = "11px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    // Short subdivisions make the scale readable between labeled divisions.
    const minorStep = step / 5;
    const firstMinor = Math.ceil(startSec / minorStep);
    const lastMinor = Math.floor((startSec + span) / minorStep);
    if (minorStep / span * w >= 4) {
      ctx.strokeStyle = "#3a4658";
      ctx.beginPath();
      for (let i = firstMinor; i <= lastMinor; i++) {
        const x = ((i * minorStep * state.rate + triggerOrigin()) - v.start) / v.spp;
        ctx.moveTo(x + 0.5, h - 4);
        ctx.lineTo(x + 0.5, h);
      }
      ctx.stroke();
    }
    let lastLabel = -Infinity;
    for (let t = first; t < startSec + span + step * 0.01; t += step) {
      const x = ((t * state.rate + triggerOrigin()) - v.start) / v.spp;
      if (x < -20 || x > w + 20) continue;
      ctx.strokeStyle = "#3a4658";
      ctx.beginPath();
      ctx.moveTo(x + 0.5, h - 7);
      ctx.lineTo(x + 0.5, h);
      ctx.stroke();
      if (x - lastLabel < 72) continue;
      ctx.fillText(formatRulerTick(t, step), x, (h - 7) / 2);
      lastLabel = x;
    }
  }
  if (typeof state.triggerSample === "number" && state.triggerSample >= 0 && state.total > 0) {
    const x = (triggerOrigin() - v.start) / v.spp;
    if (x >= -8 && x <= w + 8) drawDiamond(ctx, x, h / 2, "#f0c14d");
  }
  view().markers.forEach((marker, index) => {
    const x = (marker.sample - v.start) / v.spp;
    if (x >= -8 && x <= w + 8) drawDiamond(ctx, x, h / 2, MARKER_COLORS[index % MARKER_COLORS.length]);
  });
}

function drawDiamond(ctx, x, y, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(x, y - 5);
  ctx.lineTo(x + 5, y);
  ctx.lineTo(x, y + 5);
  ctx.lineTo(x - 5, y);
  ctx.closePath();
  ctx.fill();
}

function lightTheme() {
  return document.documentElement.dataset.theme === "light";
}

function wavePalette() {
  if (lightTheme()) {
    return {
      bg: "#f4efe4",
      bgAlt: "#e6dcc8",
      ink: "#243140",
      grid: "rgba(36, 49, 64, 0.12)",
      groupBorder: "#526275",
      timeGrid: "rgba(36, 72, 110, 0.18)",
      logicGuide: "rgba(36, 49, 64, 0.16)",
      analogGuide: "rgba(36, 49, 64, 0.22)",
      label: "#3d4e62",
      hover: "rgba(23, 37, 52, 0.35)",
      empty: "#5c6b7e",
      halo: "rgba(244, 239, 228, 0.92)",
      measure: "#16345c",
    };
  }
  return {
    bg: "#0b0f14",
    bgAlt: "#141b24",
    ink: "#d5deea",
    grid: "rgba(255,255,255,0.045)",
    groupBorder: "#718198",
    timeGrid: "rgba(86, 140, 190, 0.16)",
    logicGuide: "rgba(140, 170, 200, 0.14)",
    analogGuide: "rgba(140, 170, 200, 0.18)",
    label: "rgba(176, 188, 204, 0.55)",
    hover: "rgba(255,255,255,0.28)",
    empty: "#8b95a6",
    halo: "rgba(8, 12, 18, 0.9)",
    measure: "#d5e2ff",
  };
}

function hslToHex(h, s, l) {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const hp = ((h % 360) + 360) % 360 / 60;
  const x = c * (1 - Math.abs(hp % 2 - 1));
  let r = 0;
  let g = 0;
  let b = 0;
  if (hp < 1) [r, g, b] = [c, x, 0];
  else if (hp < 2) [r, g, b] = [x, c, 0];
  else if (hp < 3) [r, g, b] = [0, c, x];
  else if (hp < 4) [r, g, b] = [0, x, c];
  else if (hp < 5) [r, g, b] = [x, 0, c];
  else [r, g, b] = [c, 0, x];
  const m = l - c / 2;
  const byte = (value) => Math.max(0, Math.min(255, Math.round((value + m) * 255))).toString(16).padStart(2, "0");
  return "#" + byte(r) + byte(g) + byte(b);
}

// Display-only. Stored channel colors stay unchanged so dark theme and the picker keep the chosen hex.
function traceColor(color) {
  if (!lightTheme()) return color;
  const text = String(color || "").trim();
  const match = /^#([0-9a-fA-F]{6})$/.exec(text);
  if (!match) return color;
  const n = parseInt(match[1], 16);
  const r = ((n >> 16) & 255) / 255;
  const g = ((n >> 8) & 255) / 255;
  const b = (n & 255) / 255;
  const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  if (lum < 0.55) return "#" + match[1].toLowerCase();
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const lightness = (max + min) / 2;
  const delta = max - min;
  const saturation = delta < 1e-6 ? 0 : delta / (1 - Math.abs(2 * lightness - 1));
  if (saturation < 0.18) return "#2c3a4a";
  let hue = 0;
  if (max === r) hue = ((g - b) / delta) % 6;
  else if (max === g) hue = (b - r) / delta + 2;
  else hue = (r - g) / delta + 4;
  hue *= 60;
  if (hue < 0) hue += 360;
  return hslToHex(hue, saturation, 0.38);
}

function drawLaneBackgrounds(ctx, width, layout, palette) {
  layout.forEach((item, index) => {
    ctx.fillStyle = index % 2 ? palette.bgAlt : palette.bg;
    ctx.fillRect(0, item.top, width, item.height);
  });
}

function drawWave() {
  const metrics = rowMetrics();
  const { ctx, w, h } = prep(wave, metrics.total);
  const palette = wavePalette();
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = palette.bg;
  ctx.fillRect(0, 0, w, h);
  const layout = metrics.layout;
  drawLaneBackgrounds(ctx, w, layout, palette);
  if (state.total <= 0 || layout.length === 0) {
    ctx.fillStyle = palette.empty;
    ctx.font = "14px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("Click Run to capture data", w / 2, h / 2);
    drawGroupBorders(ctx, w, layout, palette);
    return;
  }
  drawGrid(ctx, w, h, layout, palette);
  const endX = traceEndX(w);
  ctx.save();
  ctx.beginPath();
  ctx.rect(0, 0, Math.max(0, endX), h);
  ctx.clip();
  for (const item of layout) {
    const row = item.row;
    if (state.hidden.has(row.key)) continue;
    const cols = state.tiles[row.tileKey || row.key];
    if (!cols) continue;
    if (row.kind === "analog") drawAnalog(ctx, cols, item.top, item.height, traceColor(row.color));
    else if (row.kind === "logic") {
      if (signalMode(row.key) === "analog") drawLogicAnalog(ctx, cols, item.top, item.height, traceColor(row.color));
      else drawDigital(ctx, cols, item.top, item.height, traceColor(row.color));
    }
  }
  drawBuses(ctx, layout);
  drawCondensedRows(ctx, w, layout);
  drawDecodeOverlay(ctx, w, metrics);
  ctx.restore();
  for (const item of layout) {
    const row = item.row;
    if (row.kind !== "logic" || state.hidden.has(row.key) || signalMode(row.key) === "analog") continue;
    const top = item.top;
    const pad = Math.max(8, item.height * 0.22);
    ctx.font = "11px sans-serif";
    ctx.textAlign = "left";
    ctx.textBaseline = "middle";
    ctx.lineWidth = 3;
    ctx.strokeStyle = palette.halo;
    ctx.strokeText("H", 8, top + pad);
    ctx.strokeText("L", 8, top + item.height - pad);
    ctx.fillStyle = palette.ink;
    ctx.fillText("H", 8, top + pad);
    ctx.fillText("L", 8, top + item.height - pad);
  }
  drawGroupBorders(ctx, w, layout, palette);
  drawMeasureSpan(ctx, w, h);
  drawHoverBoundaries(ctx, w, layout);
  drawHoverSnap(ctx, layout);
  drawMarkerLines(ctx, h);
  if (pointer && pointer.kind === "cursors") {
    const v = view();
    ctx.save();
    ctx.setLineDash([3, 3]);
    ctx.strokeStyle = "#8eb6ff";
    for (const sample of [pointer.a, pointer.b]) {
      const x = (sample - v.start) / v.spp;
      ctx.beginPath();
      ctx.moveTo(x + 0.5, 0);
      ctx.lineTo(x + 0.5, h);
      ctx.stroke();
    }
    ctx.restore();
  }
  if (state.hoverX != null) {
    ctx.strokeStyle = palette.hover;
    ctx.beginPath();
    const x = state.hoverSnap ? sampleX(state.hoverSnap.sample) : state.hoverX;
    ctx.moveTo(x + 0.5, 0);
    ctx.lineTo(x + 0.5, h);
    ctx.stroke();
  }
}

// Highlight the exact logic transition selected by the hover cursor.
function drawHoverSnap(ctx, layout) {
  const snap = state.hoverSnap;
  if (!snap) return;
  const item = layout.find((entry) => entry.row.key === snap.key);
  if (!item || !["logic", "bus", "decode", "condense"].includes(item.row.kind)) return;
  const pad = Math.max(8, item.height * 0.22);
  const x = sampleX(snap.sample);
  ctx.save();
  ctx.strokeStyle = "#ffca5e";
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(x, item.top + pad);
  ctx.lineTo(x, item.top + item.height - pad);
  ctx.stroke();
  ctx.restore();
}

function drawGroupBorders(ctx, width, layout, palette) {
  ctx.save();
  ctx.strokeStyle = palette.groupBorder;
  ctx.lineWidth = 2;
  ctx.beginPath();
  for (const range of groupRanges(layout)) {
    const top = layout[range.start].top;
    const last = layout[range.end];
    const bottom = last.top + last.height;
    ctx.moveTo(0, top + 1);
    ctx.lineTo(width, top + 1);
    ctx.moveTo(0, bottom - 1);
    ctx.lineTo(width, bottom - 1);
  }
  ctx.stroke();
  ctx.restore();
}

// Temporary dimension lines connect the exact boundaries used by the hover values.
function drawHoverBoundaries(ctx, width, layout) {
  const bounds = state.hoverBounds;
  if (!bounds) return;
  const item = layout.find((entry) => entry.row.key === bounds.key);
  if (!item) return;
  const v = view();
  ctx.save();
  ctx.lineWidth = 0.65;
  ctx.beginPath();
  ctx.rect(0, item.top, width, item.height);
  ctx.clip();
  for (const [samples, color, dash, position] of [
    [[bounds.periodStart, bounds.periodEnd], "#5ac8ff", [2, 4], 0.72],
    [[bounds.pulseStart, bounds.pulseEnd], "#ffca5e", [5, 3], 0.28],
  ]) {
    ctx.strokeStyle = color;
    ctx.fillStyle = color;
    ctx.setLineDash(dash);
    for (const sample of samples) {
      if (typeof sample !== "number") continue;
      const x = (sample - v.start) / v.spp;
      if (x < 0 || x > width) continue;
      ctx.beginPath();
      ctx.moveTo(x + 0.5, item.top);
      ctx.lineTo(x + 0.5, item.top + item.height);
      ctx.stroke();
    }
    if (samples.every((sample) => typeof sample === "number") && samples[1] > samples[0]) {
      const x0 = (samples[0] - v.start) / v.spp;
      const x1 = (samples[1] - v.start) / v.spp;
      if (x1 < 0 || x0 > width) continue;
      const y = item.top + item.height * position;
      const head = Math.min(4, (x1 - x0) / 3);
      ctx.setLineDash([]);
      ctx.beginPath();
      ctx.moveTo(Math.max(0, x0), y);
      ctx.lineTo(Math.min(width, x1), y);
      ctx.stroke();
      for (const [x, direction] of [[x0, 1], [x1, -1]]) {
        if (x < 0 || x > width) continue;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x + direction * head, y - head * 0.55);
        ctx.lineTo(x + direction * head, y + head * 0.55);
        ctx.closePath();
        ctx.fill();
      }
    }
  }
  ctx.restore();
}

function drawGrid(ctx, w, h, layout, palette = wavePalette()) {
  const v = view();
  ctx.save();
  ctx.lineWidth = 1;
  if (state.rate > 0) {
    const span = (w * v.spp) / state.rate;
    const step = niceStep(span, w);
    if (step && isFinite(step)) {
      const startSec = sampleSeconds(v.start);
      const first = Math.ceil(startSec / step) * step;
      ctx.strokeStyle = palette.timeGrid;
      for (let t = first; t < startSec + span + step * 0.01; t += step) {
        const x = ((t * state.rate + triggerOrigin()) - v.start) / v.spp;
        ctx.beginPath();
        ctx.moveTo(x + 0.5, 0);
        ctx.lineTo(x + 0.5, h);
        ctx.stroke();
      }
    }
  }
  for (const item of layout) {
    const row = item.row;
    const top = item.top;
    const rowH = item.height;
    ctx.strokeStyle = palette.grid;
    ctx.beginPath();
    ctx.moveTo(0, top + 0.5);
    ctx.lineTo(w, top + 0.5);
    ctx.stroke();
    if (row.kind === "logic" && signalMode(row.key) !== "analog") {
      const pad = Math.max(8, rowH * 0.22);
      ctx.strokeStyle = palette.logicGuide;
      ctx.beginPath();
      ctx.moveTo(0, top + pad + 0.5);
      ctx.lineTo(w, top + pad + 0.5);
      ctx.moveTo(0, top + rowH - pad + 0.5);
      ctx.lineTo(w, top + rowH - pad + 0.5);
      ctx.stroke();
    } else if (row.kind === "logic" && signalMode(row.key) === "analog") {
      const pad = Math.max(8, rowH * 0.22);
      ctx.fillStyle = palette.label;
      ctx.font = "10px sans-serif";
      ctx.textAlign = "left";
      ctx.textBaseline = "middle";
      ctx.fillText("1", 6, top + pad);
      ctx.fillText("0", 6, top + rowH - pad);
    } else if (row.kind === "analog") {
      const mid = top + rowH / 2;
      ctx.strokeStyle = palette.analogGuide;
      ctx.beginPath();
      ctx.moveTo(0, mid + 0.5);
      ctx.lineTo(w, mid + 0.5);
      ctx.stroke();
      ctx.fillStyle = palette.label;
      ctx.font = "10px sans-serif";
      ctx.textAlign = "left";
      ctx.textBaseline = "middle";
      ctx.fillText("1 V", 6, top + 12);
      ctx.fillText("0 V", 6, mid);
      ctx.fillText("−1 V", 6, top + rowH - 12);
    } else if (row.kind === "bus" && row.bus && (row.bus.analog || row.bus.radix === "analog")) {
      const bits = descendantChannels(row.bus).length;
      const max = bits ? (1n << BigInt(bits)) - 1n : 1n;
      ctx.fillStyle = palette.label;
      ctx.font = "10px sans-serif";
      ctx.textAlign = "left";
      ctx.textBaseline = "middle";
      ctx.fillText("0x" + max.toString(16).toUpperCase(), 6, top + 12);
      ctx.fillText("0", 6, top + rowH - 12);
    }
  }
  ctx.restore();
}

function drawMarkerLines(ctx, h) {
  const v = view();
  ctx.save();
  ctx.setLineDash([3, 3]);
  view().markers.forEach((marker, index) => {
    if (marker.sample >= state.total) return;
    const x = (marker.sample - v.start) / v.spp;
    const color = MARKER_COLORS[index % MARKER_COLORS.length];
    ctx.strokeStyle = color;
    ctx.beginPath();
    ctx.moveTo(x + 0.5, 0);
    ctx.lineTo(x + 0.5, h);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = color;
    ctx.font = "10px sans-serif";
    ctx.textAlign = "left";
    ctx.textBaseline = "top";
    ctx.fillText("M" + marker.n, x + 4, 4);
    ctx.setLineDash([3, 3]);
  });
  ctx.restore();
}

function drawMeasureSpan(ctx, w, h) {
  const spans = view().measures.slice();
  if (pointer && pointer.kind === "measure") {
    spans.push({ a: pointer.a, b: pointer.b, live: true });
  }
  const v = view();
  ctx.save();
  for (const span of spans) {
    const left = Math.min(span.a, span.b);
    const right = Math.max(span.a, span.b);
    const x0 = (left - v.start) / v.spp;
    const x1 = (right - v.start) / v.spp;
    if (x1 < 0 || x0 > w) continue;
    ctx.fillStyle = "rgba(61, 141, 253, 0.16)";
    ctx.fillRect(x0, 0, x1 - x0, h);
    ctx.strokeStyle = "#8eb6ff";
    ctx.beginPath();
    ctx.moveTo(x0 + 0.5, 0);
    ctx.lineTo(x0 + 0.5, h);
    ctx.moveTo(x1 + 0.5, 0);
    ctx.lineTo(x1 + 0.5, h);
    ctx.stroke();
    const seconds = Math.abs(span.b - span.a) / Math.max(1, state.rate);
    ctx.fillStyle = wavePalette().measure;
    ctx.font = "11px sans-serif";
    ctx.textAlign = "left";
    ctx.textBaseline = "top";
    ctx.fillText(formatSeconds(seconds), Math.max(4, x0 + 4), 16);
  }
  ctx.restore();
}

const FRAME_CLASS = new Set(["select", "start", "stop", "ack", "nack"]);

const DECODE_FORMATS = {
  hex: "Hex",
  dec: "Decimal",
  bin: "Binary",
  oct: "Octal",
  analog: "Analog",
};

function decodePref(id) {
  if (!state.decodeView[id]) state.decodeView[id] = { overlay: true, condensed: false, format: "hex" };
  return state.decodeView[id];
}

function overlayEnabled(id) {
  const pref = state.decodeView[id];
  return !pref || pref.overlay !== false;
}

function decoderCondensed(id, lane) {
  const pref = state.decodeView[id];
  if (!pref) return false;
  return lane && pref.lanes && lane in pref.lanes ? !!pref.lanes[lane] : !!pref.condensed;
}

function decodeFormat(id) {
  const pref = state.decodeView[id];
  return pref && DECODE_FORMATS[pref.format] ? pref.format : "hex";
}

function decoderChannelIndexes(decoder) {
  return Object.values(decoder.channels || {}).map(Number).filter((index) => Number.isFinite(index));
}

function rowHiddenByDecoder(row) {
  return row.kind === "logic" && !!row.decoderId && decoderCondensed(row.decoderId, row.lane);
}

function busRadixLabel(bus) {
  if (!bus || bus.analog || bus.radix === "analog") return "Analog";
  if (bus.radix === "dec") return "Decimal";
  if (bus.radix === "bin") return "Binary";
  if (bus.radix === "oct") return "Octal";
  return "Hex";
}

function rowKindLabel(row) {
  if (row.kind === "group") return "Label";
  if (row.kind === "condense" || row.kind === "decode") {
    if (row.bus && row.bus.analog) return "Analog";
    return DECODE_FORMATS[decodeFormat(row.decoderId)] || "Hex";
  }
  if (row.kind === "analog") return "Analog";
  if (row.kind === "bus") return busRadixLabel(row.bus);
  if (row.kind === "logic" && signalMode(row.key) === "analog") return "Analog";
  return "Digital";
}

function valueAnnotations(decoder) {
  const rows = (state.waveformAnnotations || []).filter((row) => row.decoder === decoder.id);
  // WS281x also emits overlapping per-bit and full-color annotations for the
  // decode table. Waveform value views show only its eight-bit data chunks.
  if (decoder.protocol === "rgb_led_ws281x") return rows.filter((row) => row.class === "byte");
  const values = rows.filter((row) => !FRAME_CLASS.has(row.class));
  return values.length ? values : rows;
}

function annotationLabel(row) {
  if (isSpiProtocol(row.protocol) && row.fields && (row.fields.mosi || row.fields.miso)) {
    return "0x" + (row.fields.mosi || "00") + "/0x" + (row.fields.miso || "00");
  }
  return row.text || row.class || "";
}

function logicRow(layout, channel, decoderId, lane) {
  const index = Number(channel);
  if (!Number.isFinite(index)) return null;
  const matches = layout.filter((item) => item.row.kind === "logic" && item.row.channel === index && !state.hidden.has(item.row.key));
  if (decoderId) {
    const owned = matches.find((item) => item.row.decoderId === decoderId && (!lane || item.row.lane === lane));
    if (owned) return owned;
  }
  return matches.find((item) => !item.row.decoderId) || matches[0] || null;
}

function dataLineTargets(decoder) {
  const channels = decoder.channels || {};
  const text = annotationLabel;
  const specs = decoderLaneSpecs(decoder);
  if (specs.length) return specs.map((lane) => ({
    channel: channels[lane.channel], lane: lane.id,
    label: (row) => decoder.protocol === "rgb_led_ws281x"
      ? laneLabel(row, decodeFormat(decoder.id), lane.id, decoder)
      : lane.value_field && row.fields?.[lane.value_field] != null
        ? "0x" + row.fields[lane.value_field] : text(row),
  }));
  if (decoder.protocol === "i2c") return [{ channel: channels.sda, label: text }];
  if (decoder.protocol === "uart") return [{ channel: channels.rx, label: text }];
  if (decoder.protocol === "eeprom24") {
    const parent = (state.decoders || []).find((row) => row.id === decoder.stack_on);
    return [{ channel: parent && parent.channels ? parent.channels.sda : null, decoderId: parent && parent.id, label: text }];
  }
  const schema = (state.decoderCatalog || []).find((item) => item.id === decoder.protocol);
  const names = [...(schema?.channels || []), ...(schema?.optional_channels || [])];
  const first = names.find((name) => channels[name] != null);
  if (first != null) return [{ channel: channels[first], label: text }];
  const parent = (state.decoders || []).find((row) => row.id === decoder.stack_on);
  return parent ? dataLineTargets(parent).map((target) => ({ ...target, decoderId: target.decoderId || parent.id, label: text })) : [];
}

function laneAnnotations(rows, lane, decoder) {
  if (!lane) return rows;
  const spec = decoderLaneSpecs(decoder).find((item) => item.id === lane);
  if (!spec) return [];
  return rows.filter((row) => spec.classes.includes(row.class) &&
    (!spec.value_field || row.fields?.[spec.value_field] != null));
}

function laneValue(row, decoder, lane) {
  const spec = decoderLaneSpecs(decoder).find((item) => item.id === lane);
  return spec?.value_field ? row.fields?.[spec.value_field] : null;
}

function traceHexagon(ctx, x, y, w, h) {
  const point = Math.max(3, Math.min(14, h * 0.42, w * 0.28));
  ctx.beginPath();
  ctx.moveTo(x + point, y);
  ctx.lineTo(x + w - point, y);
  ctx.lineTo(x + w, y + h / 2);
  ctx.lineTo(x + w - point, y + h);
  ctx.lineTo(x + point, y + h);
  ctx.lineTo(x, y + h / 2);
  ctx.closePath();
}

function drawHexagons(ctx, rows, top, bottom, color, canvasW, labelOf, alpha, dataRow = false) {
  if (dataRow) {
    const spans = rows.map((row) => [sampleX(row.start_sample), Math.max(sampleX(row.start_sample) + 2, sampleX(row.end_sample))])
      .filter(([start, end]) => end >= 0 && start <= canvasW).sort((a, b) => a[0] - b[0]);
    ctx.save();
    ctx.strokeStyle = traceColor(color || "#3d8dfd");
    ctx.lineWidth = 1.25;
    ctx.beginPath();
    let end = 0;
    for (const [start, finish] of spans) {
      if (start > end) { ctx.moveTo(end, (top + bottom) / 2); ctx.lineTo(start, (top + bottom) / 2); }
      end = Math.max(end, finish);
    }
    if (end < canvasW) { ctx.moveTo(end, (top + bottom) / 2); ctx.lineTo(canvasW, (top + bottom) / 2); }
    ctx.stroke();
    ctx.restore();
  }
  const height = Math.max(12, bottom - top);
  let lastLabel = -1;
  ctx.lineWidth = 1.25;
  for (const row of rows) {
    const x0 = sampleX(row.start_sample);
    const x1 = Math.max(x0 + 2, sampleX(row.end_sample));
    if (x1 < 0 || x0 > canvasW) continue;
    const width = x1 - x0;
    traceHexagon(ctx, x0, top, width, height);
    const shown = traceColor(color || "#3d8dfd");
    ctx.save();
    ctx.fillStyle = shown;
    ctx.globalAlpha = alpha == null ? 0.36 : alpha;
    ctx.fill();
    ctx.globalAlpha = 0.92;
    ctx.strokeStyle = shown;
    ctx.stroke();
    ctx.restore();
    const label = labelOf(row);
    const point = Math.max(3, Math.min(14, height * 0.42, width * 0.28));
    if (width < point * 2 + 20 || x0 < lastLabel) continue;
    ctx.save();
    ctx.beginPath();
    ctx.rect(x0 + point, top, Math.max(0, width - point * 2), height);
    ctx.clip();
    ctx.fillStyle = lightTheme() && (alpha == null || alpha < 0.7) ? wavePalette().ink : "#f7fafc";
    ctx.textAlign = dataRow ? "center" : "left";
    ctx.fillText(label, dataRow ? x0 + width / 2 : x0 + point + 4, top + height / 2);
    ctx.restore();
    lastLabel = x0 + Math.min(width, ctx.measureText(label).width + point + 10);
  }
}

function drawDecodeOverlay(ctx, canvasW, metrics) {
  const layout = metrics.layout;
  ctx.save();
  ctx.font = "12px sans-serif";
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";
  for (const decoder of state.decoders || []) {
    const rows = valueAnnotations(decoder);
    if (!rows.length) continue;
    if (!overlayEnabled(decoder.id)) continue;
    for (const target of dataLineTargets(decoder)) {
      if (target.channel == null || decoderCondensed(decoder.id, target.lane)) continue;
      const item = logicRow(layout, target.channel, target.decoderId || decoder.id, target.lane);
      if (!item) continue;
      const pad = Math.max(8, item.height * 0.22);
      drawHexagons(ctx, laneAnnotations(rows, target.decoderId ? "" : target.lane, decoder), item.top + pad, item.top + item.height - pad, traceColor(item.row.color), canvasW, target.label);
    }
  }
  ctx.restore();
}

function annotationNumbers(row) {
  const fields = row.fields || {};
  if (isSpiProtocol(row.protocol) && (fields.mosi || fields.miso)) {
    const out = [];
    if (fields.mosi) out.push(parseInt(fields.mosi, 16));
    if (fields.miso) out.push(parseInt(fields.miso, 16));
    return out.filter((value) => Number.isFinite(value));
  }
  if (fields.value && /^[0-9a-f]+$/i.test(fields.value)) return [parseInt(fields.value, 16)].filter((value) => Number.isFinite(value));
  if (fields.data) return [parseInt(fields.data, 16)].filter((value) => Number.isFinite(value));
  if (fields.address) return [parseInt(fields.address, 16)].filter((value) => Number.isFinite(value));
  return [];
}

function formatDecoded(value, format, bitWidth = 8) {
  const n = value;
  if (format === "dec") return String(n);
  if (format === "bin") return n.toString(2).padStart(bitWidth, "0");
  if (format === "oct") return n.toString(8);
  return "0x" + n.toString(16).toUpperCase().padStart(Math.ceil(bitWidth / 4), "0");
}

function condensedLabel(row, format) {
  const parts = annotationNumbers(row).map((value) => formatDecoded(value, format));
  return parts.length ? parts.join(" / ") : annotationLabel(row);
}

function laneLabel(row, format, lane, decoder) {
  const raw = laneValue(row, decoder, lane);
  if (raw == null || raw === "") return annotationLabel(row);
  const value = /^[0-9a-f]+$/i.test(String(raw)) ? parseInt(raw, 16) : NaN;
  return Number.isFinite(value) ? formatDecoded(value, format, decoder.protocol === "rgb_led_ws281x" ? String(raw).length * 4 : 8) : String(raw);
}

function drawStepSeries(ctx, rows, top, bot, color, valueOf) {
  const max = 255;
  ctx.beginPath();
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.6;
  let started = false;
  for (const row of rows) {
    const value = valueOf(row);
    if (!Number.isFinite(value)) continue;
    const y = bot - (Math.max(0, Math.min(max, value)) / max) * (bot - top);
    const x0 = sampleX(row.start_sample);
    const x1 = Math.max(x0 + 1, sampleX(row.end_sample));
    if (!started) {
      ctx.moveTo(x0, y);
      started = true;
    } else ctx.lineTo(x0, y);
    ctx.lineTo(x1, y);
  }
  ctx.stroke();
}

function drawCondensedRows(ctx, canvasW, layout) {
  for (const item of layout) {
    if (item.row.kind !== "condense" && item.row.kind !== "decode") continue;
    if (state.hidden.has(item.row.key)) continue;
    const decoder = (state.decoders || []).find((row) => row.id === item.row.decoderId);
    if (!decoder) continue;
    const rows = laneAnnotations(valueAnnotations(decoder), item.row.lane, decoder);
    const format = item.row.bus && item.row.bus.analog ? "analog" : decodeFormat(decoder.id);
    const pad = Math.max(8, item.height * 0.22);
    const bandTop = item.top + pad;
    const bandBot = item.top + item.height - pad;
    if (format === "analog") {
      const lane = item.row.lane;
      if (lane) {
        drawStepSeries(ctx, rows, bandTop, bandBot, traceColor(item.row.color), (row) => parseInt(laneValue(row, decoder, lane), 16));
      } else {
        const fields = rows[0] && rows[0].fields;
        if (fields && (fields.mosi || fields.miso)) {
          drawStepSeries(ctx, rows, bandTop, bandBot, traceColor("#ff6b8a"), (row) => parseInt((row.fields || {}).mosi, 16));
          drawStepSeries(ctx, rows, bandTop, bandBot, traceColor("#7dcea0"), (row) => parseInt((row.fields || {}).miso, 16));
        } else {
          drawStepSeries(ctx, rows, bandTop, bandBot, traceColor(item.row.color || "#8eb6ff"), (row) => {
            const values = annotationNumbers(row);
            return values.length ? values[0] : NaN;
          });
        }
      }
      ctx.fillStyle = wavePalette().label;
      ctx.font = "10px sans-serif";
      ctx.textAlign = "left";
      ctx.textBaseline = "middle";
      ctx.fillText("255", 6, bandTop + 8);
      ctx.fillText("0", 6, bandBot - 6);
      continue;
    }
    const hexH = Math.min(48, Math.max(16, bandBot - bandTop));
    const mid = (bandTop + bandBot) / 2;
    const labelOf = item.row.lane ? (row) => laneLabel(row, format, item.row.lane, decoder) : (row) => condensedLabel(row, format);
    drawHexagons(ctx, rows, mid - hexH / 2, mid + hexH / 2, traceColor(item.row.color), canvasW, labelOf, 0.82, true);
  }
}

function spiWords(decoderId) {
  return (state.waveformAnnotations || []).filter((row) => row.decoder === decoderId && row.class === "word" && row.fields);
}

function hexByte(text) {
  const value = parseInt(text, 16);
  return Number.isFinite(value) ? value : 0;
}

function sampleX(sample) {
  return (sample - view().start) / view().spp;
}

function tileSample(index) {
  const tile = state.tileView;
  if (!tile || !(tile.spp > 0)) return view().start + index * view().spp;
  return tile.start + index * tile.spp;
}

function traceX(index) {
  const v = view();
  const tile = state.tileView;
  const spp = tile && tile.spp > 0 ? tile.spp : v.spp;
  return (tileSample(index) + spp * 0.5 - v.start) / Math.max(v.spp, 1e-9);
}

function drawDigital(ctx, cols, top, height, color) {
  const pad = Math.max(8, height * 0.22);
  const yTop = top + pad;
  const yBot = top + height - pad;
  const yOf = (high) => (high ? yTop : yBot);
  ctx.beginPath();
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.6;
  let prev = null;
  for (let i = 0; i < cols.length; i++) {
    if (tileSample(i) >= state.total) break;
    const column = cols[i];
    if (!column || column.valid === false) break;
    const x = traceX(i);
    if (column.toggled) {
      const yLast = yOf(column.last);
      if (prev == null) ctx.moveTo(x, yOf(column.first));
      ctx.lineTo(x, yTop);
      ctx.lineTo(x, yBot);
      ctx.lineTo(x, yLast);
      prev = yLast;
    } else {
      const y = yOf(column.last);
      if (prev == null) ctx.moveTo(x, y);
      else if (prev !== y) {
        ctx.lineTo(x, prev);
        ctx.lineTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
      prev = y;
    }
  }
  ctx.stroke();
}

function drawLogicAnalog(ctx, cols, top, height, color) {
  const pad = Math.max(8, height * 0.22);
  const yTop = top + pad;
  const yBot = top + height - pad;
  const yOf = (high) => (high ? yTop : yBot);
  ctx.beginPath();
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.4;
  let prev = null;
  for (let i = 0; i < cols.length; i++) {
    if (tileSample(i) >= state.total) break;
    const column = cols[i];
    if (!column || column.valid === false) break;
    const x = traceX(i);
    const y = yOf(!!column.last);
    if (prev == null) ctx.moveTo(x, y);
    else if (prev !== y) {
      ctx.lineTo(x, prev);
      ctx.lineTo(x, y);
    } else ctx.lineTo(x, y);
    prev = y;
  }
  ctx.stroke();
}

function drawAnalog(ctx, cols, top, height, color) {
  const pad = 10;
  const y0 = top + pad;
  const y1 = top + height - pad;
  const scaleMin = -1.25;
  const scaleMax = 1.25;
  const yOf = (value) => {
    const t = (value - scaleMin) / (scaleMax - scaleMin);
    return y1 - t * (y1 - y0);
  };
  const usable = (column, index) => {
    if (tileSample(index) >= state.total || !column || column.valid === false) return false;
    if (!Number.isFinite(column.min) || !Number.isFinite(column.max)) return false;
    if (Math.abs(column.min) > 20 || Math.abs(column.max) > 20) return false;
    return true;
  };
  ctx.beginPath();
  let started = false;
  for (let i = 0; i < cols.length; i++) {
    if (tileSample(i) >= state.total) break;
    const column = cols[i];
    if (!usable(column, i)) continue;
    const x = traceX(i);
    if (!started) {
      ctx.moveTo(x, yOf(column.max));
      started = true;
    } else ctx.lineTo(x, yOf(column.max));
  }
  for (let i = cols.length - 1; i >= 0; i--) {
    if (tileSample(i) >= state.total) continue;
    const column = cols[i];
    if (!usable(column, i)) continue;
    ctx.lineTo(traceX(i), yOf(column.min));
  }
  if (started) {
    ctx.closePath();
    ctx.save();
    ctx.globalAlpha = 0.22;
    ctx.fillStyle = color;
    ctx.fill();
    ctx.restore();
  }
  ctx.beginPath();
  started = false;
  for (let i = 0; i < cols.length; i++) {
    if (tileSample(i) >= state.total) break;
    const column = cols[i];
    if (!usable(column, i)) continue;
    const y = yOf((column.min + column.max) / 2);
    if (!started) {
      ctx.moveTo(traceX(i), y);
      started = true;
    } else ctx.lineTo(traceX(i), y);
  }
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.4;
  ctx.stroke();
}

function busValueAt(bus, index, channels) {
  const bitsSource = channels || descendantChannels(bus);
  let value = 0n;
  const bits = bitsSource.length;
  for (let bit = 0; bit < bits; bit++) {
    const cols = state.tiles["logic:" + bitsSource[bit]];
    const column = cols && cols[index];
    if (!(column && column.valid !== false && column.last)) continue;
    const shift = bus.msbFirst ? BigInt(bits - 1 - bit) : BigInt(bit);
    value |= 1n << shift;
  }
  return value;
}

function formatBusValue(value, radix, bits) {
  if (radix === "dec") return value.toString(10);
  if (radix === "bin") return value.toString(2).padStart(Math.max(1, bits), "0");
  if (radix === "oct") return value.toString(8);
  return "0x" + value.toString(16).toUpperCase();
}

function drawDecodeBus(ctx, item, bus) {
  const words = spiWords(bus.decode);
  const pad = Math.max(8, item.height * 0.22);
  const top = item.top + pad;
  const bot = item.top + item.height - pad;
  const max = 255;
  if (bus.analog) {
    const stroke = (key, color) => {
      ctx.beginPath();
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.4;
      let started = false;
      for (const word of words) {
        const y = bot - (hexByte(word.fields[key]) / max) * (bot - top);
        const x0 = sampleX(word.start_sample);
        const x1 = sampleX(word.end_sample);
        if (!started) {
          ctx.moveTo(x0, y);
          started = true;
        } else ctx.lineTo(x0, y);
        ctx.lineTo(x1, y);
      }
      ctx.stroke();
    };
    stroke("mosi", traceColor("#ff6b8a"));
    stroke("miso", traceColor("#7dcea0"));
    return;
  }
  ctx.font = "12px sans-serif";
  ctx.textBaseline = "middle";
  ctx.fillStyle = wavePalette().ink;
  let lastX = -80;
  for (const word of words) {
    const x = sampleX(word.start_sample);
    if (x < -8 || x - lastX < 72) continue;
    const label = "0x" + (word.fields.mosi || "00") + "/0x" + (word.fields.miso || "00");
    ctx.fillText(label, x + 4, (top + bot) / 2);
    lastX = x;
  }
}

function drawLabelBar(ctx, item) {
  const pad = Math.max(8, item.height * 0.22);
  const span = Math.max(1, item.height - pad * 2);
  const barH = Math.max(2, span / 3);
  const y = item.top + (item.height - barH) / 2;
  ctx.fillStyle = traceColor(item.row.color);
  ctx.fillRect(0, y, Math.max(wave.clientWidth || 0, 1), barH);
}

function busColumns(channels) {
  let cols = null;
  for (const index of channels) {
    const candidate = state.tiles["logic:" + index];
    if (candidate && (!cols || candidate.length > cols.length)) cols = candidate;
  }
  return cols;
}

function busValueRuns(bus, channels, cols) {
  const bits = channels.length;
  const runs = [];
  let prev = null;
  let start = 0;
  let last = -1;
  for (let i = 0; i < cols.length; i++) {
    if (tileSample(i) >= state.total) break;
    last = i;
    const value = busValueAt(bus, i, channels);
    if (prev == null) {
      prev = value;
      start = i;
      continue;
    }
    if (value !== prev) {
      runs.push({ start_sample: tileSample(start), end_sample: tileSample(i), value: prev, bits });
      prev = value;
      start = i;
    }
  }
  if (prev != null && last >= start) {
    const spp = state.tileView && state.tileView.spp > 0 ? state.tileView.spp : view().spp;
    runs.push({
      start_sample: tileSample(start),
      end_sample: tileSample(last) + spp,
      value: prev,
      bits,
    });
  }
  return runs;
}

function drawBuses(ctx, layout) {
  const canvasW = Math.max(wave.clientWidth || 0, 1);
  for (const item of layout) {
    const row = item.row;
    if ((row.kind !== "bus" && row.kind !== "group") || state.hidden.has(row.key)) continue;
    const bus = row.bus;
    if (!bus) continue;
    if (bus.decode) {
      if (row.kind === "bus") drawDecodeBus(ctx, item, bus);
      continue;
    }
    if (bus.type === "group" || row.kind === "group") {
      drawLabelBar(ctx, item);
      continue;
    }
    const channels = descendantChannels(bus);
    if (!channels.length) continue;
    const cols = busColumns(channels);
    if (!cols) continue;
    const pad = Math.max(8, item.height * 0.22);
    const top = item.top + pad;
    const bot = item.top + item.height - pad;
    const bits = channels.length;
    const color = traceColor(row.color);
    const analog = bus.analog || bus.radix === "analog";
    if (analog) {
      const max = Number((1n << BigInt(bits)) - 1n) || 1;
      ctx.beginPath();
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.4;
      let started = false;
      for (let i = 0; i < cols.length; i++) {
        if (tileSample(i) >= state.total) break;
        const y = bot - (Number(busValueAt(bus, i, channels)) / max) * (bot - top);
        const x = traceX(i);
        if (!started) {
          ctx.moveTo(x, y);
          started = true;
        } else ctx.lineTo(x, y);
      }
      ctx.stroke();
      continue;
    }
    const runs = busValueRuns(bus, channels, cols);
    const hexH = Math.min(48, Math.max(16, bot - top));
    const mid = (top + bot) / 2;
    ctx.font = "12px sans-serif";
    ctx.textAlign = "left";
    ctx.textBaseline = "middle";
    drawHexagons(ctx, runs, mid - hexH / 2, mid + hexH / 2, color, canvasW, (run) => formatBusValue(run.value, bus.radix || "hex", run.bits), 0.82, true);
  }
}

function overviewTargetRow() {
  const selection = ensureSelection().selection || [];
  const firstKey = selection[0] || null;
  if (firstKey) {
    const found = layoutRows().find((row) => row.key === firstKey);
    if (found) return found;
  }
  const channel = state.channels.find((item) => item.index === 0) || state.channels[0];
  return channel ? logicRowModel(channel, "") : null;
}

function overviewStrokeColor(row) {
  if (!row) return "#3dcc8e";
  return traceColor(row.color || "#3dcc8e");
}

function drawOverviewDigital(ctx, cols, w, h, color) {
  if (!cols || !cols.length) return;
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  let moved = false;
  let prev = null;
  for (let i = 0; i < cols.length; i++) {
    const column = cols[i];
    if (!column || column.valid === false) break;
    const x = (i + 0.5) * (w / cols.length);
    const y = column.last ? 6 : h - 6;
    if (!moved) {
      ctx.moveTo(x, y);
      moved = true;
    } else if (prev !== y) {
      ctx.lineTo(x, prev);
      ctx.lineTo(x, y);
    } else ctx.lineTo(x, y);
    prev = y;
    if (column.toggled) {
      ctx.lineTo(x, 6);
      ctx.lineTo(x, h - 6);
      ctx.lineTo(x, y);
    }
  }
  ctx.stroke();
}

function drawOverviewLogicAnalog(ctx, cols, w, h, color) {
  if (!cols || !cols.length) return;
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  let moved = false;
  let prev = null;
  for (let i = 0; i < cols.length; i++) {
    const column = cols[i];
    if (!column || column.valid === false) break;
    const x = (i + 0.5) * (w / cols.length);
    const y = column.last ? 6 : h - 6;
    if (!moved) {
      ctx.moveTo(x, y);
      moved = true;
    } else if (prev !== y) {
      ctx.lineTo(x, prev);
      ctx.lineTo(x, y);
    } else ctx.lineTo(x, y);
    prev = y;
  }
  ctx.stroke();
}

function drawOverviewAnalogSamples(ctx, cols, w, h, color) {
  if (!cols || !cols.length) return;
  const scaleMin = -1.25;
  const scaleMax = 1.25;
  const yOf = (value) => {
    const t = (value - scaleMin) / (scaleMax - scaleMin);
    return (h - 6) - Math.max(0, Math.min(1, t)) * (h - 12);
  };
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  let moved = false;
  for (let i = 0; i < cols.length; i++) {
    const column = cols[i];
    if (!column || column.valid === false) continue;
    if (!Number.isFinite(column.min) || !Number.isFinite(column.max)) continue;
    const x = (i + 0.5) * (w / cols.length);
    const y = yOf((column.min + column.max) / 2);
    if (!moved) {
      ctx.moveTo(x, y);
      moved = true;
    } else ctx.lineTo(x, y);
  }
  ctx.stroke();
}

function drawOverviewBusAnalog(ctx, channelCols, bus, w, h, color) {
  const channels = descendantChannels(bus);
  if (!channels.length || !channelCols) return;
  const bits = channels.length;
  const max = Number((1n << BigInt(bits)) - 1n) || 1;
  const length = channelCols[channels[0]] ? channelCols[channels[0]].length : 0;
  if (!length) return;
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  let moved = false;
  for (let i = 0; i < length; i++) {
    let value = 0n;
    for (let bit = 0; bit < bits; bit++) {
      const cols = channelCols[channels[bit]];
      const column = cols && cols[i];
      if (!(column && column.valid !== false && column.last)) continue;
      const shift = bus.msbFirst ? BigInt(bits - 1 - bit) : BigInt(bit);
      value |= 1n << shift;
    }
    const y = (h - 6) - (Number(value) / max) * (h - 12);
    const x = (i + 0.5) * (w / length);
    if (!moved) {
      ctx.moveTo(x, y);
      moved = true;
    } else ctx.lineTo(x, y);
  }
  ctx.stroke();
}

function drawOverviewDecodeAnalog(ctx, row, w, h, color) {
  const decoder = (state.decoders || []).find((item) => item.id === row.decoderId);
  if (!decoder) return;
  const rows = laneAnnotations(valueAnnotations(decoder), row.lane, decoder);
  if (!rows.length || state.total <= 0) return;
  const valueOf = (entry) => {
    if (row.lane) {
      const raw = laneValue(entry, decoder, row.lane);
      const parsed = parseInt(raw, 16);
      return Number.isFinite(parsed) ? parsed : NaN;
    }
    const fields = entry.fields || {};
    if (fields.mosi || fields.miso) {
      const parsed = parseInt(fields.mosi || fields.miso, 16);
      return Number.isFinite(parsed) ? parsed : NaN;
    }
    const values = annotationNumbers(entry);
    return values.length ? values[0] : NaN;
  };
  const max = 255;
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  let moved = false;
  let prevY = null;
  for (const entry of rows) {
    const value = valueOf(entry);
    if (!Number.isFinite(value)) continue;
    const y = (h - 6) - (Math.max(0, Math.min(max, value)) / max) * (h - 12);
    const x0 = (entry.start_sample / state.total) * w;
    const x1 = Math.max(x0 + 1, (entry.end_sample / state.total) * w);
    if (!moved) {
      ctx.moveTo(x0, y);
      moved = true;
    } else if (prevY != null) ctx.lineTo(x0, prevY);
    ctx.lineTo(x0, y);
    ctx.lineTo(x1, y);
    prevY = y;
  }
  ctx.stroke();
}

function drawOverview() {
  const { ctx, w, h } = prep(overview);
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "#10151c";
  ctx.fillRect(0, 0, w, h);
  const snap = state.overviewSnap;
  if (snap && state.total > 0) {
    const color = overviewStrokeColor(snap.row);
    if (snap.mode === "analog-samples") drawOverviewAnalogSamples(ctx, snap.cols, w, h, color);
    else if (snap.mode === "bus-analog") drawOverviewBusAnalog(ctx, snap.channelCols, snap.bus, w, h, color);
    else if (snap.mode === "decode-analog") drawOverviewDecodeAnalog(ctx, snap.row, w, h, color);
    else if (snap.mode === "logic-analog") drawOverviewLogicAnalog(ctx, snap.cols, w, h, color);
    else drawOverviewDigital(ctx, snap.cols, w, h, color);
  }
  if (state.total > 0) {
    const v = view();
    const x0 = (v.start / state.total) * w;
    const x1 = Math.min(w, ((v.start + wave.clientWidth * v.spp) / state.total) * w);
    ctx.fillStyle = "rgba(76, 141, 255, 0.18)";
    ctx.strokeStyle = "rgba(76, 141, 255, 0.9)";
    ctx.fillRect(x0, 2, Math.max(2, x1 - x0), h - 4);
    ctx.strokeRect(x0 + 0.5, 2.5, Math.max(2, x1 - x0), h - 5);
  }
}

function scheduleTiles() {
  scheduleWaveformAnnotations();
  tileAgain = true;
  if (tileFlight) return;
  tileFlight = true;
  runTiles();
}

async function runTiles() {
  try {
    while (tileAgain) {
      tileAgain = false;
      await fetchTiles();
    }
  } finally {
    tileFlight = false;
    if (tileAgain) scheduleTiles();
  }
}

function tileRequests() {
  const seen = new Set();
  const rows = [];
  const add = (row, key) => {
    if (seen.has(key)) return;
    seen.add(key);
    rows.push({ row, key });
  };
  for (const row of visibleRows()) {
    if (row.kind !== "logic" && row.kind !== "analog") continue;
    add(row, row.tileKey || row.key);
  }
  for (const bus of sessionContainers()) {
    if (bus.type === "group" || bus.decode) continue;
    for (const index of descendantChannels(bus)) {
      add({ kind: "logic", channel: index, tileKey: "logic:" + index }, "logic:" + index);
    }
  }
  return rows;
}

async function fetchTiles() {
  const requests = tileRequests();
  const viewWidth = Math.max(1, Math.floor(wave.clientWidth || 1));
  const width = Math.min(8192, viewWidth * 2);
  const v = view();
  const req = ++state.req;
  const spp = Math.max(v.spp, 1e-9);
  const viewStart = v.start;
  const start = Math.max(0, viewStart - Math.floor((width - viewWidth) / 2) * spp);
  if (requests.length === 0) {
    state.tiles = {};
    drawWave();
    drawRuler();
    return;
  }
  const pending = { req, got: {}, expect: requests.length, start, spp, width };
  state.pending = pending;
  const bodies = requests.map(({ row, key }) => ({
    cmd: "tile",
    req,
    session: state.active,
    channel: row.channel,
    start,
    columns: width,
    samples_per_pixel: spp,
    kind: row.kind,
    key,
  }));
  const sent = socket && socket.readyState === WebSocket.OPEN;
  if (sent) {
    await new Promise((resolve) => {
      let settled = false;
      const finish = () => {
        if (settled) return;
        settled = true;
        if (pending.timer) clearTimeout(pending.timer);
        resolve();
      };
      pending.done = finish;
      pending.timer = setTimeout(async () => {
        if (state.req === req && Object.keys(pending.got).length < requests.length) {
          await httpTiles(req, bodies, pending);
        }
        finish();
      }, 280);
      for (const body of bodies) socket.send(JSON.stringify(body));
      if (Object.keys(pending.got).length >= requests.length) finish();
    });
  } else {
    await httpTiles(req, bodies, pending);
  }
  if (state.req !== req) return;
  const now = view();
  const widthNow = Math.max(1, Math.floor(wave.clientWidth || 1));
  if (now.spp !== spp || widthNow !== viewWidth) {
    tileAgain = true;
    return;
  }
  const got = Object.keys(pending.got).length;
  if (got) {
    const previous = state.tileView;
    const sameTileView = previous
      && previous.start === start
      && previous.spp === spp
      && previous.width === width;
    const next = { start, spp, width };
    const panning = pointer && pointer.kind === "pan";
    const accept = sameTileView || (
      !panning || tileOverlap(next, now.start, now.spp, widthNow) >= tileOverlap(previous, now.start, now.spp, widthNow)
    );
    if (accept) {
      state.tiles = sameTileView ? Object.assign({}, state.tiles, pending.got) : pending.got;
      state.tileView = next;
      if (panning) scheduleViewPaint();
      else {
        drawWave();
        drawRuler();
      }
    }
  }
  if (now.start !== viewStart && !tileCoversView(state.tileView, now.start, now.spp, widthNow)) tileAgain = true;
}

function tileCoversView(tile, start, spp, width) {
  if (!tile || tile.spp !== spp) return false;
  const epsilon = spp * 1e-6;
  return start >= tile.start - epsilon && start + width * spp <= tile.start + tile.width * tile.spp + epsilon;
}

function tileOverlap(tile, viewStart, viewSpp, viewWidth) {
  if (!tile || !(tile.spp > 0) || !(viewSpp > 0)) return 0;
  const a0 = tile.start;
  const a1 = tile.start + tile.width * tile.spp;
  const b0 = viewStart;
  const b1 = viewStart + viewWidth * viewSpp;
  return Math.max(0, Math.min(a1, b1) - Math.max(a0, b0));
}

async function httpTiles(req, bodies, pending) {
  await Promise.all(bodies.map(async (body) => {
    if (pending.got[body.key]) return;
    try {
      const data = await api(body);
      if (state.req !== req) return;
      pending.got[body.key] = data.columns;
    } catch (_) { /* a channel left out of this capture has no tile */ }
  }));
}

function onTileFrame(frame) {
  const pending = state.pending;
  if (!frame || !pending || frame.req !== pending.req || frame.req !== state.req) return;
  const key = (frame.kind === 2 ? "analog:" : "logic:") + frame.channel;
  pending.got[key] = frame.columns;
  if (Object.keys(pending.got).length >= pending.expect) {
    if (pending.timer) clearTimeout(pending.timer);
    if (pending.done) pending.done();
  }
}

function parseFrame(buffer) {
  const viewBytes = new DataView(buffer);
  if (buffer.byteLength < 32) return null;
  const magic = String.fromCharCode(viewBytes.getUint8(0), viewBytes.getUint8(1), viewBytes.getUint8(2), viewBytes.getUint8(3));
  if (magic !== "LVT1") return null;
  const kind = viewBytes.getUint8(5);
  const channel = viewBytes.getUint16(6, true);
  const req = viewBytes.getUint32(8, true);
  const count = viewBytes.getUint32(12, true);
  const columns = [];
  if (kind === 1) {
    for (let i = 0; i < count; i++) {
      const o = 32 + i * 5;
      if (o + 5 > buffer.byteLength) break;
      columns.push({
        first: viewBytes.getUint8(o) !== 0,
        last: viewBytes.getUint8(o + 1) !== 0,
        toggled: viewBytes.getUint8(o + 2) !== 0,
        edges: viewBytes.getUint8(o + 3),
        valid: viewBytes.getUint8(o + 4) !== 0,
      });
    }
  } else {
    for (let i = 0; i < count; i++) {
      const o = 32 + i * 8;
      if (o + 8 > buffer.byteLength) break;
      const min = viewBytes.getFloat32(o, true);
      const max = viewBytes.getFloat32(o + 4, true);
      columns.push({ min, max, valid: Number.isFinite(min) && Number.isFinite(max) });
    }
  }
  return { kind, channel, req, columns };
}

let overviewToken = 0;

async function fetchOverviewTile(channel, kind, columns) {
  const data = await api({
    cmd: "tile",
    session: state.active,
    channel,
    start: 0,
    columns,
    samples_per_pixel: state.total / columns,
    kind,
  });
  return data.columns || null;
}

async function refreshOverview() {
  const token = ++overviewToken;
  if (state.total <= 0) {
    state.overviewCols = null;
    state.overviewSnap = null;
    drawOverview();
    return;
  }
  const columns = Math.max(8, Math.floor(overview.clientWidth || 200));
  const row = overviewTargetRow();
  try {
    let snap = null;
    if (!row) {
      const cols = await fetchOverviewTile(0, "logic", columns);
      if (token !== overviewToken) return;
      snap = { mode: "digital", cols, row: null };
    } else if (row.kind === "analog") {
      const cols = await fetchOverviewTile(row.channel, "analog", columns);
      if (token !== overviewToken) return;
      snap = { mode: "analog-samples", cols, row };
    } else if ((row.kind === "bus" || row.kind === "group") && row.bus && !row.bus.decode) {
      if (row.bus.type === "group" || row.kind === "group") {
        const channels = descendantChannels(row.bus);
        const channel = channels[0] ?? 0;
        const cols = await fetchOverviewTile(channel, "logic", columns);
        if (token !== overviewToken) return;
        snap = { mode: "digital", cols, row };
      } else if (row.bus.analog || row.bus.radix === "analog") {
        const channels = descendantChannels(row.bus);
        const channelCols = {};
        await Promise.all(channels.map(async (index) => {
          channelCols[index] = await fetchOverviewTile(index, "logic", columns);
        }));
        if (token !== overviewToken) return;
        snap = { mode: "bus-analog", channelCols, bus: row.bus, row };
      } else {
        const channels = descendantChannels(row.bus);
        const channel = channels[0] ?? 0;
        const cols = await fetchOverviewTile(channel, "logic", columns);
        if (token !== overviewToken) return;
        snap = { mode: "digital", cols, row };
      }
    } else if ((row.kind === "decode" || row.kind === "condense" || row.kind === "bus") && row.bus && row.bus.decode) {
      if (rowShowsAnalog(row)) {
        if (token !== overviewToken) return;
        snap = { mode: "decode-analog", row };
      } else {
        const cols = await fetchOverviewTile(row.channel ?? 0, "logic", columns);
        if (token !== overviewToken) return;
        snap = { mode: "digital", cols, row };
      }
    } else if (row.kind === "logic") {
      const cols = await fetchOverviewTile(row.channel, "logic", columns);
      if (token !== overviewToken) return;
      snap = {
        mode: signalMode(row.key) === "analog" ? "logic-analog" : "digital",
        cols,
        row,
      };
    } else {
      const cols = await fetchOverviewTile(0, "logic", columns);
      if (token !== overviewToken) return;
      snap = { mode: "digital", cols, row };
    }
    state.overviewSnap = snap;
    state.overviewCols = snap && snap.cols ? snap.cols : null;
    drawOverview();
  } catch (_) {
    if (token !== overviewToken) return;
    drawOverview();
  }
}

async function refreshSessions() {
  const listed = await api({ cmd: "list_sessions" });
  state.sessions = listed.sessions;
  if (!state.active) state.active = listed.active;
  renderTabs();
}

async function selectSession(id) {
  await api({ cmd: "select_session", id });
  state.active = id;
  state.channelsAllDisabled = false;
  state.gutterSig = "";
  const status = await api({ cmd: "status", session: id });
  applyStatus(status, false);
  await refreshSessions();
  await refreshDecoders();
  await loadAnnotations();
  if (state.tab === "cursors" || state.tab === "measure") selectTab(state.tab);
}

document.getElementById("close-capture-no").addEventListener("click", () => document.getElementById("close-capture-dialog").close());
document.getElementById("close-capture-dialog").addEventListener("close", () => { pendingCloseSession = null; });
document.getElementById("close-capture-yes").addEventListener("click", async () => {
  const id = pendingCloseSession;
  document.getElementById("close-capture-dialog").close();
  if (!id) return;
  try {
    const result = await api({ cmd: "close_session", id });
    delete views[id];
    await selectSession(result.active);
  } catch (err) {
    statusEl.textContent = err.message;
  }
});

async function addSession() {
  const created = await api({ cmd: "create_session" });
  await selectSession(created.id);
}

async function runCapture() {
  if (commandBusy || isLive(state.phase)) return;
  if (state.channelsAllDisabled) {
    statusEl.textContent = "Enable at least one channel before capture.";
    return;
  }
  commandBusy = true;
  state.error = null;
  paintStatus();
  try {
    view().userNavigated = true;
    state.captureStarted = performance.now();
    state.planned = samplesForDuration(settings.durationNs, settings.rate);
    const status = await api({
      cmd: "configure",
      session: state.active,
      sample_rate_hz: settings.rate,
      duration_ms: Math.round(settings.durationNs / 1e6),
      duration_ns: settings.durationNs,
      realtime: true,
      trigger_enabled: settings.trigger,
      trigger_percent: settings.percent,
      depth: settings.depth,
      run: settings.run,
      repeat_interval_ms: settings.repeatMs,
      rle: settings.rle,
      threshold_volts: settings.threshold,
      one_sample_filter: settings.filter,
      external_clock: settings.extClock,
      clock_falling: settings.clockFalling,
      discard_on_stop: settings.discard,
      trigger_kind: settings.triggerKind,
      trigger_channel: settings.triggerChannel,
      trigger_steps: settings.triggerSteps,
      channel_enable: settings.channelEnable,
    });
    applyStatus(status, false);
    const started = await api({ cmd: "start", session: state.active, instant: false });
    applyStatus(started, true);
  } catch (err) {
    state.error = err.message;
  } finally {
    commandBusy = false;
    paintStatus();
    await refreshSessions();
  }
}

async function stopCapture() {
  if (commandBusy || !isLive(state.phase)) return;
  commandBusy = true;
  paintStatus();
  try {
    const status = await api({ cmd: "stop", session: state.active });
    applyStatus(status, false);
  } catch (err) {
    statusEl.textContent = err.message;
  } finally {
    commandBusy = false;
    paintStatus();
    await refreshSessions();
  }
}

function selectTab(name) {
  state.tab = name;
  for (const button of document.querySelectorAll(".side-rail button[data-tab]")) {
    button.classList.toggle("active", button.dataset.tab === name);
  }
  sideBody.innerHTML = panelHtml(name);
  bindPanel(name);
}

function panelHtml(name) {
  if (name === "device") return devicePanel();
  if (name === "triggers") return triggerPanel();
  if (name === "decode") {
    const query = escapeHtml(state.decodeQuery || "");
    return `<div class="decode-heading"><h2>Decode</h2>
        <button class="decode-help" type="button" aria-label="Decoder panel help" title="Open the protocol list, type to filter decoders, and press plus to add the highlighted one. Select an enabled decoder to show its table; use its gear to configure channels, options, and overlay, or its trash icon to remove it. The arrow beside each decoded bus folds or shows its waveform channels, and the eye hides a row. A channel used by multiple decoders appears in each group.">?</button>
      </div>
      <label class="decode-protocol-label" for="decoder-kind">Protocol</label>
      <div class="decode-add-row">
        <div class="decoder-picker" id="decoder-kind-picker">
          <button type="button" id="decoder-kind" class="decoder-kind" aria-haspopup="listbox" aria-expanded="false" aria-controls="decoder-kind-list">
            <span id="decoder-kind-label"></span>
          </button>
          <div id="decoder-kind-menu" class="decoder-kind-menu hidden">
            <input id="decoder-kind-search" type="search" placeholder="Search decoders" aria-label="Search decoders" aria-controls="decoder-kind-list" aria-autocomplete="list" autocomplete="off" spellcheck="false">
            <ul id="decoder-kind-list" role="listbox"></ul>
          </div>
        </div>
        <button id="add-decoder" class="decode-add" type="button" title="Add decoder" aria-label="Add decoder"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14"></path></svg></button>
      </div>
      <div class="decode-list-label">Enabled decoders</div>
      <ul id="decoder-list" class="decoder-list" aria-label="Enabled decoders"></ul>
      <label class="field">Search
        <input id="decode-search" type="search" placeholder="MOSI, 0xA5, or address" value="${query}" aria-label="Search decoded rows">
      </label>
      <div id="decode-table" class="decode-scroll"></div>`;
  }
  if (name === "cursors") {
    return `<h2>Cursors</h2>
      <h3>Markers</h3>
      <div id="marker-list"></div>
      <p class="hint">The cursor tool places one cursor, or a pair if Pair is selected. Drag a cursor to move it. The waveform keeps the M1, M2, … labels. Names stay in this list.</p>
      <h3>Cursor pair</h3>
      <button class="block" id="cur-a" type="button">Cursor A at hover</button>
      <button class="block" id="cur-b" type="button">Cursor B at hover</button>
      <p id="cursor-readout">Cursors are not set.</p>
      <label class="field">Pattern (0, 1, x)
        <input id="set-pattern" type="text" value="${settings.pattern}">
      </label>
      <button class="block" id="pat-next" type="button">Next match</button>
      <button class="block" id="pat-prev" type="button">Previous match</button>`;
  }
  if (name === "export") {
    return `<h2>Export</h2><div class="export-form">${exportFormHtml("panel")}</div>`;
  }
  return `<h2>Measure</h2>
    <p id="measure-readout">${state.hoverText || "Hover a logic trace, or drag a measurement on the waveform."}</p>
    <button class="block" id="keep-measure" type="button">Keep hovered pulse</button>
    <h3>Drag measurements</h3>
    <div id="span-list"></div>
    <h3>Saved pulses</h3>
    <div id="saved-measures"></div>`;
}

function streamCeiling(bands) {
  if (!bands || !bands.length) return 0;
  let max = 0;
  for (const band of bands) max = Math.max(max, band.max_hz || 0);
  return max;
}

function podLinkReduced(device) {
  if (!device || device.kind !== "usb" || device.super_speed) return false;
  const pid = Number.parseInt(String(device.id).split(":").pop(), 16);
  const profile = (state.profiles || []).find((item) => item.product_id === pid);
  if (profile) return streamCeiling(profile.super_stream_rates) > streamCeiling(profile.stream_rates);
  return pid === 0x002c;
}

function reducedLinkTitle() {
  const pods = (state.devices || []).filter(podLinkReduced);
  if (!pods.length) return "";
  const names = pods.map((device) => device.name).join(", ");
  if (pods.length === 1) return `${names} is connected at USB 2. This pod supports USB 3.`;
  return `${names} are connected at USB 2. These pods support USB 3.`;
}

function podArt(device) {
  const label = `${device && device.id || ""} ${device && device.name || ""}`.toLowerCase();
  if (/\b(scope|dso|oscilloscope)\b/.test(label)) return "/assets/scopeDevice.png";
  return "/assets/logicDevice.png";
}

function podIconHtml(devices) {
  const list = (Array.isArray(devices) ? devices : []).slice(0, 3);
  const shown = list.length ? list : [null];
  const n = shown.length;
  const imgs = shown.map((device, index) => {
    const stack = n - 1 - index;
    const src = podArt(device);
    const fallback = src === "/assets/logicDevice.png"
      ? ""
      : ` onerror="this.onerror=null;this.src='/assets/logicDevice.png'"`;
    return `<img class="pod" src="${src}" alt="" style="--stack:${stack}"${fallback}>`;
  });
  return `<span class="pod-stack" data-count="${n}">${imgs.join("")}</span>`;
}

function connectedMarkup() {
  const title = reducedLinkTitle();
  const titleAttr = title ? ` title="${escapeHtml(title)}"` : "";
  const klass = title ? "connected reduced" : "connected";
  return `<span class="${klass}"${titleAttr}><i class="dot"></i> Connected</span>`;
}

function paintPodIcons() {
  const html = podIconHtml(state.devices || []);
  for (const host of [document.querySelector(".device-chip"), document.getElementById("device-card")]) {
    if (!host) continue;
    const stack = host.querySelector(".pod-stack");
    if (stack) stack.outerHTML = html;
    else host.insertAdjacentHTML("afterbegin", html);
  }
}

function paintConnected() {
  const title = reducedLinkTitle();
  for (const el of document.querySelectorAll(".device-chip .connected, .device-card .connected")) {
    el.classList.toggle("reduced", !!title);
    if (title) el.title = title;
    else el.removeAttribute("title");
  }
}

function devicePanel() {
  const devices = state.devices || [];
  const title = devices.map((device) => device.name).join(" + ") || settings.deviceName || "Demo";
  const hardware = devices.some((device) => device.kind === "usb");
  const logic = state.channels.map((channel) => channel.name).join(", ") || "—";
  const analog = state.analog.length
    ? state.analog.map((channel) => channel.name).join(", ")
    : "none";
  const analogRow = state.analog.length
    ? `<div class="acq-row"><span>Analog channels</span><span class="value">${state.analog.length} · ${analog}</span></div>`
    : "";
  return `<h2>Device Settings</h2>
    <button type="button" class="device-card" id="device-card">
      ${podIconHtml(devices)}
      <div>
        <strong>${title}</strong>
        ${connectedMarkup()}
        <p class="hint">${hardware ? "DreamSourceLab" : "Software demo"}</p>
      </div>
    </button>
    <p id="plugged-in" class="hint">Looking for a DreamSourceLab pod.</p>

    <h3>Acquisition</h3>
    <label class="acq-row">Sample rate
      <select id="set-rate" aria-label="Sample rate">${rateOptionsHtml()}</select>
    </label>
    <p id="rate-note" class="hint">${rateNote()}</p>
    <label class="acq-row">Length
      <input id="set-duration" list="duration-presets" type="text" aria-label="Capture length" spellcheck="false" autocomplete="off">
    </label>
    <datalist id="duration-presets"></datalist>
    <p id="duration-note" class="hint"></p>
    <label class="acq-row">Buffer
      <select id="set-depth" aria-label="Buffer mode">
        <option value="buffer">Buffer</option>
        <option value="stream">Stream</option>
      </select>
    </label>
    <div class="acq-row"><span>Digital channels</span><span class="value">${state.channels.length} · ${logic}</span></div>
    <h3>Sample</h3>
    <div id="channel-enable">${channelChecks(state.probes.length ? state.probes : state.channels)}</div>
    <p class="hint">Each button is a channel number. A dim number is left out of the next capture and hidden on the waveform.</p>
    ${analogRow}
    <label class="acq-row">Input voltage
      <select id="set-threshold" aria-label="Input voltage">
        <option value="0.8">0.8 V</option>
        <option value="1.2">1.2 V</option>
        <option value="1.6">1.6 V</option>
        <option value="2.5">2.5 V</option>
        <option value="3.3">3.3 V</option>
        <option value="5">5.0 V</option>
      </select>
    </label>
    <details class="advanced">
      <summary>Advanced</summary>
      <label class="acq-row">Run
        <select id="set-run" aria-label="Run mode">
          <option value="single">Single</option>
          <option value="repeat">Repeat</option>
          <option value="loop">Loop</option>
        </select>
      </label>
      <label class="acq-row">Repeat interval
        <span class="unit-field">
          <input id="set-repeat" type="number" min="0" step="100" aria-label="Repeat interval in milliseconds">
          <span>ms</span>
        </span>
      </label>
      <label class="check"><input id="set-rle" type="checkbox"> RLE</label>
      <label class="check"><input id="set-filter" type="checkbox"> One-sample filter</label>
      <label class="check"><input id="set-ext" type="checkbox"> External clock</label>
      <label class="check"><input id="set-fall" type="checkbox"> Clock falling edge</label>
      <label class="check"><input id="set-discard" type="checkbox"> Discard on stop</label>
    </details>`;
}

const TRIGGER_KINDS = [
  { id: "rising", label: "Rising edge", path: "M4 16h7V8h9" },
  { id: "falling", label: "Falling edge", path: "M4 8h7v8h9" },
  { id: "any", label: "Any edge", path: "M3 16h5V8h8v8h5" },
  { id: "high", label: "High level", path: "M4 8h16" },
  { id: "low", label: "Low level", path: "M4 16h16" },
];
const PRE_TRIGGER_CHOICES = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90];

function triggerKindIndex() {
  const index = TRIGGER_KINDS.findIndex((kind) => kind.id === settings.triggerKind);
  return index < 0 ? 0 : index;
}

function activeTriggerChannels() {
  const probes = state.probes.length ? state.probes : state.channels;
  if (!probes.length) return [{ index: settings.triggerChannel || 0, label: "0" }];
  const enabled = probes.filter((probe) => channelIsEnabled(probe.index));
  const labels = enabled.map((probe) => probe.name || String(probe.index));
  const shared = labels.some((label, index) => labels.indexOf(label) !== index);
  return enabled.map((probe) => ({
    index: probe.index,
    label: shared
      ? `${deviceTag(probe.device_name)} ${probe.name || probe.index}`
      : (probe.name || String(probe.index)),
  }));
}

function syncTriggerChannelSelect(select) {
  if (!select) return;
  const choices = activeTriggerChannels();
  const sig = choices.map((choice) => `${choice.index}:${choice.label}`).join("|");
  if (select.dataset.sig !== sig) {
    select.dataset.sig = sig;
    select.replaceChildren();
    for (const choice of choices) {
      const option = document.createElement("option");
      option.value = String(choice.index);
      option.textContent = choice.label;
      select.appendChild(option);
    }
  }
  if (!choices.length) return;
  if (!choices.some((choice) => choice.index === settings.triggerChannel)) {
    settings.triggerChannel = choices[0].index;
  }
  if (select.value !== String(settings.triggerChannel)) select.value = String(settings.triggerChannel);
}

function syncPreTriggerSelect() {
  const select = document.getElementById("trig-pre");
  if (!select) return;
  const value = Math.max(0, Math.min(90, Math.round(Number(settings.percent) || 0)));
  settings.percent = value;
  const values = PRE_TRIGGER_CHOICES.includes(value)
    ? PRE_TRIGGER_CHOICES
    : [...PRE_TRIGGER_CHOICES, value].sort((a, b) => a - b);
  const sig = values.join(",");
  if (select.dataset.sig !== sig) {
    select.dataset.sig = sig;
    select.replaceChildren();
    for (const item of values) {
      const option = document.createElement("option");
      option.value = String(item);
      option.textContent = `${item}%`;
      select.appendChild(option);
    }
  }
  if (select.value !== String(value)) select.value = String(value);
}

function paintTriggerKind() {
  const kind = TRIGGER_KINDS[triggerKindIndex()];
  const button = document.getElementById("trig-kind");
  const path = document.getElementById("trig-kind-path");
  const label = document.getElementById("trig-kind-label");
  if (!button || !path || !label) return;
  path.setAttribute("d", kind.path);
  label.textContent = kind.label;
  button.title = kind.label;
  button.setAttribute("aria-label", `Trigger type, ${kind.label}`);
}

function paintTriggerArm() {
  const button = document.getElementById("trig-arm");
  if (!button) return;
  button.setAttribute("aria-pressed", settings.trigger ? "true" : "false");
  button.title = settings.trigger ? "Trigger on" : "Trigger off";
  button.setAttribute("aria-label", settings.trigger ? "Disable trigger" : "Enable trigger");
}

function syncTriggerToolbar() {
  paintTriggerArm();
  paintTriggerKind();
  syncTriggerChannelSelect(document.getElementById("trig-channel"));
  syncPreTriggerSelect();
  const panel = document.getElementById("panel-trig-channel");
  if (panel && document.activeElement !== panel) syncTriggerChannelSelect(panel);
  const edge = document.getElementById("panel-trig-edge");
  if (edge && document.activeElement !== edge && edge.value !== settings.triggerKind) edge.value = settings.triggerKind;
  const position = document.getElementById("set-position");
  const positionLabel = document.getElementById("set-position-label");
  if (position && document.activeElement !== position) {
    position.value = String(settings.percent);
    if (positionLabel) positionLabel.textContent = `${settings.percent}%`;
  }
}

function triggerPanel() {
  const steps = settings.triggerSteps
    .map((step, index) => `<div class="step">
        <input type="number" min="0" max="31" value="${step.channel}" data-step="${index}" data-field="channel" aria-label="Step ${index + 1} channel">
        <select data-step="${index}" data-field="edge" aria-label="Step ${index + 1} edge">
          <option value="rising"${step.rising ? " selected" : ""}>Rising</option>
          <option value="falling"${step.rising ? "" : " selected"}>Falling</option>
        </select>
        <button type="button" data-remove="${index}">Remove</button>
      </div>`)
    .join("");
  const source = activeTriggerChannels().map((choice) => `<option value="${choice.index}">${escapeHtml(choice.label)}</option>`).join("");
  return `<h2>Triggers</h2>
    <label class="check"><input id="trig-enable" type="checkbox"> Enable trigger</label>
    <label class="acq-row">Source
      <select id="panel-trig-channel" aria-label="Trigger source">${source}</select>
    </label>
    <label class="acq-row">Type
      <select id="panel-trig-edge" aria-label="Trigger type">
        <option value="rising">Rising edge</option>
        <option value="falling">Falling edge</option>
        <option value="any">Any edge</option>
        <option value="high">High level</option>
        <option value="low">Low level</option>
      </select>
    </label>
    <label class="acq-row">Position
      <span>
        <input id="set-position" type="range" min="0" max="90" step="1" aria-label="Pre-trigger position">
        <span id="set-position-label"></span>
      </span>
    </label>
    <details class="advanced"><summary>Advanced trigger</summary>
      <h3>Trigger sequence</h3>
      <p class="hint">A sequence replaces the single trigger. Steps run in order and the mark is the last one. Each step is one arm-record stage, up to 16.</p>
      <div id="trigger-steps">${steps}</div>
      <button class="block" id="add-step" type="button"${settings.triggerSteps.length >= 16 ? " disabled" : ""}>Add edge step</button>
    </details>`;
}

function channelPages(probes) {
  const pages = [];
  let index = 0;
  while (index < probes.length) {
    const device = probes[index].device_id || "";
    const page = [];
    while (index < probes.length && page.length < 8 && (probes[index].device_id || "") === device) {
      page.push(probes[index]);
      index += 1;
    }
    pages.push(page);
  }
  return pages;
}

function localProbeIndex(probes, probe) {
  const first = probes.find((item) => (item.device_id || "") === (probe.device_id || ""));
  return probe.index - (first ? first.index : 0);
}

function deviceTag(name) {
  const text = String(name || "").replace(/^DSLogic\s+/, "");
  if (/^U3/i.test(text)) return "U3";
  return text || "Pod";
}

function channelChecks(probes) {
  const pages = channelPages(probes);
  if (!pages.length) return "";
  if (state.channelGroup >= pages.length) state.channelGroup = 0;
  const several = new Set(probes.map((probe) => probe.device_id || "")).size > 1;
  const tabs = pages.map((page, index) => {
    const from = localProbeIndex(probes, page[0]);
    const to = localProbeIndex(probes, page[page.length - 1]);
    const prefix = several ? deviceTag(page[0].device_name) + " " : "";
    return `<button type="button" class="ch-tab${index === state.channelGroup ? " active" : ""}" data-group="${index}">${prefix}${from}–${to}</button>`;
  }).join("");
  const buttons = pages[state.channelGroup].map((probe) => {
    const on = channelIsEnabled(probe.index);
    const local = localProbeIndex(probes, probe);
    const color = storedColor("logic:" + probe.index, probe.color || "#8eb6ff");
    return `<button type="button" class="ch-en${on ? " on" : ""}" data-bit="${probe.index}" style="--ch:${color}" aria-label="Channel ${local}" title="${escapeHtml(probe.name || "")}">${local}</button>`;
  }).join("");
  const allOn = probes.every((probe) => channelIsEnabled(probe.index));
  const groupOn = pages[state.channelGroup].every((probe) => channelIsEnabled(probe.index));
  return `<div class="ch-tabs">${tabs}<button type="button" class="ch-all" data-scope="device" aria-pressed="${allOn}" title="Toggle all channels">All</button></div><div class="ch-enable-row"><div class="ch-enables">${buttons}</div><button type="button" class="ch-all" data-scope="group" aria-pressed="${groupOn}" title="Toggle this group">All</button></div>`;
}

function bindPanel(name) {
  if (name === "device") {
    loadDeviceChoices();
    bindSelect("set-rate", "rate", true);
    const rate = document.getElementById("set-rate");
    if (rate) rate.addEventListener("change", () => refillDurationField());
    bindDurationField();
    bindSelect("set-depth", "depth", false);
    const depth = document.getElementById("set-depth");
    if (depth) {
      depth.addEventListener("change", () => {
        clampSampleRate();
        refillRateSelect();
        paintRunIcon();
      });
    }
    bindSelect("set-run", "run", false);
    const runMode = document.getElementById("set-run");
    if (runMode) runMode.addEventListener("change", () => paintRunIcon());
    const repeat = document.getElementById("set-repeat");
    const threshold = document.getElementById("set-threshold");
    repeat.value = String(settings.repeatMs);
    if (![...threshold.options].some((option) => option.value === String(settings.threshold))) {
      const extra = document.createElement("option");
      extra.value = String(settings.threshold);
      extra.textContent = settings.threshold + " V";
      threshold.append(extra);
    }
    threshold.value = String(settings.threshold);
    repeat.addEventListener("change", () => { settings.repeatMs = Number(repeat.value); });
    threshold.addEventListener("change", () => { settings.threshold = Number(threshold.value); });
    const card = document.getElementById("device-card");
    if (card) card.addEventListener("click", () => openDeviceMenu(card));
    for (const tab of document.querySelectorAll("#channel-enable .ch-tab")) {
      tab.addEventListener("click", () => {
        state.channelGroup = Number(tab.dataset.group);
        selectTab("device");
      });
    }
    const probes = state.probes.length ? state.probes : state.channels;
    const setEnabled = (indices, enabled) => {
      const selected = new Set(probes.filter((probe) => channelIsEnabled(probe.index)).map((probe) => probe.index));
      for (const index of indices) {
        if (enabled) selected.add(index);
        else selected.delete(index);
      }
      state.channelsAllDisabled = selected.size === 0;
      let mask = 0n;
      for (const index of selected) mask |= maskBit(index);
      settings.channelEnable = selected.size === probes.length || selected.size === 0 ? 0 : Number(mask);
      clampSampleRate();
      state.gutterSig = "";
      renderGutter();
      scheduleTiles();
      drawWave();
      syncTriggerToolbar();
      selectTab("device");
    };
    for (const button of document.querySelectorAll("#channel-enable .ch-en")) {
      button.addEventListener("click", () => {
        const bit = Number(button.dataset.bit);
        setEnabled([bit], !channelIsEnabled(bit));
      });
    }
    for (const button of document.querySelectorAll("#channel-enable .ch-all")) {
      button.addEventListener("click", () => {
        const pages = channelPages(probes);
        const selected = button.dataset.scope === "device" ? probes : (pages[state.channelGroup] || []);
        setEnabled(selected.map((probe) => probe.index), !selected.every((probe) => channelIsEnabled(probe.index)));
      });
    }
    bindCheck("set-rle", "rle");
    bindCheck("set-filter", "filter");
    bindCheck("set-ext", "extClock");
    bindCheck("set-fall", "clockFalling");
    bindCheck("set-discard", "discard");
  }
  if (name === "triggers") {
    const enable = document.getElementById("trig-enable");
    enable.checked = settings.trigger;
    enable.addEventListener("change", () => {
      settings.trigger = enable.checked;
      paintTriggerArm();
    });
    const source = document.getElementById("panel-trig-channel");
    const edge = document.getElementById("panel-trig-edge");
    const position = document.getElementById("set-position");
    const positionLabel = document.getElementById("set-position-label");
    source.value = String(settings.triggerChannel);
    if (source.options.length && !source.value) {
      source.selectedIndex = 0;
      settings.triggerChannel = Number(source.value || 0);
    }
    edge.value = settings.triggerKind;
    position.value = String(settings.percent);
    positionLabel.textContent = settings.percent + "%";
    source.addEventListener("change", () => {
      settings.triggerChannel = Number(source.value);
      syncTriggerChannelSelect(document.getElementById("trig-channel"));
    });
    edge.addEventListener("change", () => {
      settings.triggerKind = edge.value;
      paintTriggerKind();
    });
    position.addEventListener("input", () => {
      settings.percent = Number(position.value);
      positionLabel.textContent = settings.percent + "%";
      syncPreTriggerSelect();
    });
    document.getElementById("add-step").addEventListener("click", () => {
      const next = settings.triggerSteps.length === 0 ? 1 : settings.triggerSteps.length === 1 ? 3 : 0;
      settings.triggerSteps.push({ channel: next, rising: true });
      settings.trigger = true;
      const box = document.getElementById("trig-enable");
      if (box) box.checked = true;
      paintTriggerArm();
      selectTab("triggers");
    });
    for (const input of document.querySelectorAll("#trigger-steps [data-field='channel']")) {
      input.addEventListener("change", () => {
        const index = Number(input.dataset.step);
        const channel = Math.max(0, Math.min(31, Number(input.value) || 0));
        settings.triggerSteps[index].channel = channel;
        input.value = String(channel);
      });
    }
    for (const select of document.querySelectorAll("#trigger-steps [data-field='edge']")) {
      select.addEventListener("change", () => {
        const index = Number(select.dataset.step);
        settings.triggerSteps[index].rising = select.value !== "falling";
      });
    }
    for (const button of document.querySelectorAll("#trigger-steps [data-remove]")) {
      button.addEventListener("click", () => {
        settings.triggerSteps.splice(Number(button.dataset.remove), 1);
        selectTab("triggers");
      });
    }
  }
  if (name === "decode") {
    bindDecoderPicker();
    document.getElementById("add-decoder").addEventListener("click", () => addDecoder());
    const search = document.getElementById("decode-search");
    search.addEventListener("input", () => {
      state.decodeQuery = search.value;
      renderDecodeTable();
    });
    refreshDecoders().then(() => loadAnnotations());
  }
  if (name === "cursors") {
    document.getElementById("cur-a").addEventListener("click", () => dropCursor(0));
    document.getElementById("cur-b").addEventListener("click", () => dropCursor(1));
    document.getElementById("pat-next").addEventListener("click", () => searchPattern(true));
    document.getElementById("pat-prev").addEventListener("click", () => searchPattern(false));
    renderMarkerList();
  }
  if (name === "measure") {
    document.getElementById("keep-measure").addEventListener("click", keepMeasurement);
    refreshMeasurements();
    renderMeasureList();
  }
  if (name === "export") bindExportForm("panel");
}

function renderMarkerList() {
  const host = document.getElementById("marker-list");
  if (!host) return;
  host.replaceChildren();
  const markers = view().markers;
  if (!markers.length) {
    const empty = document.createElement("p");
    empty.className = "hint";
    empty.textContent = "No markers yet.";
    host.appendChild(empty);
    return;
  }
  markers.forEach((marker, index) => {
    const row = document.createElement("div");
    row.className = "marker-row";
    const dot = document.createElement("span");
    dot.className = "swatch-dot";
    dot.style.background = MARKER_COLORS[index % MARKER_COLORS.length];
    const label = document.createElement("span");
    const seconds = sampleSeconds(marker.sample);
    label.textContent = `M${marker.n} · ${formatSeconds(seconds)} · sample ${marker.sample}`;
    const nameInput = document.createElement("input");
    nameInput.type = "text";
    nameInput.value = marker.name || "";
    nameInput.placeholder = "Name";
    nameInput.setAttribute("aria-label", `Name for M${marker.n}`);
    nameInput.addEventListener("input", () => { marker.name = nameInput.value; });
    const jump = document.createElement("button");
    jump.type = "button";
    jump.textContent = "Show";
    jump.addEventListener("click", () => centerOn(marker.sample));
    const remove = document.createElement("button");
    remove.type = "button";
    remove.textContent = "Delete";
    remove.addEventListener("click", () => {
      view().markers = view().markers.filter((item) => item.id !== marker.id);
      renderMarkerList();
      drawWave();
      drawRuler();
    });
    row.append(dot, label, nameInput, jump, remove);
    host.appendChild(row);
  });
}

function renderMeasureList() {
  const host = document.getElementById("span-list");
  if (!host) return;
  host.replaceChildren();
  const spans = view().measures;
  if (!spans.length) {
    const empty = document.createElement("p");
    empty.className = "hint";
    empty.textContent = "No drag measurements yet.";
    host.appendChild(empty);
    return;
  }
  for (const span of spans) {
    const row = document.createElement("div");
    row.className = "measure-row";
    const seconds = Math.abs(span.b - span.a) / Math.max(1, state.rate);
    const label = document.createElement("span");
    label.textContent = `#${span.n} ch${span.channel} · ${formatSeconds(seconds)} · ${span.a} → ${span.b}`;
    const remove = document.createElement("button");
    remove.type = "button";
    remove.textContent = "Delete";
    remove.addEventListener("click", () => {
      view().measures = view().measures.filter((item) => item.id !== span.id);
      renderMeasureList();
      drawWave();
    });
    row.append(label, remove);
    host.appendChild(row);
  }
}

function bindSelect(id, key, numeric) {
  const el = document.getElementById(id);
  if (!el) return;
  el.value = String(settings[key]);
  el.addEventListener("change", () => {
    settings[key] = numeric ? Number(el.value) : el.value;
  });
}

const HOST_MAX_SAMPLES = 16_000_000;

const RATE_LADDER = [
  10_000, 20_000, 50_000, 100_000, 200_000, 500_000,
  1_000_000, 2_000_000, 5_000_000, 10_000_000, 20_000_000, 25_000_000,
  50_000_000, 100_000_000, 200_000_000, 250_000_000, 400_000_000,
  500_000_000, 1_000_000_000,
];

const PLUS_BUFFER_RATES = [
  { max_channels: 4, max_hz: 400_000_000 },
  { max_channels: 8, max_hz: 200_000_000 },
  { max_channels: 16, max_hz: 100_000_000 },
];
const PLUS_STREAM_RATES = [
  { max_channels: 3, max_hz: 100_000_000 },
  { max_channels: 6, max_hz: 50_000_000 },
  { max_channels: 12, max_hz: 25_000_000 },
  { max_channels: 16, max_hz: 20_000_000 },
];

function activeProductId() {
  const usb = (state.devices || []).find((device) => String(device.id).startsWith("usb:"));
  if (!usb) return 0x0020;
  const pid = Number.parseInt(String(usb.id).split(":").pop(), 16);
  return Number.isFinite(pid) ? pid : 0x0020;
}

function activeRateBands() {
  const pid = activeProductId();
  const profile = (state.profiles || []).find((item) => item.product_id === pid)
    || (state.profiles || []).find((item) => item.product_id === 0x0020);
  const stream = settings.depth === "stream";
  if (profile) {
    const usb = (state.devices || []).find((device) => String(device.id).startsWith("usb:"));
    const bands = stream
      ? (usb && usb.super_speed && profile.super_stream_rates && profile.super_stream_rates.length
        ? profile.super_stream_rates
        : profile.stream_rates)
      : profile.buffer_rates;
    if (bands && bands.length) return bands;
  }
  return stream ? PLUS_STREAM_RATES : PLUS_BUFFER_RATES;
}

function enabledChannelCount() {
  const probes = state.probes.length ? state.probes : state.channels;
  const width = Math.max(1, probes.length || 1);
  if (!settings.channelEnable) return width;
  let count = 0;
  for (const probe of probes) {
    if (channelIsEnabled(probe.index)) count += 1;
  }
  return Math.max(1, count);
}

function maxSampleHz(bands, channels) {
  const band = bands.find((item) => channels <= item.max_channels) || bands[bands.length - 1];
  return band ? band.max_hz : 100_000_000;
}

function sessionRateMax() {
  const devices = (state.devices || []).filter((device) => String(device.id).startsWith("usb:"));
  const stream = settings.depth === "stream";
  if (devices.length < 2) return maxSampleHz(activeRateBands(), enabledChannelCount());
  let offset = 0;
  let ceiling = Infinity;
  for (const device of devices) {
    const pid = Number.parseInt(String(device.id).split(":").pop(), 16);
    const profile = (state.profiles || []).find((item) => item.product_id === pid);
    const width = profile ? profile.channels : (pid === 0x002c ? 32 : 16);
    let count = 0;
    for (let index = 0; index < width; index += 1) {
      if (channelIsEnabled(offset + index)) count += 1;
    }
    offset += width;
    if (!count) continue;
    const bands = profile
      ? (stream
        ? (device.super_speed && profile.super_stream_rates && profile.super_stream_rates.length
          ? profile.super_stream_rates
          : profile.stream_rates)
        : profile.buffer_rates)
      : null;
    const max = maxSampleHz(bands && bands.length ? bands : (stream ? PLUS_STREAM_RATES : PLUS_BUFFER_RATES), count);
    if (max < ceiling) ceiling = max;
  }
  return Number.isFinite(ceiling) ? ceiling : maxSampleHz(activeRateBands(), enabledChannelCount());
}

function legalSampleRates() {
  const channels = enabledChannelCount();
  const max = sessionRateMax();
  const rates = RATE_LADDER.filter((rate) => rate <= max);
  if (max > 0 && !rates.includes(max)) rates.push(max);
  rates.sort((a, b) => a - b);
  return { channels, max, rates };
}

function clampSampleRate() {
  const choice = legalSampleRates();
  if (!choice.rates.length) return choice;
  if (!choice.rates.includes(settings.rate) || settings.rate > choice.max) {
    const under = choice.rates.filter((rate) => rate <= Math.min(settings.rate, choice.max));
    settings.rate = under.length ? under[under.length - 1] : choice.rates[choice.rates.length - 1];
  }
  return choice;
}

function formatSampleRate(hz) {
  const text = (value, unit) => {
    const rounded = Math.round(value * 1000) / 1000;
    return (Number.isInteger(rounded) ? String(rounded) : String(rounded)) + " " + unit;
  };
  if (hz >= 1e9) return text(hz / 1e9, "GS/s");
  if (hz >= 1e9) return (hz / 1e9).toFixed(3) + " GHz";
  if (hz >= 1e6) return text(hz / 1e6, "MS/s");
  if (hz >= 1e3) return text(hz / 1e3, "kS/s");
  return hz + " S/s";
}

function rateProfileLabel() {
  const pid = activeProductId();
  const profile = (state.profiles || []).find((item) => item.product_id === pid);
  if (profile) return profile.name.replace(/^DSLogic /, "");
  return pid === 0x002c ? "U3Pro32" : "Plus";
}

function rateNote() {
  const choice = legalSampleRates();
  const mode = settings.depth === "stream" ? "stream" : "buffer";
  const noun = choice.channels === 1 ? "channel" : "channels";
  const usb = (state.devices || []).filter((device) => String(device.id).startsWith("usb:"));
  if (usb.length > 1) {
    return `${choice.channels} ${noun} enabled. Combined ${mode} tops out at ${formatSampleRate(choice.max)}.`;
  }
  return `${choice.channels} ${noun} enabled. ${rateProfileLabel()} ${mode} tops out at ${formatSampleRate(choice.max)}.`;
}

function rateOptionsHtml() {
  clampSampleRate();
  return legalSampleRates().rates.map((rate) => `<option value="${rate}">${formatSampleRate(rate)}</option>`).join("");
}

function refillRateSelect() {
  const select = document.getElementById("set-rate");
  const note = document.getElementById("rate-note");
  const choice = clampSampleRate();
  if (select) {
    select.innerHTML = choice.rates.map((rate) => `<option value="${rate}">${formatSampleRate(rate)}</option>`).join("");
    select.value = String(settings.rate);
  }
  if (note) note.textContent = rateNote();
  refillDurationField();
}

function profileMemoryBits(profile) {
  return profile && profile.memory_bits ? profile.memory_bits : 256 * 1024 * 1024;
}

function memoryBits() {
  const pid = activeProductId();
  const profile = (state.profiles || []).find((item) => item.product_id === pid)
    || (state.profiles || []).find((item) => item.product_id === 0x0020);
  return profileMemoryBits(profile);
}

function sessionSampleCeiling() {
  if (settings.depth === "stream") return HOST_MAX_SAMPLES;
  const devices = (state.devices || []).filter((device) => String(device.id).startsWith("usb:"));
  if (devices.length < 1) return HOST_MAX_SAMPLES;
  if (devices.length < 2) return Math.floor(memoryBits() / enabledChannelCount());
  let offset = 0;
  let ceiling = Infinity;
  for (const device of devices) {
    const pid = Number.parseInt(String(device.id).split(":").pop(), 16);
    const profile = (state.profiles || []).find((item) => item.product_id === pid);
    const width = profile ? profile.channels : (pid === 0x002c ? 32 : 16);
    let count = 0;
    for (let index = 0; index < width; index += 1) {
      if (channelIsEnabled(offset + index)) count += 1;
    }
    offset += width;
    if (!count) continue;
    const share = Math.floor(profileMemoryBits(profile) / count);
    if (share < ceiling) ceiling = share;
  }
  return Number.isFinite(ceiling) ? ceiling : HOST_MAX_SAMPLES;
}

function durationLimits() {
  const rate = Math.max(1, settings.rate);
  const ceiling = sessionSampleCeiling();
  const aligned = ceiling - (ceiling % 64);
  const minNs = Number((64n * 1_000_000_000n + BigInt(rate) - 1n) / BigInt(rate));
  const maxNs = Number((BigInt(Math.max(aligned, 64)) * 1_000_000_000n) / BigInt(rate));
  return { minNs, maxNs: Math.max(minNs, maxNs), ceiling: Math.max(aligned, 64), rate };
}

function samplesForDuration(ns, rate) {
  const total = Number((BigInt(Math.max(0, rate)) * BigInt(Math.max(0, ns))) / 1_000_000_000n);
  return total - (total % 64);
}

function parseDurationNs(text) {
  const match = String(text).trim().match(/^(\d+(?:\.\d+)?)\s*(ns|us|µs|μs|ms|s)?$/i);
  if (!match) return null;
  const value = Number(match[1]);
  if (!Number.isFinite(value) || value < 0) return null;
  const unit = (match[2] || "ms").toLowerCase();
  const scale = unit === "s" ? 1e9 : unit === "ms" ? 1e6 : (unit === "us" || unit === "µs" || unit === "μs") ? 1e3 : 1;
  const ns = Math.round(value * scale);
  if (!Number.isSafeInteger(ns)) return null;
  return ns;
}

function formatDuration(ns) {
  const units = [[1e9, "s"], [1e6, "ms"], [1e3, "us"], [1, "ns"]];
  for (const [scale, unit] of units) {
    if (ns + 0.5 < scale) continue;
    const rounded = Math.round((ns / scale) * 1000) / 1000;
    if (rounded < 1 && unit !== "ns") continue;
    const text = Number.isInteger(rounded) ? String(rounded) : String(rounded);
    return text + " " + unit;
  }
  return "0 ns";
}

function durationPresets(limits) {
  const picked = new Set([limits.minNs, limits.maxNs]);
  if (2_000_000_000 >= limits.minNs && 2_000_000_000 <= limits.maxNs) picked.add(2_000_000_000);
  for (let base = 1; base <= limits.maxNs; base *= 10) {
    for (const step of [1, 2, 5]) {
      const ns = step * base;
      if (ns >= limits.minNs && ns <= limits.maxNs) picked.add(ns);
    }
    if (base > limits.maxNs / 10) break;
  }
  return [...picked].sort((a, b) => a - b);
}

function durationNote(limits) {
  return `${formatDuration(limits.minNs)} to ${formatDuration(limits.maxNs)}. The capture is rounded down to a multiple of 64 samples.`;
}

function clampDuration(limits) {
  if (!(settings.durationNs > 0)) settings.durationNs = 2_000_000_000;
  if (settings.durationNs < limits.minNs) settings.durationNs = limits.minNs;
  if (settings.durationNs > limits.maxNs) settings.durationNs = limits.maxNs;
}

function refillDurationField() {
  const input = document.getElementById("set-duration");
  const list = document.getElementById("duration-presets");
  const note = document.getElementById("duration-note");
  if (!input && !list && !note) return;
  const limits = durationLimits();
  clampDuration(limits);
  if (list) {
    list.innerHTML = durationPresets(limits).map((ns) => `<option value="${formatDuration(ns)}"></option>`).join("");
  }
  if (input && document.activeElement !== input) input.value = formatDuration(settings.durationNs);
  if (note) note.textContent = durationNote(limits);
}

function commitDuration(text) {
  const ns = parseDurationNs(text);
  if (ns == null) {
    refillDurationField();
    const note = document.getElementById("duration-note");
    if (note) note.textContent = "Use a length like 250 us, 10 ms, or 2 s.";
    return;
  }
  const limits = durationLimits();
  const samples = samplesForDuration(ns, limits.rate);
  if (samples < 64) settings.durationNs = limits.minNs;
  else if (samples > limits.ceiling) settings.durationNs = limits.maxNs;
  else settings.durationNs = ns;
  refillDurationField();
}

function bindDurationField() {
  refillDurationField();
  const input = document.getElementById("set-duration");
  if (!input) return;
  const commit = () => commitDuration(input.value);
  input.addEventListener("change", commit);
  input.addEventListener("keydown", (ev) => {
    if (ev.key !== "Enter") return;
    ev.preventDefault();
    commit();
  });
}

function bindCheck(id, key) {
  const el = document.getElementById(id);
  if (!el) return;
  el.checked = !!settings[key];
  el.addEventListener("change", () => { settings[key] = el.checked; });
}

function deviceLabel(id) {
  if (id === "demo+demo:spi") return "Demo + Demo SPI";
  const found = state.deviceList.find((device) => device.id === id);
  if (found) return found.name;
  return (state.devices || []).map((device) => device.name).join(" + ") || settings.deviceName || "Demo";
}

function syncDeviceSelect() {
  const name = document.getElementById("device-name");
  const key = (state.devices || []).map((device) => device.id).join("+");
  if (name) name.textContent = deviceLabel(key);
  paintPodIcons();
  paintConnected();
}

function deviceMenuButton(id, label) {
  const button = document.createElement("button");
  button.type = "button";
  button.dataset.device = id;
  button.textContent = label;
  button.addEventListener("click", () => {
    closeDeviceMenu();
    applyDeviceChoice(id);
  });
  return button;
}

function renderDeviceMenu() {
  const menu = document.getElementById("device-menu");
  if (!menu) return;
  menu.replaceChildren();
  const pods = state.deviceList.filter((device) => device.kind !== "demo");
  const demos = state.deviceList.filter((device) => device.kind === "demo");
  for (const pod of pods) menu.append(deviceMenuButton(pod.id, pod.name));
  const plus = pods.find((pod) => pod.id === "usb:2a0e:0020");
  const u3 = pods.find((pod) => pod.id === "usb:2a0e:002c");
  if (plus && u3) menu.append(deviceMenuButton(plus.id + "+" + u3.id, "Plus + U3Pro32"));
  if (!demos.length) return;
  const row = document.createElement("div");
  row.className = "device-sub";
  const label = document.createElement("button");
  label.type = "button";
  label.textContent = "Demo";
  label.addEventListener("click", (ev) => {
    ev.stopPropagation();
    row.classList.toggle("open");
  });
  const sub = document.createElement("div");
  sub.className = "device-submenu";
  for (const demo of demos) sub.append(deviceMenuButton(demo.id, demo.name));
  if (demos.some((device) => device.id === "demo") && demos.some((device) => device.id === "demo:spi")) {
    sub.append(deviceMenuButton("demo+demo:spi", "Demo + Demo SPI"));
  }
  row.append(label, sub);
  menu.append(row);
}

function closeDeviceMenu() {
  const menu = document.getElementById("device-menu");
  if (menu) menu.classList.add("hidden");
}

function closeDeviceAcqMenu() {
  const menu = document.getElementById("device-acq-menu");
  if (menu) menu.classList.add("hidden");
}

function closeRunMenu() {
  const menu = document.getElementById("run-menu");
  if (menu) menu.classList.add("hidden");
}

function openRunMenu() {
  closeMenu();
  closeDeviceMenu();
  closeDeviceAcqMenu();
  closeBusMenu();
  closeDecoderPicker();
  const menu = document.getElementById("run-menu");
  if (!menu) return;
  menu.replaceChildren();
  for (const [id, label] of [["single", "Single"], ["repeat", "Repeat"], ["loop", "Loop"]]) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label;
    if (settings.run === id) button.setAttribute("aria-current", "true");
    button.addEventListener("click", () => {
      settings.run = id;
      const select = document.getElementById("set-run");
      if (select) select.value = id;
      paintRunIcon();
      closeRunMenu();
    });
    menu.append(button);
  }
  menu.classList.remove("hidden");
  const rect = runBtn.getBoundingClientRect();
  placeViewportMenu(menu, rect.left, rect.bottom + 6);
}

function acqChoice(label, selected, apply) {
  const button = document.createElement("button");
  button.type = "button";
  button.textContent = label;
  if (selected) button.setAttribute("aria-current", "true");
  button.addEventListener("click", (ev) => {
    ev.stopPropagation();
    apply();
    closeDeviceAcqMenu();
  });
  return button;
}

function acqSubmenu(title, value, items) {
  const row = document.createElement("div");
  row.className = "device-sub";
  const label = document.createElement("button");
  label.type = "button";
  const name = document.createElement("span");
  name.textContent = title;
  const current = document.createElement("span");
  current.className = "menu-key";
  current.textContent = value;
  label.append(name, current);
  label.addEventListener("click", (ev) => {
    ev.stopPropagation();
    row.classList.toggle("open");
  });
  const sub = document.createElement("div");
  sub.className = "device-submenu";
  for (const item of items) sub.append(item);
  row.append(label, sub);
  return row;
}

function renderDeviceAcqMenu() {
  const menu = document.getElementById("device-acq-menu");
  if (!menu) return;
  menu.replaceChildren();
  const choice = clampSampleRate();
  const rates = choice.rates.map((rate) => acqChoice(formatSampleRate(rate), rate === settings.rate, () => {
    settings.rate = rate;
    refillRateSelect();
    refillDurationField();
  }));
  const limits = durationLimits();
  clampDuration(limits);
  const lengths = durationPresets(limits).map((ns) => acqChoice(formatDuration(ns), ns === settings.durationNs, () => {
    commitDuration(formatDuration(ns));
  }));
  menu.append(
    acqSubmenu("Sample rate", formatSampleRate(settings.rate), rates),
    acqSubmenu("Length", formatDuration(settings.durationNs), lengths),
  );
}

function openDeviceAcqMenu(x, y) {
  closeDeviceMenu();
  closeRunMenu();
  const menu = document.getElementById("device-acq-menu");
  if (!menu) return;
  renderDeviceAcqMenu();
  menu.classList.remove("hidden");
  placeViewportMenu(menu, x, y);
}

function openDeviceMenu(anchor) {
  closeDeviceAcqMenu();
  closeRunMenu();
  const menu = document.getElementById("device-menu");
  if (!menu) return;
  if (!menu.classList.contains("hidden")) {
    closeDeviceMenu();
    return;
  }
  renderDeviceMenu();
  menu.classList.remove("hidden");
  const rect = anchor.getBoundingClientRect();
  placeViewportMenu(menu, rect.left, rect.bottom + 6);
}

function placeDeviceSubmenu() {
  const menu = document.getElementById("device-menu");
  const row = menu && menu.querySelector(".device-sub");
  if (!row) return;
  const rect = menu.getBoundingClientRect();
  row.classList.toggle("flip", rect.right + 196 > window.innerWidth);
}

let deviceScanInFlight = false;
let deviceSelectionReady = false;
let deviceChoiceInFlight = false;
let pendingAttachedPod = null;

async function reconcileDeviceSelection(previous, devices) {
  if (!deviceSelectionReady) return;
  const hardware = devices.filter((device) => device.kind === "usb");
  const previousHardware = previous.filter((device) => device.kind === "usb");
  if (hardware.length === 1 && previousHardware.length === 0) pendingAttachedPod = hardware[0].id;
  if (hardware.length !== 1 || !hardware.some((device) => device.id === pendingAttachedPod)) pendingAttachedPod = null;
  if (isLive(state.phase) || commandBusy || deviceChoiceInFlight) return;

  const selected = state.devices || [];
  const missing = selected.some((device) => device.kind === "usb" && !hardware.some((pod) => pod.id === device.id));
  const demoSelected = selected.length > 0 && selected.every((device) => device.kind === "demo");
  if (!missing && !(demoSelected && pendingAttachedPod)) return;

  deviceChoiceInFlight = true;
  try {
    const profiles = state.profiles.length ? state.profiles : await api({ cmd: "list_profiles" });
    if (isLive(state.phase) || commandBusy) return;
    const usable = hardware.filter((device) => profiles.some((profile) => profile.id === device.id && profile.hardware_tested));
    const choices = missing ? [...usable.map((device) => device.id), "demo"] : usable.filter((device) => device.id === pendingAttachedPod).map((device) => device.id);
    for (const id of choices) {
      try {
        await useDevice(id);
        pendingAttachedPod = null;
        return;
      } catch (err) {
        statusEl.textContent = `Could not select ${id}: ${err.message}`;
      }
    }
    if (!missing) pendingAttachedPod = null;
  } finally { deviceChoiceInFlight = false; }
}

async function refreshDeviceList() {
  if (deviceScanInFlight) return;
  deviceScanInFlight = true;
  try {
    const devices = await api({ cmd: "list_devices" });
    const previous = state.deviceList;
    const changed = JSON.stringify(devices) !== JSON.stringify(previous);
    state.deviceList = devices;
    const hardware = devices.filter((device) => device.kind !== "demo");
    const plugged = document.getElementById("plugged-in");
    if (plugged) {
      plugged.textContent = hardware.length
        ? `Detected: ${hardware.map((device) => device.name).join(", ")}.`
        : "No DreamSourceLab pod is plugged in.";
    }
    syncDeviceSelect();
    const menu = document.getElementById("device-menu");
    if (changed && menu && !menu.classList.contains("hidden")) renderDeviceMenu();
    await reconcileDeviceSelection(previous, devices);
  } catch (_) { /* Keep the last successful scan until the next retry. */ }
  finally { deviceScanInFlight = false; }
}

async function loadDeviceChoices() {
  await refreshDeviceList();
  try {
    api({ cmd: "list_profiles" }).then((profiles) => {
      state.profiles = profiles;
      const note = document.getElementById("profile-note");
      if (note) {
        const untested = profiles.filter((profile) => !profile.hardware_tested).length;
        const tested = profiles.filter((profile) => profile.hardware_tested).map((profile) => profile.name);
        note.textContent = `${tested.join(", ") || "No pod"} tested on hardware. ${untested} other logic product ids stay closed.`;
      }
      if (state.tab === "device") refillRateSelect();
      syncDeviceSelect();
    }).catch(() => {});
  } catch (err) {
    statusEl.textContent = err.message;
  }
}

async function applyDeviceChoice(value) {
  const ids = value.split("+").filter(Boolean);
  if (!ids.length || deviceChoiceInFlight) return;
  pendingAttachedPod = null;
  deviceChoiceInFlight = true;
  try {
    if (ids.some((id) => id.startsWith("usb:"))) {
      // Fetch the authoritative status before opening, even if the background
      // profile request is still in flight.
      const profiles = await api({ cmd: "list_profiles" });
      for (const id of ids.filter((item) => item.startsWith("usb:"))) {
        const profile = profiles.find((item) => item.id === id);
        if (!profile || !profile.hardware_tested) {
          const device = state.deviceList.find((item) => item.id === id);
          window.alert(`${profile?.name || device?.name || id}: support has not been tested in hardware.`);
          return;
        }
      }
    }
    await useDevice(ids[0]);
    for (const id of ids.slice(1)) {
      const status = await api({ cmd: "attach_device", id, session: state.active });
      state.gutterSig = "";
      applyStatus(status, false);
    }
    await loadDeviceChoices();
    if (state.tab === "device") selectTab("device");
  } catch (err) {
    statusEl.textContent = err.message;
    syncDeviceSelect();
    // USB open failures used to look like the chip "snapped back" to Demo with
    // only a status-line hint. Surface the reason in a dialog.
    if (ids.some((id) => id.startsWith("usb:"))) {
      window.alert(err.message || "Could not open the selected USB device.");
    }
  } finally { deviceChoiceInFlight = false; }
}

async function useDevice(id) {
  const connected = await api({ cmd: "connect", id });
  state.channelsAllDisabled = false;
  settings.device = connected.id;
  settings.deviceName = connected.name;
  const status = await api({ cmd: "status", session: state.active });
  state.gutterSig = "";
  applyStatus(status, false);
}

const PROTOCOL_LABEL = { i2c: "I2C", spi: "SPI", uart: "UART", eeprom24: "EEPROM 24xx" };
const GEAR_ICON = `<span class="settings-icon" aria-hidden="true"></span>`;
const TRASH_ICON = `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M9 7V5h6v2M8 7l1 13h6l1-13"></path></svg>`;

function escapeHtml(text) {
  return String(text).replace(/[&<>"']/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" })[ch]);
}

function protocolLabel(protocol) {
  return state.decoderCatalog.find((item) => item.id === protocol)?.name || PROTOCOL_LABEL[protocol] || protocol;
}

function decoderMatches(item, query) {
  const needle = String(query || "").trim().toLowerCase();
  if (!needle) return true;
  const tags = Array.isArray(item.tags) ? item.tags.join(" ") : "";
  return [item.name, item.id, item.longname, item.desc, tags]
    .filter((part) => part != null && part !== "")
    .join("\n")
    .toLowerCase()
    .includes(needle);
}

function chosenDecoderProtocol() {
  const catalog = state.decoderCatalog || [];
  if (state.decoderProtocol && catalog.some((item) => item.id === state.decoderProtocol)) {
    return state.decoderProtocol;
  }
  return catalog[0] ? catalog[0].id : "";
}

function protocolToAdd() {
  const menu = document.getElementById("decoder-kind-menu");
  if (menu && !menu.classList.contains("hidden")) {
    const active = menu.querySelector("[role='option'][aria-selected='true']");
    if (active && active.dataset.id) return active.dataset.id;
  }
  return chosenDecoderProtocol();
}

let decoderPickIndex = 0;

function placeDecoderPicker() {
  const button = document.getElementById("decoder-kind");
  const menu = document.getElementById("decoder-kind-menu");
  if (!button || !menu || menu.classList.contains("hidden")) return;
  const rect = button.getBoundingClientRect();
  const gap = 4;
  const below = window.innerHeight - rect.bottom - gap - 8;
  const above = rect.top - gap - 8;
  const downward = below >= 160 || below >= above;
  const limit = Math.max(120, Math.min(240, downward ? below : above));
  menu.style.width = rect.width + "px";
  menu.style.maxHeight = limit + "px";
  if (downward) {
    placeViewportMenu(menu, rect.left, rect.bottom + gap);
    return;
  }
  menu.style.top = "0px";
  placeViewportMenu(menu, rect.left, rect.top - gap - menu.offsetHeight);
}

function renderDecoderPickerList(matches) {
  const list = document.getElementById("decoder-kind-list");
  const search = document.getElementById("decoder-kind-search");
  if (!list) return;
  list.replaceChildren();
  if (!matches.length) {
    const empty = document.createElement("li");
    empty.className = "decoder-kind-empty";
    empty.textContent = "No matching decoders";
    list.append(empty);
    decoderPickIndex = -1;
    if (search) search.setAttribute("aria-activedescendant", "");
    return;
  }
  if (decoderPickIndex < 0 || decoderPickIndex >= matches.length) decoderPickIndex = 0;
  matches.forEach((item, index) => {
    const row = document.createElement("li");
    row.setAttribute("role", "option");
    row.dataset.id = item.id;
    row.id = "decoder-kind-opt-" + index;
    if (index === decoderPickIndex) row.setAttribute("aria-selected", "true");
    const name = document.createElement("span");
    name.className = "decoder-kind-name";
    name.textContent = item.name || item.id;
    const id = document.createElement("span");
    id.className = "decoder-kind-id";
    id.textContent = item.id;
    row.append(name, id);
    row.addEventListener("pointerdown", (ev) => ev.preventDefault());
    row.addEventListener("click", () => chooseDecoderProtocol(item.id));
    list.append(row);
  });
  const active = list.querySelector("[aria-selected='true']");
  if (search) search.setAttribute("aria-activedescendant", active ? active.id : "");
}

function closeDecoderPicker() {
  const menu = document.getElementById("decoder-kind-menu");
  const button = document.getElementById("decoder-kind");
  if (!menu || !button) return;
  menu.classList.add("hidden");
  button.setAttribute("aria-expanded", "false");
  const list = document.getElementById("decoder-kind-list");
  if (list) list.replaceChildren();
  const search = document.getElementById("decoder-kind-search");
  if (search) {
    search.value = "";
    search.setAttribute("aria-activedescendant", "");
  }
}

function openDecoderPicker() {
  const menu = document.getElementById("decoder-kind-menu");
  const button = document.getElementById("decoder-kind");
  const search = document.getElementById("decoder-kind-search");
  if (!menu || !button || !search) return;
  menu.classList.remove("hidden");
  button.setAttribute("aria-expanded", "true");
  search.value = "";
  const matches = (state.decoderCatalog || []).filter((item) => decoderMatches(item, ""));
  const selected = chosenDecoderProtocol();
  const found = matches.findIndex((item) => item.id === selected);
  decoderPickIndex = found >= 0 ? found : 0;
  renderDecoderPickerList(matches);
  placeDecoderPicker();
  search.focus();
  const active = document.getElementById("decoder-kind-list").querySelector("[aria-selected='true']");
  if (active) active.scrollIntoView({ block: "nearest" });
}

function chooseDecoderProtocol(id) {
  state.decoderProtocol = id;
  const label = document.getElementById("decoder-kind-label");
  if (label) label.textContent = protocolLabel(id);
  closeDecoderPicker();
}

function bindDecoderPicker() {
  const button = document.getElementById("decoder-kind");
  const picker = document.getElementById("decoder-kind-picker");
  const search = document.getElementById("decoder-kind-search");
  if (!button || !picker || !search) return;
  const current = chosenDecoderProtocol();
  if (current) state.decoderProtocol = current;
  const label = document.getElementById("decoder-kind-label");
  if (label) label.textContent = current ? protocolLabel(current) : "Decoder";
  button.addEventListener("click", (ev) => {
    ev.stopPropagation();
    const menu = document.getElementById("decoder-kind-menu");
    if (menu.classList.contains("hidden")) openDecoderPicker();
    else closeDecoderPicker();
  });
  picker.addEventListener("click", (ev) => ev.stopPropagation());
  search.addEventListener("input", () => {
    const matches = (state.decoderCatalog || []).filter((item) => decoderMatches(item, search.value));
    decoderPickIndex = matches.length ? 0 : -1;
    renderDecoderPickerList(matches);
  });
  search.addEventListener("keydown", (ev) => {
    const matches = (state.decoderCatalog || []).filter((item) => decoderMatches(item, search.value));
    if (ev.key === "ArrowDown" || ev.key === "ArrowUp") {
      ev.preventDefault();
      if (!matches.length) return;
      const delta = ev.key === "ArrowDown" ? 1 : -1;
      const base = decoderPickIndex < 0 ? 0 : decoderPickIndex;
      decoderPickIndex = (base + delta + matches.length) % matches.length;
      renderDecoderPickerList(matches);
      const active = document.getElementById("decoder-kind-list").querySelector("[aria-selected='true']");
      if (active) active.scrollIntoView({ block: "nearest" });
    } else if (ev.key === "Enter") {
      ev.preventDefault();
      const match = matches[decoderPickIndex];
      if (match) chooseDecoderProtocol(match.id);
    } else if (ev.key === "Escape") {
      ev.preventDefault();
      ev.stopPropagation();
      closeDecoderPicker();
      button.focus();
    }
  });
}

function emitsProtocol(protocol, expected) {
  if (!expected) return false;
  if (protocol === expected) return true;
  const schema = (state.decoderCatalog || []).find((item) => item.id === protocol);
  return Array.isArray(schema?.outputs) && schema.outputs.includes(expected);
}

async function addDecoder(protocol, channelIndex) {
  protocol = protocol || protocolToAdd();
  if (!protocol) return;
  state.decoderBusy = (state.decoderBusy || 0) + 1;
  paintStatus();
  let decodeError = null;
  try {
    const schema = (state.decoderCatalog || []).find((item) => item.id === protocol);
    const parent = schema?.stack_on && state.decoders.find((row) => emitsProtocol(row.protocol, schema.stack_on));
    const firstInput = [...(schema?.channels || []), ...(schema?.optional_channels || [])][0];
    const created = await api({
      cmd: "add_decoder",
      session: state.active,
      protocol,
      channels: {},
      stack_on: parent ? parent.id : null,
    });
    state.selectedDecoder = created.id;
    await refreshDecoders();
    const decoder = state.decoders.find((row) => row.id === created.id);
    if (decoder) {
      const pending = { ...decoder, channels: { ...decoder.channels } };
      if (channelIndex != null && firstInput) pending.channels[firstInput] = channelIndex;
      openDecodeConfig(pending);
    }
    await loadAnnotations();
  } catch (err) {
    decodeError = err;
  } finally {
    state.decoderBusy = Math.max(0, state.decoderBusy - 1);
    paintStatus();
    if (decodeError) statusEl.textContent = decodeError.message;
  }
}

async function refreshDecoders() {
  if (!state.active) return;
  state.decoders = await api({ cmd: "list_decoders", session: state.active });
  if (!state.selectedDecoder || !state.decoders.some((row) => row.id === state.selectedDecoder)) {
    state.selectedDecoder = state.decoders.length ? state.decoders[0].id : null;
  }
  renderDecoderList();
  state.gutterSig = "";
  renderGutter();
}

function renderDecoderList() {
  const host = document.getElementById("decoder-list");
  if (!host) return;
  host.replaceChildren();
  if (!state.decoders.length) {
    const empty = document.createElement("li");
    empty.className = "decoder-empty";
    empty.textContent = "No decoders added";
    host.append(empty);
  }
  for (const row of state.decoders) {
    const item = document.createElement("li");
    item.className = "decoder-row" + (row.id === state.selectedDecoder ? " selected" : "");
    const pick = document.createElement("button");
    pick.type = "button";
    pick.className = "decoder-pick";
    pick.textContent = protocolLabel(row.protocol);
    pick.addEventListener("click", () => {
      state.selectedDecoder = row.id;
      renderDecoderList();
      renderDecodeTable();
    });
    const gear = document.createElement("button");
    gear.type = "button";
    gear.className = "decoder-icon";
    gear.title = "Configure";
    gear.setAttribute("aria-label", "Configure " + protocolLabel(row.protocol));
    gear.innerHTML = GEAR_ICON;
    gear.addEventListener("click", () => openDecodeConfig(row));
    const trash = document.createElement("button");
    trash.type = "button";
    trash.className = "decoder-icon";
    trash.title = "Remove";
    trash.setAttribute("aria-label", "Remove " + protocolLabel(row.protocol));
    trash.innerHTML = TRASH_ICON;
    trash.addEventListener("click", async () => {
      await api({ cmd: "remove_decoder", session: state.active, id: row.id });
      delete state.spiView[row.id];
      delete state.decodeView[row.id];
      if (state.selectedDecoder === row.id) state.selectedDecoder = null;
      await refreshDecoders();
      await loadAnnotations();
    });
    item.append(pick, gear, trash);
    host.append(item);
  }
}

let waveformAnnotationTimer = null;
let waveformAnnotationRequest = 0;
let waveformAnnotationRange = null;

function scheduleWaveformAnnotations(panning = false) {
  const v = view();
  const visibleStart = Math.max(0, Math.floor(v.start));
  const visibleEnd = Math.max(visibleStart + 1, Math.ceil(v.start + Math.max(1, wave.clientWidth) * v.spp));
  const range = waveformAnnotationRange;
  if (panning && range && range.session === state.active && range.spp === v.spp &&
      range.start <= visibleStart && range.end >= visibleEnd) return;
  const request = ++waveformAnnotationRequest;
  clearTimeout(waveformAnnotationTimer);
  if (!state.active || !state.total || !state.decoders.length) {
    state.waveformAnnotations = [];
    waveformAnnotationRange = null;
    return;
  }
  const session = state.active;
  const margin = panning ? visibleEnd - visibleStart : 0;
  const start = Math.max(0, visibleStart - margin);
  const end = Math.min(state.total, visibleEnd + margin);
  waveformAnnotationRange = { session, spp: v.spp, start, end };
  const decoders = state.decoders.map((decoder) => decoder.id);
  waveformAnnotationTimer = setTimeout(async () => {
    try {
      const pages = await Promise.all(decoders.map(async (decoder) => {
        const rows = [];
        let page;
        do {
          page = await api({ cmd: "read_annotations", session, decoder, start, end, offset: rows.length, limit: 5000 });
          if (request !== waveformAnnotationRequest || state.active !== session) return [];
          rows.push(...page);
        } while (page.length === 5000);
        return rows;
      }));
      if (request !== waveformAnnotationRequest || state.active !== session) return;
      state.waveformAnnotations = pages.flat();
      drawWave();
    } catch (err) {
      if (request === waveformAnnotationRequest) { waveformAnnotationRange = null; statusEl.textContent = err.message; }
    }
  }, panning ? 30 : 100);
}

async function loadAnnotations() {
  if (!state.active) return;
  try {
    if (!state.decoders.length) {
      state.decoders = await api({ cmd: "list_decoders", session: state.active });
    }
    state.annotations = await api({
      cmd: "read_annotations",
      session: state.active,
      limit: 2000,
    });
  } catch (err) {
    state.annotations = [];
    statusEl.textContent = err.message;
  }
  renderDecodeTable();
  state.gutterSig = "";
  renderGutter();
  scheduleWaveformAnnotations();
  drawWave();
}

function renderDecodeTable() {
  const body = document.getElementById("decode-table");
  if (!body) return;
  const decoder = (state.decoders || []).find((row) => row.id === state.selectedDecoder);
  const rows = tableRows();
  if (!decoder) {
    body.innerHTML = `<div class="table-empty">Add a decoder to see its data here.</div>`;
    return;
  }
  if (!rows.length) {
    body.innerHTML = `<div class="table-empty">No rows for ${escapeHtml(protocolLabel(decoder.protocol))} yet.</div>`;
    return;
  }
  const table = document.createElement("table");
  table.className = "ann";
  const head = document.createElement("tr");
  const spi = decoder.protocol === "spi";
  head.innerHTML = spi ? "<td>Time</td><td>MOSI</td><td>MISO</td><td>Text</td>" : "<td>Time</td><td>Class</td><td>Text</td>";
  table.append(head);
  for (const row of rows) {
    const tr = document.createElement("tr");
    const time = formatSeconds(sampleSeconds(row.start_sample));
    const fields = row.fields || {};
    if (spi) {
      tr.innerHTML = `<td>${time}</td><td>${escapeHtml(fields.mosi || "")}</td><td>${escapeHtml(fields.miso || "")}</td><td>${escapeHtml(row.text)}</td>`;
    } else {
      tr.innerHTML = `<td>${time}</td><td>${escapeHtml(row.class)}</td><td>${escapeHtml(row.text)}</td>`;
    }
    tr.addEventListener("click", () => centerOn(row.start_sample));
    table.append(tr);
  }
  body.replaceChildren(table);
}

function tableRows() {
  const id = state.selectedDecoder;
  const query = (state.decodeQuery || "").trim().toLowerCase();
  return (state.annotations || []).filter((row) => {
    if (id && row.decoder !== id) return false;
    if (!query) return true;
    const fields = row.fields ? Object.values(row.fields).join(" ") : "";
    return `${row.class} ${row.text} ${fields}`.toLowerCase().includes(query);
  });
}

function centerOn(sample) {
  const v = view();
  const width = Math.max(1, wave.clientWidth);
  v.start = sample - width * v.spp * 0.5;
  v.userNavigated = true;
  clampView();
  scheduleTiles();
  drawRuler();
  drawOverview();
}

function hoverSample() {
  if (state.hoverX == null || state.total <= 0) return 0;
  if (state.hoverSnap) return state.hoverSnap.sample;
  return Math.min(state.total - 1, Math.max(0, Math.floor(view().start + state.hoverX * view().spp)));
}

function sampleAt(clientX) {
  const rect = wave.getBoundingClientRect();
  const x = clientX - rect.left;
  if (state.total <= 0) return 0;
  return Math.min(state.total - 1, Math.max(0, Math.floor(view().start + x * view().spp)));
}

function rowAt(clientY) {
  const rect = wave.getBoundingClientRect();
  const y = clientY - rect.top;
  const { layout } = rowMetrics();
  if (!layout.length) return null;
  if (y < layout[0].top) return null;
  for (const item of layout) {
    if (y >= item.top && y < item.top + item.height) return item.row;
  }
  return null;
}

function placeEdgeButtons(clientY) {
  state.edgePointerY = clientY;
  const prev = document.getElementById("edge-prev");
  const next = document.getElementById("edge-next");
  const stage = document.querySelector(".wave-stage");
  const row = rowAt(clientY);
  if (!prev || !next || !stage || !row || !["logic", "bus", "decode", "condense"].includes(row.kind) || state.total <= 0) {
    hideEdgeButtons();
    return;
  }
  const item = rowMetrics().layout.find((entry) => entry.row.key === row.key);
  if (!item) {
    hideEdgeButtons();
    return;
  }
  const mid = item.top + item.height / 2 - stage.scrollTop;
  if (mid < 10 || mid > stage.clientHeight - 10) {
    hideEdgeButtons();
    return;
  }
  state.edgeChannel = row.channel;
  state.edgeRow = row;
  prev.style.top = mid + "px";
  next.style.top = mid + "px";
  prev.classList.remove("hidden");
  next.classList.remove("hidden");
}

function hideEdgeButtons() {
  state.edgeChannel = null;
  state.edgeRow = null;
  document.getElementById("edge-prev")?.classList.add("hidden");
  document.getElementById("edge-next")?.classList.add("hidden");
}

function activeLogicChannel() {
  if (state.hoverKey && state.hoverKey.startsWith("logic:")) return state.hoverChannel;
  const v = ensureSelection();
  const rows = orderedRows();
  const anchor = rows.find((row) => row.key === v.anchor && row.kind === "logic");
  if (anchor) return anchor.channel;
  const chosen = rows.find((row) => v.selection.includes(row.key) && row.kind === "logic");
  if (chosen) return chosen.channel;
  const first = rows.find((row) => row.kind === "logic");
  return first ? first.channel : 0;
}

async function searchPattern(forward) {
  const field = document.getElementById("set-pattern");
  if (field) settings.pattern = field.value;
  const from = state.hoverX == null ? Math.floor(view().start) : hoverSample();
  try {
    const data = await api({
      cmd: "search_pattern",
      session: state.active,
      channel: activeLogicChannel(),
      from,
      pattern: settings.pattern,
      forward,
    });
    if (data.sample == null) {
      statusEl.textContent = "no match";
      return;
    }
    centerOn(data.sample);
    statusEl.textContent = `match at ${data.sample}`;
  } catch (err) {
    statusEl.textContent = err.message;
  }
}

async function stepEdge(forward, channel) {
  if (state.total <= 0) return;
  if (channel == null) channel = state.edgeChannel == null ? activeLogicChannel() : state.edgeChannel;
  const from = state.hoverX == null
    ? Math.floor(view().start + wave.clientWidth * view().spp * 0.5)
    : hoverSample();
  try {
    const rising = await api({
      cmd: "search_edge",
      session: state.active,
      channel,
      from,
      rising: true,
      forward,
    });
    const falling = await api({
      cmd: "search_edge",
      session: state.active,
      channel,
      from,
      rising: false,
      forward,
    });
    const hits = [rising.sample, falling.sample].filter((sample) => sample != null);
    if (!hits.length) {
      statusEl.textContent = "no edge";
      return;
    }
    const sample = hits.reduce((best, sample) => (Math.abs(sample - from) < Math.abs(best - from) ? sample : best));
    centerOn(sample);
    statusEl.textContent = `edge at ${sample} on channel ${channel}`;
  } catch (err) {
    statusEl.textContent = err.message;
  }
}

async function stepDataChange(forward, row) {
  if (!row || row.kind === "logic") return stepEdge(forward, row?.channel);
  const from = state.hoverX == null
    ? Math.floor(view().start + wave.clientWidth * view().spp * 0.5)
    : hoverSample();
  const session = state.active;
  try {
    let hits = [];
    if (row.kind === "bus" && !row.bus.decode) {
      const channels = [...new Set(descendantChannels(row.bus))];
      const results = await Promise.all(channels.flatMap((channel) => [true, false].map((rising) =>
        api({ cmd: "search_edge", session, channel, from, rising, forward }))));
      hits = results.map((result) => result.sample).filter((sample) => sample != null);
    } else {
      const decoder = (state.decoders || []).find((entry) => entry.id === row.decoderId);
      if (!decoder) return;
      let offset = 0;
      const rows = [];
      for (;;) {
        const page = await api({ cmd: "read_annotations", session, decoder: row.decoderId, offset, limit: 5000 });
        rows.push(...page);
        if (page.length < 5000) break;
        offset += page.length;
      }
      if (state.active !== session) return;
      const values = decoder.protocol === "rgb_led_ws281x" ? rows.filter((item) => item.class === "byte") : (() => {
        const filtered = rows.filter((item) => !FRAME_CLASS.has(item.class));
        return filtered.length ? filtered : rows;
      })();
      hits = laneAnnotations(values, row.lane, decoder).flatMap((item) => [item.start_sample, item.end_sample])
        .filter((sample) => forward ? sample > from && sample < state.total : sample < from);
    }
    if (!hits.length) { statusEl.textContent = "no data change"; return; }
    const sample = hits.reduce((best, hit) => forward ? Math.min(best, hit) : Math.max(best, hit));
    centerOn(sample);
    statusEl.textContent = `data change at ${sample}`;
  } catch (err) {
    statusEl.textContent = err.message;
  }
}

async function dropCursor(which) {
  const sample = state.hoverX == null ? Math.floor(view().start) : hoverSample();
  try {
    const data = await api({ cmd: "set_cursor", session: state.active, which, sample });
    state.cursors = [data.a, data.b];
    drawRuler();
    const span = await api({ cmd: "cursor_span", session: state.active, channel: activeLogicChannel() });
    const readout = document.getElementById("cursor-readout");
    if (readout) {
      readout.textContent = `A ${data.a} · B ${data.b} · ${span.samples} samples · ${span.edges} edges`;
    }
  } catch (err) {
    const readout = document.getElementById("cursor-readout");
    if (readout) readout.textContent = err.message;
  }
}

async function keepMeasurement() {
  const kept = state.lastMeasure;
  if (!kept) {
    statusEl.textContent = "hover a logic trace first";
    return;
  }
  try {
    await api({
      cmd: "save_measurement",
      session: state.active,
      channel: kept.channel,
      sample: kept.sample,
    });
    refreshMeasurements();
  } catch (err) {
    statusEl.textContent = err.message;
  }
}

async function refreshMeasurements() {
  const host = document.getElementById("saved-measures");
  if (!host) return;
  const rows = await api({ cmd: "list_measurements", session: state.active });
  host.replaceChildren();
  for (const row of rows) {
    const p = document.createElement("p");
    const duty = row.duty == null ? "—" : `${(row.duty * 100).toFixed(1)}%`;
    const freq = row.frequency_hz == null ? "—" : `${Math.round(row.frequency_hz)} Hz`;
    p.textContent = `#${row.id} ch${row.channel} @ ${row.sample}: width ${row.pulse_width_samples} · period ${row.period_samples ?? "—"} · ${freq} · duty ${duty}`;
    host.appendChild(p);
  }
}

const SAVE_KINDS = {
  csv: {
    title: "Save CSV",
    filename: "capture.csv",
    ext: ".csv",
    mime: "text/csv",
    path: "/api/export/csv",
    note: "One row per sample: time and logic levels.",
    picker: { description: "CSV", accept: { "text/csv": [".csv"] } },
  },
  xlsx: {
    title: "Save Excel",
    filename: "capture.xlsx",
    ext: ".xlsx",
    mime: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    path: "/api/export/xlsx",
    note: "One row per sample. A long capture is cut at Excel's row limit.",
    picker: { description: "Excel workbook", accept: { "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": [".xlsx"] } },
  },
  lvcap: {
    title: "Save capture",
    filename: "capture.lvcap",
    ext: ".lvcap",
    mime: "application/zip",
    path: "/api/export/lvcap",
    note: "LogicView capture, including the samples.",
    picker: { description: "LogicView capture", accept: { "application/zip": [".lvcap"] } },
  },
  dsl: {
    title: "Save capture",
    filename: "capture.dsl",
    ext: ".dsl",
    mime: "application/zip",
    path: "/api/export/dsl",
    note: "Capture container with the sample blocks.",
    picker: { description: "Capture", accept: { "application/zip": [".dsl"] } },
  },
};

let saveJob = null;

let pendingSavePick = null;

function pickSaveFile(kind) {
  return new Promise((resolve) => {
    if (pendingSavePick) pendingSavePick.resolve(null);
    pendingSavePick = { kind, resolve };
    window.ipc.postMessage("save-file:" + kind);
  });
}

window.logicviewSaveSelected = (kind, path) => {
  const pending = pendingSavePick;
  pendingSavePick = null;
  if (!pending || pending.kind !== kind) return;
  pending.resolve(path || null);
};

async function saveCaptureExport(kind) {
  const spec = SAVE_KINDS[kind];
  if (!spec) return;
  if (!(state.total > 0)) {
    statusEl.textContent = "nothing captured yet";
    return;
  }
  if (window.ipc && kind === "lvcap") {
    const path = await pickSaveFile(kind);
    if (!path) {
      statusEl.textContent = "save cancelled";
      return;
    }
    try {
      const response = await fetch("/api/save-as", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ path }),
      });
      const json = await response.json().catch(() => ({}));
      if (!response.ok || !json.ok) throw new Error(json.error || "save failed");
      statusEl.textContent = "saved " + (json.path || path);
    } catch (err) {
      statusEl.textContent = err.message || "save failed";
    }
    return;
  }
  try {
    const produced = await fetchCaptureBlob(spec.path);
    const blob = produced instanceof Blob ? produced : new Blob([produced], { type: spec.mime || "application/octet-stream" });
    const wrote = await writeChosenFile(spec.filename, blob, spec.picker);
    if (wrote === "cancel") statusEl.textContent = "save cancelled";
    else statusEl.textContent = "saved " + wrote;
  } catch (err) {
    statusEl.textContent = err.message || "save failed";
  }
}

async function fetchCaptureBlob(path) {
  const res = await fetch(path);
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || "export failed");
  }
  const rows = res.headers.get("x-logicview-rows");
  const total = res.headers.get("x-logicview-total");
  if (rows && total && rows !== total) {
    statusEl.textContent = `exported ${Number(rows).toLocaleString()} of ${Number(total).toLocaleString()} samples`;
  }
  return res.blob();
}

function openSaveDialog(job) {
  saveJob = job;
  document.getElementById("save-title").textContent = job.title;
  document.getElementById("save-note").textContent = job.note || "";
  const input = document.getElementById("save-name");
  input.value = job.filename;
  document.getElementById("save-dialog").classList.remove("hidden");
  input.focus();
  input.select();
}

function closeSaveDialog() {
  saveJob = null;
  document.getElementById("save-dialog").classList.add("hidden");
}

async function confirmSave(ev) {
  ev.preventDefault();
  const job = saveJob;
  if (!job) return;
  const button = document.getElementById("save-confirm");
  button.disabled = true;
  try {
    let name = document.getElementById("save-name").value.trim() || job.filename;
    name = name.replace(/[\\/]/g, "");
    if (job.ext && !name.toLowerCase().endsWith(job.ext)) name += job.ext;
    const produced = await job.produce();
    const blob = produced instanceof Blob ? produced : new Blob([produced], { type: job.mime || "application/octet-stream" });
    closeSaveDialog();
    const wrote = await writeChosenFile(name, blob, job.picker);
    if (wrote === "cancel") statusEl.textContent = "save cancelled";
    else statusEl.textContent = "saved " + wrote;
  } catch (err) {
    statusEl.textContent = err.message || "save failed";
  } finally {
    button.disabled = false;
  }
}

async function writeChosenFile(name, blob, pickerType) {
  if (typeof window.showSaveFilePicker === "function") {
    try {
      const handle = await window.showSaveFilePicker({
        suggestedName: name,
        types: pickerType ? [pickerType] : undefined,
      });
      const writable = await handle.createWritable();
      await writable.write(blob);
      await writable.close();
      return handle.name || name;
    } catch (err) {
      if (err && err.name === "AbortError") return "cancel";
    }
  }
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = name;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(link.href), 1500);
  return name;
}

const EXPORT_TYPES = [
  { id: "csv", label: "CSV" },
  { id: "xlsx", label: "Excel" },
  { id: "lvcap", label: "LogicView (.lvcap)" },
  { id: "dsl", label: "DSL (.dsl)" },
  { id: "annotations", label: "Annotations CSV" },
];

function storedNumber(key, fallback) {
  try {
    const value = Number(localStorage.getItem(key));
    if (Number.isInteger(value) && value >= 1) return value;
  } catch (_) { /* private mode keeps the counter in memory */ }
  return fallback;
}

function storedText(key) {
  try { return localStorage.getItem(key) || ""; } catch (_) { return ""; }
}

let exportSerial = storedNumber("logicview-export-serial", 1);
const exportChoice = {
  kind: "csv",
  directory: storedText("logicview-export-dir"),
  filename: `Capture(${storedNumber("logicview-export-serial", 1)})`,
};

function captureFileName(n) {
  return `Capture(${n})`;
}

function exportFormHtml(prefix) {
  const options = EXPORT_TYPES.map((item) => {
    const selected = item.id === exportChoice.kind ? " selected" : "";
    return `<option value="${item.id}"${selected}>${escapeHtml(item.label)}</option>`;
  }).join("");
  return `<label class="field">Type
      <select id="${prefix}-export-kind" aria-label="Export type">${options}</select>
    </label>
    <label class="field">Location
      <span class="path-row export-location">
        <input id="${prefix}-export-dir" type="text" spellcheck="false" autocomplete="off" placeholder="Output folder" value="${escapeHtml(exportChoice.directory)}">
        <button type="button" class="path-browse" data-path-target="${prefix}-export-dir" aria-label="Choose output folder">...</button>
      </span>
    </label>
    <label class="field">File name
      <input id="${prefix}-export-name" type="text" spellcheck="false" autocomplete="off" value="${escapeHtml(exportChoice.filename)}">
    </label>
    <button class="block" id="${prefix}-export-go" type="button">Export</button>
    <p class="hint">CSV and Excel list one row per sample. A long capture is cut at Excel's row limit.</p>`;
}

function syncExportChoice(prefix) {
  const kind = document.getElementById(`${prefix}-export-kind`);
  const dir = document.getElementById(`${prefix}-export-dir`);
  const name = document.getElementById(`${prefix}-export-name`);
  if (kind) exportChoice.kind = kind.value;
  if (dir && dir.value !== exportChoice.directory) rememberExportDirectory(dir.value);
  if (name) exportChoice.filename = name.value;
  paintExportFields(prefix);
}

function paintExportFields(except, force) {
  for (const prefix of ["panel", "dialog"]) {
    if (prefix === except) continue;
    const kind = document.getElementById(`${prefix}-export-kind`);
    const dir = document.getElementById(`${prefix}-export-dir`);
    const name = document.getElementById(`${prefix}-export-name`);
    if (kind && (force || document.activeElement !== kind)) kind.value = exportChoice.kind;
    if (dir && (force || document.activeElement !== dir)) dir.value = exportChoice.directory;
    if (name && (force || document.activeElement !== name)) name.value = exportChoice.filename;
  }
}

function parentDirectory(value) {
  const trimmed = String(value || "").replace(/[\\/]+$/, "");
  const index = Math.max(trimmed.lastIndexOf("\\"), trimmed.lastIndexOf("/"));
  if (index < 0) return "";
  const parent = trimmed.slice(0, index);
  if (/^[A-Za-z]:$/.test(parent)) return parent + "\\";
  return parent;
}

function assignExportDirectory(input, folder) {
  if (!input || !folder) return;
  input.value = folder;
  syncExportChoice(input.id.startsWith("dialog-") ? "dialog" : "panel");
}

function bindExportForm(prefix) {
  const kind = document.getElementById(`${prefix}-export-kind`);
  const dir = document.getElementById(`${prefix}-export-dir`);
  const name = document.getElementById(`${prefix}-export-name`);
  const go = document.getElementById(`${prefix}-export-go`);
  if (!kind || !dir || !name || !go || kind.dataset.bound) return;
  kind.dataset.bound = "1";
  kind.addEventListener("change", () => syncExportChoice(prefix));
  dir.addEventListener("input", () => syncExportChoice(prefix));
  name.addEventListener("input", () => syncExportChoice(prefix));
  go.addEventListener("click", () => runExport(prefix));
  const row = dir.closest(".export-location") || dir;
  row.addEventListener("dragenter", (ev) => {
    ev.preventDefault();
    row.classList.add("dragover");
  });
  row.addEventListener("dragover", (ev) => {
    ev.preventDefault();
    if (ev.dataTransfer) ev.dataTransfer.dropEffect = "copy";
    row.classList.add("dragover");
  });
  row.addEventListener("dragleave", (ev) => {
    if (ev.relatedTarget && row.contains(ev.relatedTarget)) return;
    row.classList.remove("dragover");
  });
  row.addEventListener("drop", (ev) => {
    ev.preventDefault();
    ev.stopPropagation();
    row.classList.remove("dragover");
    const file = ev.dataTransfer && ev.dataTransfer.files && ev.dataTransfer.files[0];
    const raw = file && file.path;
    if (!raw) {
      statusEl.textContent = "Drop a folder on the location field.";
      return;
    }
    const leaf = String(raw).split(/[\\/]/).pop() || "";
    assignExportDirectory(dir, /\.[A-Za-z0-9]{1,8}$/.test(leaf) ? parentDirectory(raw) : raw);
  });
}

function advanceExportName() {
  exportSerial += 1;
  try { localStorage.setItem("logicview-export-serial", String(exportSerial)); } catch (_) { /* the next name is still shown */ }
  exportChoice.filename = captureFileName(exportSerial);
  paintExportFields(null, true);
}

async function runExport(prefix) {
  syncExportChoice(prefix);
  const directory = exportChoice.directory.trim();
  if (!directory) {
    statusEl.textContent = "Choose an output folder";
    return;
  }
  const filename = exportChoice.filename.trim().replace(/[\\/]/g, "");
  if (!filename || filename === "." || filename === "..") {
    statusEl.textContent = "Enter a file name";
    return;
  }
  const button = document.getElementById(`${prefix}-export-go`);
  if (button) button.disabled = true;
  try {
    const response = await fetch("/api/export-to", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        kind: exportChoice.kind,
        directory,
        filename,
        query: (state.decodeQuery || "").trim() || null,
      }),
    });
    const text = await response.text();
    let json = {};
    try { json = JSON.parse(text); } catch (_) { json = { error: text }; }
    if (!response.ok || json.ok === false) throw new Error(json.error || "export failed");
    if (json.rows != null && json.total != null && Number(json.rows) !== Number(json.total)) {
      statusEl.textContent = `exported ${Number(json.rows).toLocaleString()} of ${Number(json.total).toLocaleString()} samples`;
    } else {
      statusEl.textContent = "saved " + (json.path || filename);
    }
    advanceExportName();
  } catch (err) {
    statusEl.textContent = err.message || "export failed";
  } finally {
    if (button) button.disabled = false;
  }
}

function openExportDialog() {
  paintExportFields(null, true);
  const dialog = document.getElementById("export-dialog");
  const logo = dialog.querySelector(".export-logo");
  dialog.showModal();
  if (logo && !logo.naturalWidth) {
    logo.removeAttribute("src");
    logo.src = "/assets/ExportFileLogo.png";
  }
}

function closeExportDialog() {
  const dialog = document.getElementById("export-dialog");
  if (dialog.open) dialog.close();
}

function setupDocument() {
  const v = view();
  const mode = document.getElementById("cursor-mode");
  const decoders = state.decoders || [];
  return {
    kind: "logicview-setup",
    version: 1,
    order: v.order || orderedRows().map((row) => row.key),
    heights: v.heights || {},
    customHeights: !!v.customHeights,
    names: v.names || {},
    hidden: [...state.hidden],
    buses: v.buses || [],
    nextBus: v.nextBus || 1,
    selection: ensureSelection().selection,
    anchor: v.anchor || null,
    selected: v.anchor || null,
    colors: v.colors || {},
    modes: signalModes(),
    markers: (v.markers || []).map((marker) => ({
      id: marker.id,
      n: marker.n,
      sample: marker.sample,
      channel: marker.channel,
      name: marker.name || "",
    })),
    cursors: {
      a: state.cursors ? state.cursors[0] : null,
      b: state.cursors ? state.cursors[1] : null,
      mode: mode ? mode.value : "single",
    },
    decoders: decoders.map((decoder) => ({
      protocol: decoder.protocol,
      channels: Object.fromEntries(Object.entries(decoder.channels || {}).map(([name, index]) => [name, channelSpecByIndex(index)])),
      options: decoder.options || {},
      stackIndex: decoder.stack_on ? decoders.findIndex((row) => row.id === decoder.stack_on) : null,
      view: Object.assign({ overlay: true, condensed: false, format: "hex" }, state.decodeView[decoder.id] || {}),
    })),
  };
}

function channelSpecByIndex(index) {
  const channel = state.channels.find((row) => row.index === index);
  return channel ? channelSpec(channel) : String(index);
}

async function saveSetup() {
  const setup = setupDocument();
  try {
    if (window.ipc) {
      const path = await pickSaveFile("setup");
      if (!path) { statusEl.textContent = "save cancelled"; return; }
      const response = await fetch("/api/save-setup", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ path, setup }),
      });
      const json = await response.json().catch(() => ({}));
      if (!response.ok || !json.ok) throw new Error(json.error || "save failed");
      statusEl.textContent = "saved " + (json.path || path);
      return;
    }
    const blob = new Blob([JSON.stringify(setup, null, 2)], { type: "application/json" });
    const wrote = await writeChosenFile("setup.lvsetup", blob, {
      description: "LogicView setup", accept: { "application/json": [".lvsetup", ".json"] },
    });
    statusEl.textContent = wrote === "cancel" ? "save cancelled" : "saved " + wrote;
  } catch (err) {
    statusEl.textContent = err.message || "save failed";
  }
}

async function openSetupFile(file) {
  let doc;
  try {
    doc = JSON.parse(await file.text());
  } catch (_) {
    statusEl.textContent = "setup file is not JSON";
    return;
  }
  try {
    await applySetup(doc);
    statusEl.textContent = "opened " + file.name;
  } catch (err) {
    statusEl.textContent = err.message || "could not open setup";
  }
}

async function applySetup(doc) {
  if (!doc || doc.kind !== "logicview-setup") throw new Error("not a LogicView setup");
  const v = view();
  v.order = Array.isArray(doc.order) ? doc.order : v.order;
  v.heights = doc.heights && typeof doc.heights === "object" ? doc.heights : {};
  v.customHeights = !!doc.customHeights;
  v.names = doc.names && typeof doc.names === "object" ? doc.names : {};
  v.colors = doc.colors && typeof doc.colors === "object" ? doc.colors : {};
  v.modes = doc.modes && typeof doc.modes === "object" ? doc.modes : {};
  v.buses = Array.isArray(doc.buses) ? doc.buses : [];
  for (const bus of v.buses) normalizeContainerInPlace(bus);
  v.nextBus = Number(doc.nextBus) || v.nextBus || 1;
  if (Array.isArray(doc.selection)) {
    v.selection = doc.selection;
    v.anchor = doc.anchor || doc.selection[0] || null;
  } else if (doc.selected) {
    v.selection = [doc.selected];
    v.anchor = doc.selected;
  } else {
    v.selection = [];
    v.anchor = null;
  }
  v.selected = v.anchor;
  v.markers = Array.isArray(doc.markers) ? doc.markers : [];
  const maxMarker = v.markers.reduce((max, marker) => Math.max(max, Number(marker.id) || 0), 0);
  state.nextMarker = Math.max(state.nextMarker, maxMarker + 1);
  state.hidden = new Set(Array.isArray(doc.hidden) ? doc.hidden : []);
  if (v.order) persistOrder(v.order);
  persistColors();
  const mode = document.getElementById("cursor-mode");
  if (mode && doc.cursors && doc.cursors.mode) mode.value = doc.cursors.mode;
  if (doc.cursors) {
    state.cursors = [doc.cursors.a ?? null, doc.cursors.b ?? null];
    if (doc.cursors.a != null) await api({ cmd: "set_cursor", session: state.active, which: 0, sample: doc.cursors.a });
    if (doc.cursors.b != null) await api({ cmd: "set_cursor", session: state.active, which: 1, sample: doc.cursors.b });
  }
  const existing = [...await api({ cmd: "list_decoders", session: state.active })].reverse();
  for (const row of existing) {
    try { await api({ cmd: "remove_decoder", session: state.active, id: row.id }); } catch (_) { /* already removed with its parent */ }
  }
  state.decodeView = {};
  state.spiView = {};
  const created = [];
  for (const decoder of doc.decoders || []) {
    const stack = Number.isInteger(decoder.stackIndex) ? created[decoder.stackIndex] : null;
    const info = await api({
      cmd: "add_decoder",
      session: state.active,
      protocol: decoder.protocol,
      channels: decoder.channels || {},
      options: decoder.options || {},
      stack_on: stack || null,
    });
    created.push(info.id);
    if (decoder.view) state.decodeView[info.id] = Object.assign({ overlay: true, condensed: false, format: "hex" }, decoder.view);
  }
  state.gutterSig = "";
  await refreshDecoders();
  await loadAnnotations();
  renderMarkerList();
  drawWave();
  drawRuler();
}

function openColorFlyout(row, anchor) {
  const fly = document.getElementById("color-flyout");
  const key = colorKey(row);
  if (!fly.classList.contains("hidden") && fly.dataset.key === key) {
    closeColorFlyout();
    return;
  }
  fly.dataset.key = key;
  fly.dataset.row = row.key;
  const current = normalizeHex(row.color);
  document.getElementById("color-custom").value = current;
  for (const swatch of fly.querySelectorAll(".swatch")) {
    swatch.classList.toggle("picked", swatch.dataset.color === current);
  }
  placeColorFlyout(anchor);
}

function closeColorFlyout() {
  const fly = document.getElementById("color-flyout");
  fly.classList.add("hidden");
  delete fly.dataset.key;
  delete fly.dataset.row;
}

function placeColorFlyout(anchor) {
  const fly = document.getElementById("color-flyout");
  fly.classList.remove("hidden");
  const rect = anchor.getBoundingClientRect();
  const width = fly.offsetWidth;
  const height = fly.offsetHeight;
  let left = rect.right + 8;
  let top = rect.top;
  if (left + width > window.innerWidth - 8) left = Math.max(8, rect.left - width - 8);
  if (top + height > window.innerHeight - 8) top = Math.max(8, window.innerHeight - 8 - height);
  fly.style.left = left + "px";
  fly.style.top = top + "px";
}

function normalizeHex(color) {
  const text = String(color || "").trim();
  return /^#[0-9a-fA-F]{6}$/.test(text) ? text.toLowerCase() : "#e2b340";
}

function setChannelColor(rowKey, color) {
  const row = orderedRows().find((item) => item.key === rowKey);
  if (!row) return;
  const colors = view().colors || (view().colors = {});
  colors[colorKey(row)] = color;
  persistColors();
  state.gutterSig = "";
  renderGutter();
  drawWave();
  if (row.kind === "logic") {
    const button = document.querySelector(`.ch-en[data-bit="${row.channel}"]`);
    if (button) button.style.setProperty("--ch", color);
  }
  const fly = document.getElementById("color-flyout");
  if (!fly.classList.contains("hidden")) {
    const current = normalizeHex(color);
    document.getElementById("color-custom").value = current;
    for (const swatch of fly.querySelectorAll(".swatch")) {
      swatch.classList.toggle("picked", swatch.dataset.color === current);
    }
    const anchor = gutter.querySelector(`.ch[data-key="${CSS.escape(rowKey)}"] .bar`);
    if (anchor) placeColorFlyout(anchor);
  }
}

function fillColorSwatches() {
  const host = document.getElementById("color-swatches");
  if (!host || host.childElementCount) return;
  for (const color of CHANNEL_COLORS) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "swatch";
    button.dataset.color = color;
    button.style.background = color;
    button.title = color;
    button.setAttribute("aria-label", color);
    button.addEventListener("click", () => {
      const fly = document.getElementById("color-flyout");
      if (fly.dataset.row) setChannelColor(fly.dataset.row, color);
    });
    host.appendChild(button);
  }
}

function isCaptureName(name) {
  const lower = String(name || "").toLowerCase();
  return lower.endsWith(".lvcap") || lower.endsWith(".dsl");
}

async function openCaptureFile(file) {
  statusEl.textContent = "opening " + file.name;
  const bytes = await file.arrayBuffer();
  const res = await fetch("/api/import?name=" + encodeURIComponent(file.name), {
    method: "POST",
    headers: { "content-type": "application/octet-stream" },
    body: bytes,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok || !json.ok) {
    statusEl.textContent = json.error || "could not open capture";
    return;
  }
  await applyImportedCapture(json.data, file.name);
}

let pendingFilePick = null;

function pickCaptureFile(kind) {
  if (window.ipc) {
    return new Promise((resolve) => {
      if (pendingFilePick) pendingFilePick.resolve(null);
      pendingFilePick = { kind, resolve };
      window.ipc.postMessage("pick-file:" + kind);
    });
  }
  const input = document.getElementById(kind === "load" ? "load-file" : "import-file");
  return new Promise((resolve) => {
    const onChange = () => {
      input.removeEventListener("change", onChange);
      const file = input.files && input.files[0];
      input.value = "";
      resolve(file || null);
    };
    input.addEventListener("change", onChange);
    input.click();
  });
}

window.logicviewFileSelected = (kind, path) => {
  const pending = pendingFilePick;
  pendingFilePick = null;
  if (!pending || pending.kind !== kind) return;
  pending.resolve(path || null);
};

function captureLeaf(picked) {
  if (!picked) return "";
  if (typeof picked === "string") return picked.split(/[\\/]/).pop() || "";
  return picked.name || "";
}

async function openPickedCapture(picked) {
  if (typeof picked === "string") await openNativeCapture(picked);
  else await openCaptureFile(picked);
}

async function loadSavedCapture() {
  const picked = await pickCaptureFile("load");
  if (!picked) return;
  if (!captureLeaf(picked).toLowerCase().endsWith(".lvcap")) {
    statusEl.textContent = "Load a .lvcap capture";
    return;
  }
  await openPickedCapture(picked);
}

async function importCapture() {
  const picked = await pickCaptureFile("import");
  if (!picked) return;
  if (!isCaptureName(captureLeaf(picked))) {
    statusEl.textContent = "Import a .lvcap or .dsl capture";
    return;
  }
  await openPickedCapture(picked);
}

function closeLogicView() {
  if (window.ipc) window.ipc.postMessage("close");
  else window.close();
}

async function applyImportedCapture(data, name) {
  state.tiles = {};
  state.annotations = [];
  state.waveformAnnotations = [];
  state.decoders = [];
  state.selectedDecoder = null;
  state.decodeView = {};
  view().userNavigated = false;
  state.gutterSig = "";
  applyStatus(data, false);
  await refreshDecoders();
  await loadAnnotations();
  const count = Number(data.sample_count || 0).toLocaleString();
  statusEl.textContent = `opened ${name} · ${count} samples`;
}

function dragHasFile(ev) {
  const types = ev.dataTransfer && ev.dataTransfer.types;
  return !!types && [...types].includes("Files");
}

function bindCaptureDrop() {
  const stage = document.querySelector(".wave-stage");
  stage.addEventListener("dragenter", (ev) => {
    if (!dragHasFile(ev)) return;
    ev.preventDefault();
    stage.classList.add("drop-capture");
  });
  stage.addEventListener("dragover", (ev) => {
    if (!dragHasFile(ev)) return;
    ev.preventDefault();
    ev.dataTransfer.dropEffect = "copy";
    stage.classList.add("drop-capture");
  });
  stage.addEventListener("dragleave", (ev) => {
    if (ev.relatedTarget && stage.contains(ev.relatedTarget)) return;
    stage.classList.remove("drop-capture");
  });
  stage.addEventListener("drop", (ev) => {
    if (!dragHasFile(ev)) return;
    ev.preventDefault();
    stage.classList.remove("drop-capture");
    const file = [...ev.dataTransfer.files].find((item) => isCaptureName(item.name));
    if (!file) {
      statusEl.textContent = "Drop a .lvcap or .dsl capture";
      return;
    }
    openCaptureFile(file);
  });
  window.addEventListener("dragover", (ev) => {
    if (dragHasFile(ev)) ev.preventDefault();
  });
  window.addEventListener("drop", (ev) => {
    if (!dragHasFile(ev)) return;
    ev.preventDefault();
    if (ev.target.closest && ev.target.closest(".wave-stage, #preferences-dialog, .export-location")) return;
    statusEl.textContent = "Drop the capture on the waveform";
  });
}

function connectSocket() {
  const proto = location.protocol === "https:" ? "wss" : "ws";
  socket = new WebSocket(`${proto}://${location.host}/ws`);
  socket.binaryType = "arraybuffer";
  socket.onmessage = (ev) => {
    if (typeof ev.data !== "string") {
      try { onTileFrame(parseFrame(ev.data)); } catch (_) { /* drop a short frame */ }
      return;
    }
    let msg;
    try { msg = JSON.parse(ev.data); } catch (_) { return; }
    if (msg.type === "appended" || msg.type === "phase" || msg.type === "stopped" || msg.type === "error") {
      onEngineEvent(msg);
    }
  };
  socket.onclose = () => {
    socket = null;
    setTimeout(connectSocket, 1000);
  };
}

function onEngineEvent(msg) {
  if (msg.session !== state.active) {
    refreshSessions();
    return;
  }
  if (msg.type === "error") {
    state.phase = "error";
    state.error = msg.message || "Capture failed";
    renderChrome();
    paintWait();
    return;
  }
  if (typeof msg.sample_count === "number") {
    applyStatus({
      phase: msg.phase || state.phase,
      sample_count: msg.sample_count,
      sample_rate_hz: state.rate,
      duration_ms: state.durationMs,
      channels: state.channels,
      analog: state.analog,
      trigger_sample: state.triggerSample,
      devices: state.devices,
    }, true);
  }
  if (msg.type === "stopped") {
    api({ cmd: "status", session: state.active }).then((status) => {
      if (msg.session === state.active) applyStatus(status, false);
    }).catch(() => {});
  }
}

function markerAt(x) {
  const v = view();
  let best = null;
  let bestDist = 8;
  for (const marker of v.markers) {
    const mx = (marker.sample - v.start) / v.spp;
    const dist = Math.abs(mx - x);
    if (dist <= bestDist) {
      best = marker;
      bestDist = dist;
    }
  }
  return best;
}

function placeMarker(sample, channel) {
  const marker = {
    id: state.nextMarker,
    n: state.nextMarker,
    sample,
    channel,
    name: "",
  };
  state.nextMarker += 1;
  view().markers.push(marker);
  renderMarkerList();
  drawWave();
  drawRuler();
  return marker;
}

async function snapMarker(marker, clientX, clientY) {
  if (preferences.edge_snap === false) return;
  const row = rowAt(clientY);
  const channel = row && row.kind === "logic" ? row.channel : (marker.channel ?? activeLogicChannel());
  try {
    const data = await api({
      cmd: "nearest_edge",
      session: state.active,
      channel,
      sample: marker.sample,
    });
    if (data.sample != null) {
      marker.sample = data.sample;
      marker.channel = channel;
      renderMarkerList();
      drawWave();
      drawRuler();
      statusEl.textContent = `marker snapped to sample ${data.sample}`;
    }
  } catch (err) {
    statusEl.textContent = err.message;
  }
}

wave.addEventListener("contextmenu", (ev) => {
  const row = state.total > 0 ? rowAt(ev.clientY) : null;
  if (row && row.kind === "logic") {
    ev.preventDefault();
    if (!ensureSelection().selection.includes(row.key)) selectOnly(row.key);
    openSignalMenu(row, ev.clientX, ev.clientY);
    return;
  }
  if (!row || !row.bus) return;
  if ((row.kind === "group" || row.kind === "bus") && !row.bus.decode) {
    ev.preventDefault();
    openContainerMenu(row.bus, ev.clientX, ev.clientY);
    return;
  }
  if (row.kind !== "bus" && row.kind !== "decode") return;
  ev.preventDefault();
  openBusMenu(row.bus, ev.clientX, ev.clientY);
});

wave.addEventListener("wheel", (ev) => {
  ev.preventDefault();
  if (state.total <= 0) return;
  if (!zoomAnchor) {
    const rect = wave.getBoundingClientRect();
    const x = ev.clientX - rect.left;
    const v = view();
    zoomAnchor = { x, sample: v.start + x * v.spp };
  }
  clearTimeout(zoomAnchorTimer);
  zoomAnchorTimer = setTimeout(() => {
    zoomAnchor = null;
  }, 300);
  if (ev.ctrlKey) zoomAt(zoomAnchor.sample, zoomAnchor.x, Math.exp(ev.deltaY * 0.01));
  else stepZoom(ev.deltaY > 0, zoomAnchor);
}, { passive: false });

function currentTimebaseIndex() {
  syncTimebaseLabel();
  const slider = document.getElementById("timebase");
  const index = slider ? Number(slider.value) : 0;
  if (!Number.isInteger(index) || index < 0 || index >= TIME_DIVS.length) return 0;
  return index;
}

function stepZoom(out, anchor) {
  const slider = document.getElementById("timebase");
  if (!slider || state.total <= 0) return;
  if (out && view().spp >= fitSpp() * (1 - 1e-9)) return;
  const current = currentTimebaseIndex();
  const next = Math.max(0, Math.min(TIME_DIVS.length - 1, current + (out ? 1 : -1)));
  if (next === current) return;
  slider.value = String(next);
  applyTimebase(next, anchor);
  drawWave();
}

function zoomAt(sample, x, factor) {
  const v = view();
  const width = Math.max(1, wave.clientWidth);
  const minSpp = TIME_DIVS[0] * Math.max(1, state.rate) / Math.max(40, width / 10);
  const maxSpp = state.total > 0 ? state.total / width : minSpp;
  const before = v.spp;
  v.spp = Math.min(maxSpp, Math.max(minSpp, before * factor));
  const start = sample - x * v.spp;
  if (v.spp === before && v.start === start) return;
  v.start = start;
  v.userNavigated = true;
  clampView();
  scheduleTiles();
  drawWave();
  drawRuler();
  drawOverview();
  syncTimebaseLabel();
}

wave.addEventListener("pointerdown", (ev) => {
  if (ev.pointerType === "touch") {
    if (state.total <= 0) return;
    touchPoints.set(ev.pointerId, { x: ev.clientX, y: ev.clientY });
    wave.setPointerCapture(ev.pointerId);
    if (touchPoints.size === 2) {
      const [a, b] = [...touchPoints.values()];
      const x = (a.x + b.x) / 2 - wave.getBoundingClientRect().left;
      pinch = { distance: Math.max(1, Math.hypot(a.x - b.x, a.y - b.y)), sample: view().start + x * view().spp };
    }
    return;
  }
  if (ev.button !== 0) return;
  if (state.total <= 0) return;
  const rect = wave.getBoundingClientRect();
  const x = ev.clientX - rect.left;
  const existing = markerAt(x);
  if (existing) {
    pointer = { kind: "marker", marker: existing, x: ev.clientX, moved: false, origin: existing.sample };
    wave.setPointerCapture(ev.pointerId);
    return;
  }
  if (state.tool === "marker") {
    const row = rowAt(ev.clientY);
    const channel = row && row.kind === "logic" ? row.channel : activeLogicChannel();
    const mode = document.getElementById("cursor-mode");
    if (mode && mode.value === "pair") {
      const sample = sampleAt(ev.clientX);
      pointer = { kind: "cursors", a: sample, b: sample, x: ev.clientX, channel };
      wave.setPointerCapture(ev.pointerId);
      return;
    }
    const marker = placeMarker(sampleAt(ev.clientX), channel);
    pointer = { kind: "marker", marker, x: ev.clientX, moved: false, fresh: true };
    wave.setPointerCapture(ev.pointerId);
    return;
  }
  if (state.tool === "measure") {
    const row = rowAt(ev.clientY);
    const sample = state.hoverSnap && row && state.hoverSnap.key === row.key
      ? state.hoverSnap.sample : sampleAt(ev.clientX);
    pointer = {
      kind: "measure",
      a: sample,
      b: sample,
      x: ev.clientX,
      channel: row && row.kind === "logic" ? row.channel : activeLogicChannel(),
      row,
    };
    wave.setPointerCapture(ev.pointerId);
    drawWave();
    return;
  }
  pointer = { kind: "pan", x: ev.clientX, start: view().start };
  hideHover();
  wave.setPointerCapture(ev.pointerId);
});

let viewPaintQueued = false;
function scheduleViewPaint() {
  if (viewPaintQueued) return;
  viewPaintQueued = true;
  requestAnimationFrame(() => {
    viewPaintQueued = false;
    drawWave();
    drawRuler();
    drawOverview();
  });
}

let measureSnapTimer = null;
let measureSnapSequence = 0;
function queueMeasureSnap(active, sample, ev) {
  const sequence = ++measureSnapSequence;
  clearTimeout(measureSnapTimer);
  if (preferences.edge_snap === false) { active.b = sample; return; }
  const position = { clientX: ev.clientX, clientY: ev.clientY };
  const session = state.active;
  measureSnapTimer = setTimeout(async () => {
    try {
      const result = await nearestRowEdge(active.row || { kind: "logic", channel: active.channel }, sample, session);
      if (pointer !== active || session !== state.active || sequence !== measureSnapSequence) return;
      active.b = typeof result.sample === "number" ? result.sample : sample;
      drawWave();
      const seconds = Math.abs(active.b - active.a) / Math.max(1, state.rate);
      showHover(position, `measurement ${formatSeconds(seconds)}`, `<b>Measurement</b><br>${formatSeconds(seconds)}<br>${Math.abs(active.b - active.a)} samples`);
    } catch (_) { /* Keep the last selected edge until a lookup succeeds. */ }
  }, 40);
}

wave.addEventListener("pointermove", (ev) => {
  if (ev.pointerType === "touch") {
    if (!touchPoints.has(ev.pointerId)) return;
    touchPoints.set(ev.pointerId, { x: ev.clientX, y: ev.clientY });
    if (pinch && touchPoints.size === 2) {
      const [a, b] = [...touchPoints.values()];
      const distance = Math.max(1, Math.hypot(a.x - b.x, a.y - b.y));
      const x = (a.x + b.x) / 2 - wave.getBoundingClientRect().left;
      zoomAt(pinch.sample, x, pinch.distance / distance);
      pinch.distance = distance;
    }
    return;
  }
  const rect = wave.getBoundingClientRect();
  state.hoverX = ev.clientX - rect.left;
  if (pointer && pointer.kind === "pan") {
    const v = view();
    v.start = pointer.start - (ev.clientX - pointer.x) * v.spp;
    v.userNavigated = true;
    clampView();
    scheduleWaveformAnnotations(true);
    const width = Math.max(1, Math.floor(wave.clientWidth || 1));
    if (!tileCoversView(state.tileView, v.start, v.spp, width) &&
        !(tileFlight && tileCoversView(state.pending, v.start, v.spp, width))) {
      tileAgain = true;
      if (!tileFlight) { tileFlight = true; runTiles(); }
    }
    scheduleViewPaint();
    return;
  }
  if (pointer && pointer.kind === "marker") {
    if (Math.abs(ev.clientX - pointer.x) > 3) pointer.moved = true;
    pointer.marker.sample = sampleAt(ev.clientX);
    drawWave();
    drawRuler();
    hideHover();
    return;
  }
  if (pointer && pointer.kind === "cursors") {
    pointer.b = sampleAt(ev.clientX);
    drawWave();
    hideHover();
    return;
  }
  if (pointer && pointer.kind === "measure") {
    if (ev.clientX < rect.left || ev.clientX >= rect.right || ev.clientY < rect.top || ev.clientY >= rect.bottom) {
      measureSnapSequence += 1;
      clearTimeout(measureSnapTimer);
      hideHover();
      return;
    }
    queueMeasureSnap(pointer, sampleAt(ev.clientX), ev);
    drawWave();
    const seconds = Math.abs(pointer.b - pointer.a) / Math.max(1, state.rate);
    showHover(ev, `measurement ${formatSeconds(seconds)}`, `<b>Measurement</b><br>${formatSeconds(seconds)}<br>${Math.abs(pointer.b - pointer.a)} samples`);
    return;
  }
  const hoveredRow = rowAt(ev.clientY);
  if (state.hoverSnap && (!hoveredRow || hoveredRow.key !== state.hoverSnap.key)) {
    state.hoverSnap = null;
  }
  placeEdgeButtons(ev.clientY);
  queueHover(ev);
  drawWave();
});

function endWaveTouch(ev) {
  touchPoints.delete(ev.pointerId);
  pinch = null;
}
wave.addEventListener("pointercancel", (ev) => {
  if (ev.pointerType === "touch") endWaveTouch(ev);
  else { pointer = null; measureSnapSequence += 1; clearTimeout(measureSnapTimer); }
});

wave.addEventListener("pointerup", async (ev) => {
  if (ev.pointerType === "touch") { endWaveTouch(ev); return; }
  const active = pointer;
  pointer = null;
  measureSnapSequence += 1;
  clearTimeout(measureSnapTimer);
  if (!active) return;
  if (active.kind === "measure") active.b = sampleAt(ev.clientX);
  if (active.kind === "cursors") {
    const channel = active.channel;
    if (Math.abs(active.b - active.a) < 2) placeMarker(active.a, channel);
    else {
      placeMarker(Math.min(active.a, active.b), channel);
      placeMarker(Math.max(active.a, active.b), channel);
    }
    drawWave();
    return;
  }
  if (active.kind === "marker" && active.moved && !active.fresh) {
    await snapMarker(active.marker, ev.clientX, ev.clientY);
  } else if (active.kind === "measure" && active.a !== active.b) {
    try {
      const session = state.active;
      const [a, b] = preferences.edge_snap === false ? [{}, {}] : await Promise.all([active.a, active.b].map((sample) =>
        nearestRowEdge(active.row || { kind: "logic", channel: active.channel }, sample, session)));
      if (session !== state.active) return;
      if (typeof a.sample === "number") active.a = a.sample;
      if (typeof b.sample === "number") active.b = b.sample;
    } catch (_) { /* Keep the selected samples if edge lookup fails. */ }
    const span = {
      id: state.nextMeasure,
      n: state.nextMeasure,
      a: Math.min(active.a, active.b),
      b: Math.max(active.a, active.b),
      channel: active.channel,
    };
    state.nextMeasure += 1;
    view().measures.push(span);
    renderMeasureList();
    try {
      await api({
        cmd: "save_measurement",
        session: state.active,
        channel: span.channel,
        sample: span.a,
      });
      refreshMeasurements();
    } catch (_) { /* the span is still on the waveform */ }
    drawWave();
  } else {
    drawWave();
  }
});

wave.addEventListener("pointerleave", () => {
  state.hoverX = null;
  state.hoverKey = null;
  hideHover();
  drawWave();
});

function overviewMetrics() {
  const rect = overview.getBoundingClientRect();
  const width = Math.max(1, rect.width);
  const v = view();
  const span = Math.max(1, wave.clientWidth * v.spp);
  const x0 = (v.start / state.total) * width;
  const x1 = Math.min(width, ((v.start + span) / state.total) * width);
  return { rect, width, span, x0, x1: Math.max(x0 + 2, x1) };
}

function scrollOverviewTo(start) {
  const v = view();
  v.start = start;
  v.userNavigated = true;
  clampView();
  scheduleTiles();
  drawWave();
  drawRuler();
  drawOverview();
}

let overviewDrag = null;

overview.addEventListener("pointerdown", (ev) => {
  if (ev.button !== 0 || state.total <= 0) return;
  const metrics = overviewMetrics();
  const x = ev.clientX - metrics.rect.left;
  if (x >= metrics.x0 && x <= metrics.x1) {
    overviewDrag = {
      pointer: ev.pointerId,
      grab: x - metrics.x0,
      thumb: metrics.x1 - metrics.x0,
    };
    overview.setPointerCapture(ev.pointerId);
    overview.classList.add("dragging");
    return;
  }
  const page = wave.clientWidth * view().spp;
  scrollOverviewTo(view().start + (x < metrics.x0 ? -page : page));
});

overview.addEventListener("pointermove", (ev) => {
  if (!overviewDrag || ev.pointerId !== overviewDrag.pointer) return;
  const rect = overview.getBoundingClientRect();
  const width = Math.max(1, rect.width);
  const x = ev.clientX - rect.left;
  let left = x - overviewDrag.grab;
  const maxLeft = Math.max(0, width - overviewDrag.thumb);
  if (left < 0) left = 0;
  if (left > maxLeft) left = maxLeft;
  scrollOverviewTo((left / width) * state.total);
});

function endOverviewDrag(ev) {
  if (!overviewDrag || ev.pointerId !== overviewDrag.pointer) return;
  overviewDrag = null;
  overview.classList.remove("dragging");
  if (overview.hasPointerCapture(ev.pointerId)) overview.releasePointerCapture(ev.pointerId);
}

overview.addEventListener("pointerup", endOverviewDrag);
overview.addEventListener("pointercancel", endOverviewDrag);

function queueHover(ev) {
  state.hoverSequence += 1;
  state.hoverEvent = { clientX: ev.clientX, clientY: ev.clientY };
  if (hoverTimer) return;
  hoverTimer = setTimeout(() => {
    hoverTimer = null;
    const current = state.hoverEvent;
    if (current) runHover(current, state.hoverSequence);
  }, 40);
}

async function nearestRowEdge(row, sample, session) {
  if (row.kind === "logic") return api({ cmd: "nearest_edge", session, channel: row.channel, sample });
  if (row.kind === "bus" && row.bus && !row.bus.decode) {
    const channels = [...new Set(descendantChannels(row.bus))];
    const edges = await Promise.all(channels.map((channel) => api({ cmd: "nearest_edge", session, channel, sample })));
    const hits = edges.map((edge) => edge.sample).filter((hit) => typeof hit === "number");
    return { sample: hits.length ? hits.reduce((best, hit) => Math.abs(hit - sample) < Math.abs(best - sample) ? hit : best) : null };
  }
  if (row.kind === "decode" || row.kind === "condense") {
    const decoder = (state.decoders || []).find((entry) => entry.id === row.decoderId);
    if (!decoder) return { sample: null };
    const spec = row.lane ? decoderLaneSpecs(decoder).find((item) => item.id === row.lane) : null;
    if (row.lane && !spec) return { sample: null };
    return api({ cmd: "nearest_annotation_boundary", session, decoder: row.decoderId, sample,
      classes: spec ? spec.classes : null, value_field: spec?.value_field || null });
  }
  return { sample: null };
}

// A decoder row represents annotation spans, not a single physical channel.
async function decodedHoverBounds(row, sample, session, sequence) {
  let offset = 0;
  let current = null;
  for (;;) {
    const page = await api({ cmd: "read_annotations", session, decoder: row.decoderId, start: sample, offset, limit: 5000 });
    if (sequence !== state.hoverSequence || session !== state.active || pointer) return null;
    for (const item of page) {
      const decoder = (state.decoders || []).find((entry) => entry.id === row.decoderId);
      if (decoder?.protocol === "rgb_led_ws281x" ? item.class !== "byte" : FRAME_CLASS.has(item.class)) continue;
      if (row.lane) {
        if (decoder ? !laneAnnotations([item], row.lane, decoder).length : !item.fields || item.fields[row.lane] == null) continue;
      }
      if (!current) {
        if (item.start_sample <= sample && sample < item.end_sample) current = item;
        else if (item.start_sample > sample) return null;
      } else if (item.start_sample >= current.end_sample) {
        return { start: current.start_sample, end: current.end_sample, next: item.start_sample };
      }
    }
    if (page.length < 5000) break;
    offset += page.length;
  }
  return current ? { start: current.start_sample, end: current.end_sample, next: null } : null;
}

async function busHoverBounds(row, sample, session) {
  const channels = [...new Set(descendantChannels(row.bus))];
  if (!channels.length) return null;
  const metrics = await Promise.all(channels.map((channel) => api({ cmd: "measure", session, channel, sample })));
  const starts = metrics.map((item) => item.pulse_start);
  const ends = metrics.map((item) => item.pulse_end);
  if (starts.some((value) => typeof value !== "number") || ends.some((value) => typeof value !== "number")) return null;
  const start = Math.max(...starts);
  const end = Math.min(...ends);
  return { start, end, next: end < state.total ? end : null };
}

async function runHover(ev, sequence) {
  const session = state.active;
  const rect = wave.getBoundingClientRect();
  const x = ev.clientX - rect.left;
  const y = ev.clientY - rect.top;
  const { layout } = rowMetrics();
  if (layout.length === 0 || state.total <= 0) {
    hideHover();
    return;
  }
  if (x >= traceEndX(rect.width)) {
    hideHover();
    return;
  }
  const row = rowAt(ev.clientY);
  if (!row || state.hidden.has(row.key)) {
    hideHover();
    return;
  }
  let sample = Math.min(state.total - 1, Math.max(0, Math.floor(view().start + x * view().spp)));
  state.hoverKey = row.key;
  if (row.kind === "analog") {
    state.hoverBounds = null;
    drawWave();
    const cols = state.tiles[row.key] || [];
    const column = cols[Math.floor(x)];
    if (!column || column.valid === false || pastCapture(Math.floor(x))) {
      hideHover();
      return;
    }
    const volts = (column.min + column.max) / 2;
    showHover(ev, `${row.name} · ${volts.toFixed(3)} V`, `<b style="color:${row.color}">${row.name}</b><br>${volts.toFixed(3)} V`);
    return;
  }
  try {
    const originalSample = sample;
    if (preferences.edge_snap !== false && ["logic", "bus", "decode", "condense"].includes(row.kind)) {
      const edge = await nearestRowEdge(row, sample, session);
      if (sequence !== state.hoverSequence || session !== state.active || pointer || preferences.edge_snap === false) return;
      state.hoverSnap = typeof edge.sample === "number" ? { key: row.key, sample: edge.sample } : null;
      if (state.hoverSnap) sample = state.hoverSnap.sample;
      drawWave();
    } else state.hoverSnap = null;
    if (row.kind === "decode" || row.kind === "condense" || row.kind === "bus") {
      let bounds = row.kind === "decode" || row.kind === "condense"
        ? await decodedHoverBounds(row, sample, session, sequence)
        : await busHoverBounds(row, sample, session);
      if (!bounds && (row.kind === "decode" || row.kind === "condense") && sample > 0 && sample !== originalSample) {
        bounds = await decodedHoverBounds(row, sample - 1, session, sequence);
      }
      if (sequence !== state.hoverSequence || session !== state.active || pointer) return;
      if (!bounds) {
        if (!state.hoverSnap) { hideHover(); return; }
        state.hoverBounds = null;
        state.hoverText = "";
        hoverEl.classList.add("hidden");
        paintStatus();
        drawWave();
        return;
      }
      const width = formatSeconds((bounds.end - bounds.start) / state.rate);
      const gap = bounds.next == null ? null : formatSeconds((bounds.next - bounds.end) / state.rate);
      state.lastMeasure = null;
      state.hoverBounds = { key: row.key, pulseStart: bounds.start, pulseEnd: bounds.end,
        periodStart: bounds.next == null ? null : bounds.end, periodEnd: bounds.next };
      drawWave();
      const line = `${row.name} ? width ${width}${gap == null ? "" : ` ? gap ${gap}`}`;
      const html = `<b style="color:${row.color}">${escapeHtml(row.name)}</b><br><span class="width-key">Width</span> ${width}${gap == null ? "" : `<br><span class="period-key">Gap</span> ${gap}`}`;
      showHover(ev, line, html);
      const readout = document.getElementById("measure-readout");
      if (readout) readout.textContent = line;
      return;
    }
    if (row.kind !== "logic") { hideHover(); return; }
    const metrics = await api({ cmd: "measure", session, channel: row.channel, sample });
    if (sequence !== state.hoverSequence || session !== state.active || pointer) return;
    state.hoverBounds = { key: row.key, pulseStart: metrics.pulse_start, pulseEnd: metrics.pulse_end, periodStart: metrics.period_start, periodEnd: metrics.period_end };
    drawWave();
    state.hoverChannel = row.channel;
    const level = metrics.level_high ? "high" : "low";
    const width = formatSeconds(metrics.width_secs);
    const period = metrics.period_secs == null ? "—" : formatSeconds(metrics.period_secs);
    const freq = formatHz(metrics.frequency_hz);
    const duty = metrics.duty == null ? "—" : `${(metrics.duty * 100).toFixed(1)}%`;
    state.lastMeasure = { channel: row.channel, sample };
    const line = `${row.name} ${level} · width ${width} · period ${period} · ${freq} · duty ${duty}`;
    const html = `<b style="color:${row.color}">${row.name}</b> <span class="muted">${level}</span><br><span class="width-key">Width</span> ${width}<br><span class="period-key">Period</span> ${period}<br>${freq} · duty ${duty}`;
    showHover(ev, line, html);
    const readout = document.getElementById("measure-readout");
    if (readout) readout.textContent = line;
  } catch (_) {
    if (sequence === state.hoverSequence) hideHover();
  }
}

function showHover(ev, line, html) {
  state.hoverText = line;
  paintStatus();
  hoverEl.innerHTML = html;
  hoverEl.classList.remove("hidden");
  const margin = 12;
  let left = ev.clientX + 16;
  let top = ev.clientY + 18;
  hoverEl.style.left = "0px";
  hoverEl.style.top = "0px";
  const box = hoverEl.getBoundingClientRect();
  if (left + box.width + margin > window.innerWidth) left = ev.clientX - box.width - 16;
  if (top + box.height + margin > window.innerHeight) top = Math.max(8, ev.clientY - box.height - 12);
  hoverEl.style.left = left + "px";
  hoverEl.style.top = top + "px";
}

function hideHover() {
  state.hoverSequence += 1;
  state.hoverEvent = null;
  if (hoverTimer) clearTimeout(hoverTimer);
  hoverTimer = null;
  const hadBounds = !!state.hoverBounds || !!state.hoverSnap;
  state.hoverBounds = null;
  state.hoverSnap = null;
  state.hoverText = "";
  hoverEl.classList.add("hidden");
  paintStatus();
  if (hadBounds) drawWave();
}

function setTool(name) {
  state.tool = state.tool === name ? null : name;
  document.getElementById("tool-marker").classList.toggle("active", state.tool === "marker");
  document.getElementById("tool-measure").classList.toggle("active", state.tool === "measure");
  wave.style.cursor = state.tool ? "crosshair" : "grab";
}

function syncTimebaseLabel() {
  const label = document.getElementById("timebase-label");
  const slider = document.getElementById("timebase");
  if (!label || !slider) return;
  slider.max = String(TIME_DIVS.length - 1);
  const px = Math.max(40, (wave.clientWidth || 800) / 10);
  const seconds = (view().spp * px) / Math.max(1, state.rate);
  let best = 0;
  let err = Infinity;
  TIME_DIVS.forEach((div, index) => {
    const delta = Math.abs(Math.log(div) - Math.log(Math.max(seconds, 1e-12)));
    if (delta < err) {
      err = delta;
      best = index;
    }
  });
  if (document.activeElement !== slider) slider.value = String(best);
  label.textContent = formatDiv(seconds);
}

function formatDiv(seconds) {
  return formatSeconds(seconds).replace(/\.000(?=\s)/, "") + "/div";
}

function applyTimebase(index, anchor) {
  if (!Number.isInteger(index) || index < 0 || index >= TIME_DIVS.length) return;
  const seconds = TIME_DIVS[index];
  const px = Math.max(40, (wave.clientWidth || 800) / 10);
  const v = view();
  const width = Math.max(1, wave.clientWidth);
  const sample = anchor ? anchor.sample : v.start + (width / 2) * v.spp;
  const x = anchor ? anchor.x : width / 2;
  const fit = state.total > 0 ? fitSpp() : v.spp;
  v.spp = Math.min(fit, (seconds * Math.max(1, state.rate)) / px);
  v.start = sample - x * v.spp;
  v.userNavigated = true;
  clampView();
  scheduleTiles();
  drawWave();
  drawRuler();
  drawOverview();
  syncTimebaseLabel();
}

function bindSplitters() {
  const side = document.getElementById("split-side");
  side.addEventListener("pointerdown", (ev) => {
    ev.preventDefault();
    const startX = ev.clientX;
    const start = parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--side")) || 300;
    side.classList.add("drag");
    const move = (e) => {
      const next = Math.max(220, Math.min(520, start - (e.clientX - startX)));
      document.documentElement.style.setProperty("--side", next + "px");
      scheduleTiles();
      drawRuler();
    };
    const up = () => {
      side.classList.remove("drag");
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", up);
      refreshOverview();
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", up);
  });
}

const MENUS = {
  file: [
    { label: "New Capture", shortcut: "Ctrl+N", run: () => addSession() },
    { label: "Load Capture", shortcut: "Ctrl+O", run: () => loadSavedCapture() },
    { label: "Save Capture As…", shortcut: "Ctrl+Shift+S", run: () => saveCaptureExport("lvcap") },
    { separator: true },
    { label: "Save setup…", run: () => saveSetup() },
    { label: "Open setup…", run: () => document.getElementById("setup-file").click() },
    { separator: true },
    { label: "Export Capture…", shortcut: "Ctrl+E", run: () => openExportDialog() },
    { label: "Import Capture…", shortcut: "Ctrl+I", run: () => importCapture() },
    { separator: true },
    { label: "Close LogicView", shortcut: "Alt+F4", run: () => closeLogicView() },
  ],
  edit: [["Clear markers", () => {
    view().markers = [];
    renderMarkerList();
    drawWave();
    drawRuler();
  }]],
  capture: [
    ["Run", () => runCapture()],
    ["Stop", () => stopCapture()],
  ],
  view: [
    ["Zoom in", () => stepZoom(false)],
    ["Zoom out", () => stepZoom(true)],
  ],
  decode: [],
  measure: [["Add measurement", () => setTool("measure")]],
  tools: [
    ["Previous edge", () => stepEdge(false)],
    ["Next edge", () => stepEdge(true)],
    ["Add marker", () => setTool("marker")],
    ["Create group…", () => openBusDialog()],
  ],
  help: [["About...", () => document.getElementById("about-dialog").showModal()]],
};

function closeMenu() {
  state.menu = null;
  document.getElementById("menu-pop").classList.add("hidden");
  for (const button of document.querySelectorAll(".menubar button")) button.classList.remove("open");
}

function openMenu(button) {
  closeRunMenu();
  const name = button.dataset.menu;
  if (state.menu === name) {
    closeMenu();
    return;
  }
  state.menu = name;
  const pop = document.getElementById("menu-pop");
  pop.replaceChildren();
  if (name === "decode") {
    const wrapper = document.createElement("div");
    wrapper.className = "decode-menu-sub";
    const add = document.createElement("button");
    add.type = "button";
    add.textContent = "Add new decoder";
    add.className = "decode-menu-trigger";
    add.setAttribute("aria-haspopup", "true");
    const submenu = document.createElement("div");
    submenu.className = "decode-menu-choices";
    const search = document.createElement("input");
    search.type = "search";
    search.className = "decode-menu-search";
    search.placeholder = "Search decoders";
    search.setAttribute("aria-label", "Search decoders");
    search.autocomplete = "off";
    search.spellcheck = false;
    const applyMenuFilter = () => {
      let visible = 0;
      for (const choice of submenu.querySelectorAll("button")) {
        const item = (state.decoderCatalog || []).find((row) => row.id === choice.dataset.id);
        const hide = !item || !decoderMatches(item, search.value);
        choice.classList.toggle("filtered-out", hide);
        if (!hide) visible += 1;
      }
      const empty = submenu.querySelector(".decoder-kind-empty");
      if (empty) empty.classList.toggle("filtered-out", visible > 0);
    };
    search.addEventListener("click", (ev) => ev.stopPropagation());
    search.addEventListener("input", applyMenuFilter);
    search.addEventListener("keydown", (ev) => {
      ev.stopPropagation();
      if (ev.key === "Escape") {
        ev.preventDefault();
        closeMenu();
      } else if (ev.key === "Enter") {
        ev.preventDefault();
        const choice = [...submenu.querySelectorAll("button")].find((button) => !button.classList.contains("filtered-out"));
        if (choice) choice.click();
      }
    });
    submenu.append(search);
    for (const item of state.decoderCatalog) {
      const choice = document.createElement("button");
      choice.type = "button";
      choice.dataset.id = item.id;
      const name = document.createElement("span");
      name.className = "decoder-kind-name";
      name.textContent = item.name || item.id;
      const id = document.createElement("span");
      id.className = "decoder-kind-id";
      id.textContent = item.id;
      choice.append(name, id);
      choice.addEventListener("click", () => { closeMenu(); addDecoder(item.id); });
      submenu.append(choice);
    }
    const empty = document.createElement("div");
    empty.className = "decoder-kind-empty filtered-out";
    empty.textContent = "No matching decoders";
    submenu.append(empty);
    add.addEventListener("click", () => wrapper.classList.toggle("open"));
    wrapper.append(add, submenu);
    pop.append(wrapper);
    const separator = document.createElement("div");
    separator.className = "menu-separator";
    pop.append(separator);
    for (const decoder of state.decoders.slice(0, 10)) {
      const item = document.createElement("button");
      item.type = "button";
      item.textContent = protocolLabel(decoder.protocol) + " (" + decoder.id + ")";
      item.addEventListener("click", () => { closeMenu(); state.selectedDecoder = decoder.id; selectTab("decode"); openDecodeConfig(decoder); });
      pop.append(item);
    }
  }
  for (const entry of MENUS[name]) {
    if (entry && entry.separator) {
      const separator = document.createElement("div");
      separator.className = "menu-separator";
      pop.append(separator);
      continue;
    }
    const label = Array.isArray(entry) ? entry[0] : entry.label;
    const run = Array.isArray(entry) ? entry[1] : entry.run;
    const shortcut = Array.isArray(entry) ? "" : entry.shortcut;
    const item = document.createElement("button");
    item.type = "button";
    const text = document.createElement("span");
    text.textContent = label;
    item.append(text);
    if (shortcut) {
      const key = document.createElement("span");
      key.className = "menu-key";
      key.textContent = shortcut;
      item.append(key);
    }
    item.addEventListener("click", () => {
      closeMenu();
      run();
    });
    pop.appendChild(item);
  }
  const rect = button.getBoundingClientRect();
  pop.classList.remove("hidden");
  placeViewportMenu(pop, rect.left, rect.bottom);
  for (const other of document.querySelectorAll(".menubar button")) {
    other.classList.toggle("open", other === button);
  }
}

document.getElementById("run").addEventListener("click", () => runCapture());
document.getElementById("run").addEventListener("contextmenu", (ev) => {
  ev.preventDefault();
  ev.stopPropagation();
  const menu = document.getElementById("run-menu");
  if (menu && !menu.classList.contains("hidden")) closeRunMenu();
  else openRunMenu();
});
document.getElementById("stop").addEventListener("click", () => stopCapture());
document.getElementById("wait-cancel").addEventListener("click", () => stopCapture());
document.getElementById("tab-add").addEventListener("click", () => addSession());
document.getElementById("device-select").addEventListener("click", (ev) => {
  ev.stopPropagation();
  openDeviceMenu(document.querySelector(".device-chip"));
});
document.querySelector(".device-chip").addEventListener("contextmenu", (ev) => {
  ev.preventDefault();
  ev.stopPropagation();
  openDeviceAcqMenu(ev.clientX, ev.clientY);
});
document.getElementById("tool-marker").addEventListener("click", () => setTool("marker"));
document.getElementById("tool-measure").addEventListener("click", () => setTool("measure"));
document.getElementById("zoom-in").addEventListener("click", () => stepZoom(false));
document.getElementById("zoom-out").addEventListener("click", () => stepZoom(true));
document.getElementById("trig-arm").addEventListener("click", () => {
  settings.trigger = !settings.trigger;
  const enable = document.getElementById("trig-enable");
  if (enable) enable.checked = settings.trigger;
  paintTriggerArm();
});
document.getElementById("trig-kind").addEventListener("click", () => {
  const next = TRIGGER_KINDS[(triggerKindIndex() + 1) % TRIGGER_KINDS.length];
  settings.triggerKind = next.id;
  syncTriggerToolbar();
});
document.getElementById("trig-channel").addEventListener("change", (ev) => {
  settings.triggerChannel = Number(ev.target.value);
  const panel = document.getElementById("panel-trig-channel");
  if (panel) panel.value = ev.target.value;
});
document.getElementById("trig-pre").addEventListener("change", (ev) => {
  settings.percent = Number(ev.target.value);
  const position = document.getElementById("set-position");
  const positionLabel = document.getElementById("set-position-label");
  if (position) position.value = String(settings.percent);
  if (positionLabel) positionLabel.textContent = `${settings.percent}%`;
});
document.getElementById("edge-prev").addEventListener("click", (ev) => {
  ev.stopPropagation();
  stepDataChange(false, state.edgeRow);
});
document.getElementById("edge-next").addEventListener("click", (ev) => {
  ev.stopPropagation();
  stepDataChange(true, state.edgeRow);
});
const waveStage = document.querySelector(".wave-stage");
let rowScrollLock = false;
function syncRowScroll(from, to) {
  if (!from || !to || rowScrollLock) return;
  rowScrollLock = true;
  to.scrollTop = from.scrollTop;
  rowScrollLock = false;
}
waveStage.addEventListener("scroll", () => {
  syncRowScroll(waveStage, gutter);
  if (state.edgePointerY != null) placeEdgeButtons(state.edgePointerY);
});
gutter.addEventListener("scroll", () => syncRowScroll(gutter, waveStage));
waveStage.addEventListener("pointerleave", (ev) => {
  if (ev.relatedTarget && waveStage.contains(ev.relatedTarget)) return;
  hideEdgeButtons();
});
document.getElementById("timebase").addEventListener("input", (ev) => applyTimebase(Number(ev.target.value)));

for (const button of document.querySelectorAll(".side-rail button[data-tab]")) {
  button.addEventListener("click", () => openSidebar(button.dataset.tab));
}
const sidePanel = document.getElementById("side-panel");
const sidePin = document.getElementById("side-pin");
sidePin.addEventListener("click", () => {
  const pinned = sidePanel.classList.toggle("pinned");
  sidePin.classList.toggle("pinned", pinned);
  sidePin.setAttribute("aria-pressed", pinned ? "true" : "false");
  if (pinned) sidePanel.classList.add("open");
});
sidePanel.addEventListener("pointerleave", (ev) => {
  if (sidePanel.classList.contains("pinned")) return;
  if (ev.relatedTarget && sidePanel.contains(ev.relatedTarget)) return;
  const menu = document.getElementById("device-menu");
  if (menu && !menu.classList.contains("hidden")) return;
  sidePanel.classList.remove("open");
});
for (const button of document.querySelectorAll(".menubar button")) {
  button.addEventListener("click", (ev) => {
    ev.stopPropagation();
    openMenu(button);
  });
  button.addEventListener("mouseenter", () => {
    if (state.menu && state.menu !== button.dataset.menu) openMenu(button);
  });
}
sideBody.addEventListener("scroll", () => placeDecoderPicker());
window.addEventListener("resize", () => placeDecoderPicker());
document.addEventListener("click", (ev) => {
  if (!ev.target.closest("#decoder-kind-picker")) closeDecoderPicker();
  if (!ev.target.closest(".menu-pop") && !ev.target.closest(".menubar")) closeMenu();
  if (!ev.target.closest("#device-menu") && !ev.target.closest("#device-select") && !ev.target.closest("#device-card")) {
    closeDeviceMenu();
  }
  if (!ev.target.closest("#device-acq-menu")) closeDeviceAcqMenu();
  if (!ev.target.closest("#bus-menu")) closeBusMenu();
  if (!ev.target.closest("#run-menu") && !ev.target.closest("#run")) closeRunMenu();
});

// Run before other controls can stop the click from reaching document.
document.addEventListener("click", (ev) => {
  if (!ev.target.closest("#color-flyout") && !ev.target.closest(".ch .bar")) closeColorFlyout();
}, true);

let menuDismissTimer = 0;
let menuDismissGroup = "";

function menuGroup(node) {
  if (!node || !node.closest) return "";
  if (node.closest("#menu-pop") || node.closest(".menubar")) return "bar";
  if (node.closest("#device-menu") || node.closest(".device-chip") || node.closest("#device-card")) return "device";
  if (node.closest("#device-acq-menu")) return "acq";
  if (node.closest("#decoder-kind-menu") || node.closest("#decoder-kind-picker")) return "decode";
  if (node.closest("#bus-menu")) return "bus";
  if (node.closest("#run-menu") || node.closest("#run")) return "run";
  return "";
}

function groupIsOpen(group) {
  if (group === "bar") return !!state.menu;
  const id = {
    device: "device-menu",
    acq: "device-acq-menu",
    decode: "decoder-kind-menu",
    bus: "bus-menu",
    run: "run-menu",
  }[group];
  const el = id && document.getElementById(id);
  return !!(el && !el.classList.contains("hidden"));
}

function dismissMenuGroup(group) {
  if (group === "bar") closeMenu();
  else if (group === "device") closeDeviceMenu();
  else if (group === "acq") closeDeviceAcqMenu();
  else if (group === "decode") closeDecoderPicker();
  else if (group === "bus") closeBusMenu();
  else if (group === "run") closeRunMenu();
}

function scheduleMenuDismiss(group) {
  clearTimeout(menuDismissTimer);
  menuDismissGroup = group;
  menuDismissTimer = setTimeout(() => {
    if (menuDismissGroup !== group) return;
    menuDismissGroup = "";
    dismissMenuGroup(group);
  }, 180);
}

document.addEventListener("mouseout", (ev) => {
  const group = menuGroup(ev.target);
  if (!group || !groupIsOpen(group)) return;
  if (menuGroup(ev.relatedTarget) === group) return;
  scheduleMenuDismiss(group);
});
document.addEventListener("mouseover", (ev) => {
  if (menuGroup(ev.target) !== menuDismissGroup) return;
  clearTimeout(menuDismissTimer);
  menuDismissGroup = "";
});

document.getElementById("about-close").addEventListener("click", () => document.getElementById("about-dialog").close());

function menuChord(ev) {
  if (ev.altKey && ev.key === "F4") return null;
  if (!(ev.ctrlKey || ev.metaKey || ev.altKey)) return null;
  const parts = [];
  if (ev.ctrlKey || ev.metaKey) parts.push("Ctrl");
  if (ev.shiftKey) parts.push("Shift");
  if (ev.altKey) parts.push("Alt");
  const key = ev.key.length === 1 ? ev.key.toUpperCase() : ev.key;
  if (key === "Control" || key === "Shift" || key === "Alt" || key === "Meta") return null;
  parts.push(key);
  return parts.join("+");
}

function runMenuShortcut(chord) {
  for (const entries of Object.values(MENUS)) {
    for (const entry of entries) {
      if (!entry || Array.isArray(entry) || entry.shortcut !== chord || typeof entry.run !== "function") continue;
      entry.run();
      return true;
    }
  }
  return false;
}

window.addEventListener("keydown", (ev) => {
  if (document.getElementById("close-capture-dialog").open || document.getElementById("about-dialog").open || document.getElementById("preferences-dialog").open || document.getElementById("export-dialog").open) return;
  if (ev.target.matches("input, select, textarea")) return;
  const chord = menuChord(ev);
  if (chord && runMenuShortcut(chord)) {
    ev.preventDefault();
    return;
  }
  if (ev.ctrlKey || ev.metaKey || ev.altKey) return;
  const key = ev.key;
  if (key === " " || key === "s" || key === "S") {
    ev.preventDefault();
    if (ev.repeat) return;
    if (isLive(state.phase)) stopCapture();
    else runCapture();
    return;
  }
  if (key === "o" || key === "O") { selectTab("device"); return; }
  if (key === "t" || key === "T") { selectTab("triggers"); return; }
  if (key === "d" || key === "D") { selectTab("decode"); return; }
  if (key === "m" || key === "M") { selectTab("measure"); return; }
  if (key === "r" || key === "R") {
    ev.preventDefault();
    const search = document.getElementById("decode-search");
    if (search) search.focus();
    return;
  }
  if (key === "Escape") {
    const pickerMenu = document.getElementById("decoder-kind-menu");
    if (pickerMenu && !pickerMenu.classList.contains("hidden")) {
      closeDecoderPicker();
      return;
    }
    const save = document.getElementById("save-dialog");
    const fly = document.getElementById("color-flyout");
    if (save && !save.classList.contains("hidden")) closeSaveDialog();
    else if (fly && !fly.classList.contains("hidden")) closeColorFlyout();
    else if (state.menu) closeMenu();
    else if (!document.getElementById("run-menu").classList.contains("hidden")) closeRunMenu();
    else if (state.tool) setTool(state.tool);
    return;
  }
  if (key === "[" ) { stepEdge(false); return; }
  if (key === "]") { stepEdge(true); return; }
  if (key === "PageDown" || key === "PageUp") {
    ev.preventDefault();
    const v = view();
    const dir = key === "PageDown" ? 1 : -1;
    v.start += dir * wave.clientWidth * v.spp * 0.8;
    v.userNavigated = true;
    clampView();
    scheduleTiles();
    drawOverview();
  }
});

window.addEventListener("resize", () => {
  if (!view().userNavigated) fitView();
  scheduleTiles();
  drawRuler();
  refreshOverview();
});

setInterval(refreshDeviceList, 2000);

setInterval(async () => {
  if (!isLive(state.phase) || !state.active) return;
  try {
    const status = await api({ cmd: "status", session: state.active });
    applyStatus(status, true);
  } catch (_) { /* the next tick retries */ }
}, 250);

bindSplitters();

function niceStep(span, px) {
  const target = span / Math.max(1, px / 140);
  if (!(target > 0) || !isFinite(target)) return null;
  const pow = 10 ** Math.floor(Math.log10(target));
  const err = target / pow;
  const nice = err >= 5 ? 5 : err >= 2 ? 2 : 1;
  return nice * pow;
}

function formatRulerTick(seconds, step) {
  const sign = seconds < 0 ? "-" : "";
  const magnitude = Math.abs(seconds);
  const basis = step > 0 && isFinite(step) ? step : magnitude || 1;
  let scale = 1e12;
  let unit = "ps";
  if (basis >= 1) {
    scale = 1;
    unit = "s";
  } else if (basis >= 1e-3) {
    scale = 1e3;
    unit = "ms";
  } else if (basis >= 1e-6) {
    scale = 1e6;
    unit = "µs";
  } else if (basis >= 1e-9) {
    scale = 1e9;
    unit = "ns";
  }
  const quantum = basis * scale;
  const snapped = Math.round((magnitude * scale) / quantum) * quantum;
  const decimals = quantum >= 100 ? 0 : quantum >= 10 ? 1 : quantum >= 1 ? 2 : 3;
  let text = snapped.toFixed(decimals).replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "");
  if (!text || text === "-0") text = "0";
  return `${sign}${text} ${unit}`;
}

function formatSeconds(seconds) {
  if (seconds == null || !isFinite(seconds)) return "—";
  const sign = seconds < 0 ? "-" : "";
  const a = Math.abs(seconds);
  if (a >= 1) return sign + a.toFixed(3) + " s";
  if (a >= 1e-3) return sign + (a * 1e3).toFixed(3) + " ms";
  if (a >= 1e-6) return sign + (a * 1e6).toFixed(3) + " µs";
  if (a >= 1e-9 || a === 0) return sign + (a * 1e9).toFixed(1) + " ns";
  return sign + (a * 1e12).toFixed(1) + " ps";
}

function formatHz(hz) {
  if (hz == null || !isFinite(hz)) return "—";
  if (hz >= 1e6) return (hz / 1e6).toFixed(3) + " MHz";
  if (hz >= 1e3) return (hz / 1e3).toFixed(3) + " kHz";
  return hz.toFixed(2) + " Hz";
}

function openSidebar(name) {
  document.getElementById("side-panel").classList.add("open");
  selectTab(name);
}

let triggeredTimer = null;

function paintWait() {
  const dialog = document.getElementById("capture-wait");
  const text = document.getElementById("wait-text");
  const arc = document.getElementById("wait-arc");
  if (!dialog || !text || !arc) return;
  const buffer = settings.depth !== "stream";
  const waiting = state.phase === "waiting_trigger";
  const sampling = buffer && (state.phase === "running" || state.phase === "arming") && state.planned > 0 && state.total < state.planned;
  if (state.waitKind === "waiting" && state.phase === "running") {
    showTriggered();
    return;
  }
  if (waiting) {
    state.waitKind = "waiting";
    dialog.className = "wait-dialog waiting";
    text.textContent = "Waiting for trigger";
    return;
  }
  if (sampling) {
    state.waitKind = "sampling";
    dialog.className = "wait-dialog sampling";
    text.textContent = state.phase === "arming" ? "Acquiring" : "Reading samples";
    const circ = 2 * Math.PI * 46;
    const frac = Math.max(0, Math.min(1, state.total / state.planned));
    arc.style.strokeDasharray = String(circ);
    arc.style.strokeDashoffset = String(circ * (1 - frac));
    return;
  }
  if (state.waitKind === "triggered") return;
  state.waitKind = "";
  dialog.className = "wait-dialog hidden";
}

function showTriggered() {
  const dialog = document.getElementById("capture-wait");
  const text = document.getElementById("wait-text");
  state.waitKind = "triggered";
  dialog.className = "wait-dialog triggered";
  text.textContent = "Triggered";
  clearTimeout(triggeredTimer);
  triggeredTimer = setTimeout(() => {
    if (state.waitKind !== "triggered") return;
    state.waitKind = "";
    dialog.className = "wait-dialog hidden";
    paintWait();
  }, 700);
}

let editingGroupId = null;

function displayedContainerName(container) {
  const names = view().names;
  const key = "bus:" + container.id;
  return (names && names[key]) || container.name || ("Group " + container.id);
}

function groupMemberLabel(member) {
  if (member.kind === "group") {
    const child = sessionContainers().find((item) => Number(item.id) === Number(member.id));
    return child ? displayedContainerName(child) : ("Group " + member.id);
  }
  const channel = state.channels.find((item) => item.index === Number(member.index));
  return channel ? channel.name : ("Channel " + member.index);
}

function setGroupDialogMode(editing) {
  const dialog = document.getElementById("bus-dialog");
  const title = document.getElementById("bus-dialog-title");
  const submit = document.getElementById("bus-submit");
  if (dialog) dialog.setAttribute("aria-label", editing ? "Edit a group" : "Create a group");
  if (title) title.textContent = editing ? "Edit group" : "Create group";
  if (submit) submit.textContent = editing ? "Apply" : "Create";
}

function paintGroupMembers(members, leaves) {
  const host = document.getElementById("bus-channels");
  host.replaceChildren();
  host.dataset.leaves = String(leaves);
  for (const member of members) {
    const line = document.createElement("div");
    line.className = "channel-line";
    line.textContent = groupMemberLabel(member);
    host.appendChild(line);
  }
}

function syncGroupDialog() {
  const type = document.querySelector('input[name="group-type"]:checked');
  const bus = !type || type.value === "bus";
  document.getElementById("bus-radix").classList.toggle("hidden", !bus);
  document.getElementById("bus-msb").classList.toggle("hidden", !bus);
  document.getElementById("group-label-note").classList.toggle("hidden", bus);
  const host = document.getElementById("bus-channels");
  const stored = Number(host && host.dataset.leaves);
  const count = Number.isFinite(stored) ? stored : document.querySelectorAll("#bus-channels .channel-line").length;
  const hint = document.getElementById("bus-hint");
  const submit = document.getElementById("bus-submit");
  const msb = document.getElementById("bus-msb-first");
  if (bus && count < 2) hint.textContent = "A bus needs at least two channels";
  else if (!count) hint.textContent = "Select a logic channel";
  else if (bus) hint.textContent = msb && msb.checked ? "Top channel is the high bit" : "Top channel is the low bit";
  else hint.textContent = "";
  if (submit) submit.disabled = (bus && count < 2) || !count;
  const name = document.getElementById("bus-name");
  if (editingGroupId == null && /^(Bus|Group) \d+$/.test(name.value)) {
    name.value = (bus ? "Bus " : "Group ") + name.value.split(" ")[1];
  }
}

function openBusDialog() {
  const members = selectedGroupMembers();
  if (!members.length) {
    statusEl.textContent = "Select logic channels, then create a group";
    return;
  }
  editingGroupId = null;
  const leaves = memberLeafChannels(members);
  paintGroupMembers(members, leaves.length);
  const type = leaves.length >= 2 ? "bus" : "group";
  const radio = document.querySelector(`input[name="group-type"][value="${type}"]`);
  if (radio) radio.checked = true;
  const hex = document.querySelector('input[name="bus-radix"][value="hex"]');
  if (hex) hex.checked = true;
  const msb = document.getElementById("bus-msb-first");
  if (msb) msb.checked = true;
  const name = document.getElementById("bus-name");
  name.value = (type === "group" ? "Group " : "Bus ") + (view().nextBus || 1);
  setGroupDialogMode(false);
  syncGroupDialog();
  document.getElementById("bus-dialog").classList.remove("hidden");
}

function openEditGroup(bus) {
  if (!bus || bus.decode) return;
  editingGroupId = Number(bus.id);
  const members = (bus.members || []).map((member) => (
    member.kind === "group"
      ? { kind: "group", id: Number(member.id) }
      : { kind: "channel", index: Number(member.index) }
  ));
  paintGroupMembers(members, descendantChannels(bus).length);
  const type = bus.type === "group" ? "group" : "bus";
  const radio = document.querySelector(`input[name="group-type"][value="${type}"]`);
  if (radio) radio.checked = true;
  const radix = bus.radix && bus.radix !== "analog" ? bus.radix : "hex";
  const radixRadio = document.querySelector(`input[name="bus-radix"][value="${radix}"]`);
  if (radixRadio) radixRadio.checked = true;
  const msb = document.getElementById("bus-msb-first");
  if (msb) msb.checked = !!bus.msbFirst;
  document.getElementById("bus-name").value = displayedContainerName(bus);
  setGroupDialogMode(true);
  syncGroupDialog();
  document.getElementById("bus-dialog").classList.remove("hidden");
}

function closeBusDialog() {
  editingGroupId = null;
  document.getElementById("bus-dialog").classList.add("hidden");
}

function closeBusMenu() {
  const menu = document.getElementById("bus-menu");
  if (menu) menu.classList.add("hidden");
}

function placeBusMenu(menu, x, y) {
  menu.classList.remove("hidden");
  placeViewportMenu(menu, x, y);
}

function openBusMenu(bus, x, y) {
  const menu = document.getElementById("bus-menu");
  menu.replaceChildren();
  const item = document.createElement("button");
  item.type = "button";
  item.textContent = bus.analog ? "Hex view" : "Analog view";
  item.addEventListener("click", () => {
    const analog = !bus.analog;
    if (!state.spiView[bus.decode]) state.spiView[bus.decode] = { analog: false };
    state.spiView[bus.decode].analog = analog;
    const pref = decodePref(bus.decode);
    if (analog) pref.format = "analog";
    else if (pref.format === "analog") pref.format = "hex";
    state.gutterSig = "";
    closeBusMenu();
    renderGutter();
    drawWave();
    refreshOverview();
  });
  menu.append(item);
  placeBusMenu(menu, x, y);
}

function openCreateGroupMenu(x, y) {
  const menu = document.getElementById("bus-menu");
  menu.replaceChildren();
  const item = document.createElement("button");
  item.type = "button";
  item.textContent = "Create group…";
  item.addEventListener("click", () => {
    closeBusMenu();
    openBusDialog();
  });
  menu.append(item);
  placeBusMenu(menu, x, y);
}

function canUngroupSignal(row) {
  if (!plainLogic(row) || row.containerId == null) return false;
  const container = sessionContainers().find((item) => Number(item.id) === Number(row.containerId));
  return !!(container && !container.decode);
}

function ungroupSignal(row) {
  if (!canUngroupSignal(row)) return;
  const container = sessionContainers().find((item) => Number(item.id) === Number(row.containerId));
  const index = Number(row.channel);
  const at = (container.members || []).findIndex((member) => member.kind === "channel" && Number(member.index) === index);
  if (at < 0) return;
  container.members.splice(at, 1);
  container.channels = container.members.filter((member) => member.kind === "channel").map((member) => Number(member.index));
  const parent = parentContainer(container.id);
  if (parent) {
    const groupAt = parent.members.findIndex((member) => member.kind === "group" && Number(member.id) === Number(container.id));
    parent.members.splice(groupAt < 0 ? parent.members.length : groupAt + 1, 0, { kind: "channel", index });
    parent.channels = parent.members.filter((member) => member.kind === "channel").map((member) => Number(member.index));
  } else {
    const key = "logic:" + index;
    const order = view().order && view().order.length ? [...view().order] : sourceRows().map((item) => item.key);
    const without = order.filter((item) => item !== key);
    const groupAt = without.indexOf("bus:" + container.id);
    if (groupAt >= 0) without.splice(groupAt + 1, 0, key);
    else without.unshift(key);
    persistOrder(without);
  }
  deleteEmptyContainers();
  state.gutterSig = "";
  renderGutter();
  drawWave();
  scheduleTiles();
}

function openSignalMenu(row, x, y) {
  const menu = document.getElementById("bus-menu");
  menu.replaceChildren();
  if (row.kind === "logic") {
    const analog = signalMode(row.key) === "analog";
    const mode = document.createElement("button");
    mode.type = "button";
    mode.textContent = analog ? "Digital view" : "Analog view";
    mode.addEventListener("click", () => {
      setSignalMode(row.key, analog ? "digital" : "analog");
      state.gutterSig = "";
      closeBusMenu();
      renderGutter();
      drawWave();
      refreshOverview();
    });
    menu.append(mode);
    const add = document.createElement("button");
    add.type = "button";
    add.textContent = "Add decoder…";
    add.addEventListener("click", () => { closeBusMenu(); openSignalDecoderDialog(row); });
    menu.append(add);
  }
  if (canUngroupSignal(row)) {
    const item = document.createElement("button");
    item.type = "button";
    item.textContent = "Ungroup";
    item.addEventListener("click", () => {
      ungroupSignal(row);
      closeBusMenu();
    });
    menu.append(item);
  }
  if (selectedGroupMembers().length) {
    const item = document.createElement("button");
    item.type = "button";
    item.textContent = "Create group…";
    item.addEventListener("click", () => {
      closeBusMenu();
      openBusDialog();
    });
    menu.append(item);
  }
  if (!menu.childElementCount) return;
  placeBusMenu(menu, x, y);
}

function openSignalDecoderDialog(row) {
  const dialog = document.getElementById("signal-decoder-dialog");
  const list = document.getElementById("signal-decoder-list");
  const search = document.getElementById("signal-decoder-search");
  list.replaceChildren();
  search.value = "";
  const choices = (state.decoderCatalog || []).filter((item) => !item.stack_on && [...(item.channels || []), ...(item.optional_channels || [])].length);
  for (const schema of choices) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = schema.name || schema.id;
    button.addEventListener("click", () => { closeSignalDecoderDialog(); addDecoder(schema.id, row.channel); });
    list.append(button);
  }
  search.oninput = () => {
    [...list.querySelectorAll("button")].forEach((button, index) => { button.hidden = !decoderMatches(choices[index], search.value); });
  };
  dialog.classList.remove("hidden");
  search.focus();
}

function closeSignalDecoderDialog() {
  document.getElementById("signal-decoder-dialog").classList.add("hidden");
}

function openContainerMenu(bus, x, y) {
  const menu = document.getElementById("bus-menu");
  menu.replaceChildren();
  if (bus.type !== "group") {
    const analogOn = !!(bus.analog || bus.radix === "analog");
    for (const [value, label] of [["hex", "Hex"], ["dec", "Decimal"], ["bin", "Binary"], ["oct", "Octal"], ["analog", "Analog"]]) {
      const item = document.createElement("button");
      item.type = "button";
      const checked = value === "analog" ? analogOn : (!analogOn && bus.radix === value);
      item.textContent = (checked ? "✓ " : "") + label;
      item.addEventListener("click", () => {
        if (value === "analog") {
          bus.analog = true;
          bus.radix = "analog";
        } else {
          bus.radix = value;
          bus.analog = false;
        }
        state.gutterSig = "";
        closeBusMenu();
        renderGutter();
        drawWave();
        refreshOverview();
      });
      menu.append(item);
    }
    const msb = document.createElement("button");
    msb.type = "button";
    msb.textContent = (bus.msbFirst ? "✓ " : "") + "MSB first";
    msb.addEventListener("click", () => {
      bus.msbFirst = !bus.msbFirst;
      closeBusMenu();
      drawWave();
      refreshOverview();
    });
    menu.append(msb);
  }
  const edit = document.createElement("button");
  edit.type = "button";
  edit.textContent = "Edit Group";
  edit.addEventListener("click", () => {
    closeBusMenu();
    openEditGroup(bus);
  });
  menu.append(edit);
  const remove = document.createElement("button");
  remove.type = "button";
  remove.textContent = bus.type === "group" ? "Ungroup" : "Remove bus";
  remove.addEventListener("click", () => {
    removeContainer(bus.id);
    closeBusMenu();
  });
  menu.append(remove);
  placeBusMenu(menu, x, y);
}

function deleteEmptyContainers() {
  let guard = view().buses.length + 1;
  while (guard-- > 0) {
    const empty = new Set(view().buses.filter((container) => !(container.members || []).length).map((container) => Number(container.id)));
    if (!empty.size) return;
    for (const container of view().buses) {
      container.members = (container.members || []).filter((member) => !(member.kind === "group" && empty.has(Number(member.id))));
      container.channels = container.members.filter((member) => member.kind === "channel").map((member) => Number(member.index));
    }
    view().buses = view().buses.filter((container) => !empty.has(Number(container.id)));
  }
}

function placeTopLevelOrder(container, anchorKey, removedKeys, orderSnapshot) {
  const key = "bus:" + container.id;
  const order = orderSnapshot && orderSnapshot.length ? [...orderSnapshot] : sourceRows().map((row) => row.key);
  const drop = new Set(removedKeys || []);
  drop.add(key);
  const anchorAt = anchorKey ? order.indexOf(anchorKey) : -1;
  const next = order.filter((item) => !drop.has(item));
  const insertAt = anchorAt < 0 ? 0 : order.slice(0, anchorAt).filter((item) => !drop.has(item)).length;
  next.splice(Math.max(0, Math.min(insertAt, next.length)), 0, key);
  persistOrder(next);
}

function removeContainer(id) {
  const container = sessionContainers().find((item) => Number(item.id) === Number(id));
  if (!container) return;
  const parent = parentContainer(id);
  const members = container.members || [];
  if (parent) {
    const at = parent.members.findIndex((member) => member.kind === "group" && Number(member.id) === Number(id));
    const rest = parent.members.filter((_, index) => index !== at);
    const insert = at < 0 ? rest.length : at;
    parent.members = [...rest.slice(0, insert), ...members, ...rest.slice(insert)];
    parent.channels = parent.members.filter((member) => member.kind === "channel").map((member) => Number(member.index));
  } else {
    const order = view().order ? [...view().order] : [];
    const at = order.indexOf("bus:" + id);
    const childKeys = members.filter((member) => member.kind === "group").map((member) => "bus:" + member.id);
    if (at >= 0) order.splice(at, 1, ...childKeys);
    else order.push(...childKeys);
    if (order.length) persistOrder(order.filter((key) => key !== "bus:" + id));
  }
  view().buses = view().buses.filter((item) => Number(item.id) !== Number(id));
  state.gutterSig = "";
  renderGutter();
  drawWave();
  scheduleTiles();
}

function createChannelGroup(type, name, radix, msbFirst) {
  const picked = selectedGroupMembers();
  const leaves = memberLeafChannels(picked);
  if (type === "bus" && leaves.length < 2) {
    statusEl.textContent = "A bus needs at least two channels";
    return false;
  }
  if (!picked.length || !leaves.length) {
    statusEl.textContent = "Select a logic channel";
    return false;
  }
  const v = view();
  const used = sessionContainers().reduce((max, container) => Math.max(max, Number(container.id) || 0), 0);
  const id = Math.max(v.nextBus || 1, used + 1);
  v.nextBus = id + 1;
  const container = {
    id,
    name,
    type,
    members: picked.map((member) => (
      member.kind === "group"
        ? { kind: "group", id: Number(member.id) }
        : { kind: "channel", index: Number(member.index) }
    )),
    channels: picked.filter((member) => member.kind === "channel").map((member) => Number(member.index)),
    radix: type === "bus" ? radix : "hex",
    msbFirst: type === "bus" ? !!msbFirst : false,
    folded: false,
    analog: false,
  };
  const parents = picked.map((member) => memberCurrentParent(member));
  const firstParent = parents[0] || null;
  const shared = parents.every((parent) => (
    !parent && !firstParent ? true : !!(parent && firstParent && Number(parent.id) === Number(firstParent.id))
  ));
  if (shared && firstParent) {
    let first = firstParent.members.findIndex((member) => picked.some((item) => memberMatches(member, item)));
    if (first < 0) first = firstParent.members.length;
    firstParent.members = firstParent.members.filter((member) => !picked.some((item) => memberMatches(member, item)));
    firstParent.members.splice(first, 0, { kind: "group", id });
    firstParent.channels = firstParent.members.filter((member) => member.kind === "channel").map((member) => Number(member.index));
    for (const member of picked) {
      if (member.kind === "group") forgetTopLevelKey("bus:" + member.id);
    }
    v.buses.push(container);
  } else {
    const anchorKey = picked[0].kind === "group" ? ("bus:" + picked[0].id) : ("logic:" + picked[0].index);
    const snapshot = v.order && v.order.length ? [...v.order] : sourceRows().map((row) => row.key);
    for (const member of picked) {
      if (member.kind === "channel") detachChannel(member.index);
      else detachGroupMember(member.id);
    }
    v.buses.push(container);
    deleteEmptyContainers();
    const removed = picked.filter((member) => member.kind === "group").map((member) => "bus:" + member.id);
    placeTopLevelOrder(container, anchorKey, removed, snapshot);
  }
  state.gutterSig = "";
  renderGutter();
  drawWave();
  scheduleTiles();
  return true;
}

function applyGroupEdits(id, type, name, radix, msbFirst) {
  const container = sessionContainers().find((item) => Number(item.id) === Number(id));
  if (!container) return false;
  const leaves = descendantChannels(container).length;
  if (type === "bus" && leaves < 2) {
    statusEl.textContent = "A bus needs at least two channels";
    return false;
  }
  if (!leaves) {
    statusEl.textContent = "Select a logic channel";
    return false;
  }
  container.name = name;
  container.type = type === "group" ? "group" : "bus";
  container.radix = container.type === "bus" ? radix : "hex";
  container.msbFirst = container.type === "bus" ? !!msbFirst : false;
  container.analog = false;
  if (view().names) delete view().names["bus:" + container.id];
  state.gutterSig = "";
  renderGutter();
  drawWave();
  scheduleTiles();
  return true;
}

function channelSpec(channel) {
  return channel.device_id ? channel.device_id + "/" + channel.name : channel.name;
}

function channelOptions(selectedIndex) {
  return `<option value=""${selectedIndex == null ? " selected" : ""}>NC</option>` + state.channels.map((channel) => {
    const label = channel.device_name ? channel.device_name + " / " + channel.name : channel.name;
    const selected = channel.index === selectedIndex ? " selected" : "";
    return `<option value="${escapeHtml(channelSpec(channel))}"${selected}>${escapeHtml(label)}</option>`;
  }).join("");
}

function signalField(name, index) {
  return `<label class="field">${name.toUpperCase()}
    <select data-signal="${name}">${channelOptions(index)}</select>
  </label>`;
}

function openDecodeConfig(decoder) {
  const title = document.getElementById("decode-config-title");
  const body = document.getElementById("decode-config-body");
  title.textContent = protocolLabel(decoder.protocol);
  const options = decoder.options || {};
  const channels = decoder.channels || {};
  const overlayOn = overlayEnabled(decoder.id);
  const pref = decodePref(decoder.id);
  const parts = [`<label class="check"><input id="decode-overlay" type="checkbox"${overlayOn ? " checked" : ""}> Overlay decoded values on the data line</label>`];
  if ((state.decoderCatalog.find((item) => item.id === decoder.protocol)?.channels || []).length) {
    const format = decodeFormat(decoder.id);
    const options = Object.entries(DECODE_FORMATS).map(([value, label]) => `<option value="${value}"${format === value ? " selected" : ""}>${label}</option>`).join("");
    parts.push(`<label class="check"><input id="decode-condense" type="checkbox"${pref.condensed ? " checked" : ""}> Hide channels under this decoder</label>
      <label class="field">Decoded data
        <select id="decode-format">${options}</select>
      </label>`);
  }
  const schema = state.decoderCatalog.find((item) => item.id === decoder.protocol);
  const signals = schema ? [...new Set([...(schema.channels || []), ...(schema.optional_channels || [])])] : Object.keys(channels);
  parts.push(...signals.map((name) => signalField(name, channels[name])));
  if (decoder.protocol === "spi") {
    const cpol = options.cpol === "1" || options.cpol === "true" || options.cpol === "high";
    const cpha = options.cpha === "1" || options.cpha === "true" || options.cpha === "high";
    const mode = (cpol ? 2 : 0) + (cpha ? 1 : 0);
    parts.push(`<label class="field">SPI mode
      <select id="decode-mode">
        <option value="0"${mode === 0 ? " selected" : ""}>Mode 0</option>
        <option value="1"${mode === 1 ? " selected" : ""}>Mode 1</option>
        <option value="2"${mode === 2 ? " selected" : ""}>Mode 2</option>
        <option value="3"${mode === 3 ? " selected" : ""}>Mode 3</option>
      </select>
    </label>
    <label class="field">Bit order
      <select id="decode-order">
        <option value="msb"${options.order === "lsb" ? "" : " selected"}>MSB first</option>
        <option value="lsb"${options.order === "lsb" ? " selected" : ""}>LSB first</option>
      </select>
    </label>
    <label class="field">Bits per word
      <input id="decode-bits" type="number" min="1" max="8" value="${escapeHtml(options.bits || "8")}">
    </label>
    <label class="field">Chip select
      <select id="decode-cs">
        <option value="low"${options.cs === "high" ? "" : " selected"}>Active low</option>
        <option value="high"${options.cs === "high" ? " selected" : ""}>Active high</option>
      </select>
    </label>`);
  } else if (decoder.protocol === "i2c") {
    parts.push(`<label class="field">Address
      <input id="decode-address" type="text" value="${escapeHtml(options.address && options.address !== "any" ? options.address : "")}" placeholder="any, or 50">
    </label>`);
  } else if (decoder.protocol === "uart") {
    parts.push(`<label class="field">Samples per bit
      <input id="decode-bit-samples" type="number" min="1" max="10000" value="${escapeHtml(options.bit_samples || "10")}">
    </label>`);
  }
  for (const option of schema?.options || []) {
    const current = options[option.id] ?? option.default;
    const name = escapeHtml(option.name);
    const id = escapeHtml(option.id);
    if (option.values?.length) {
      const choices = option.values.map((value) => `<option value="${escapeHtml(value)}"${value === current ? " selected" : ""}>${escapeHtml(value)}</option>`).join("");
      parts.push(`<label class="field">${name}<select data-decoder-option="${id}">${choices}</select></label>`);
    } else {
      parts.push(`<label class="field">${name}<input data-decoder-option="${id}" type="text" value="${escapeHtml(current)}"></label>`);
    }
  }
  if (schema?.stack_on) {
    const parents = state.decoders.filter((row) => emitsProtocol(row.protocol, schema.stack_on) && row.id !== decoder.id);
    const choices = parents.map((row) => `<option value="${escapeHtml(row.id)}"${row.id === decoder.stack_on ? " selected" : ""}>${escapeHtml(protocolLabel(row.protocol) + " " + row.id)}</option>`).join("");
    parts.push(`<label class="field">Stacks on
      <select id="decode-stack">${choices}</select>
    </label>`);
  }
  body.innerHTML = parts.join("");
  document.getElementById("decode-config").classList.remove("hidden");
  document.getElementById("decode-config-form").dataset.id = decoder.id;
}

function closeDecodeConfig() {
  document.getElementById("decode-config").classList.add("hidden");
}

let preferences = { firmware_dir: "", scripts_dir: "", theme: "system", export_dir: "", edge_snap: true };
let exportDirTimer = null;
let exportDirSave = 0;

function rememberExportDirectory(directory) {
  exportChoice.directory = directory;
  preferences.export_dir = directory;
  try { localStorage.setItem("logicview-export-dir", directory); } catch (_) { /* the saved preferences still hold the folder */ }
  clearTimeout(exportDirTimer);
  exportDirTimer = setTimeout(persistExportDirectory, 250);
}

async function persistExportDirectory() {
  const seq = ++exportDirSave;
  const directory = preferences.export_dir || "";
  try {
    const response = await fetch("/api/export-dir", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ directory }),
    });
    if (!response.ok || seq !== exportDirSave) return;
    const saved = await response.json();
    if (seq === exportDirSave) preferences = saved;
  } catch (_) { /* the field still holds the folder for this session */ }
}
const systemTheme = window.matchMedia("(prefers-color-scheme: light)");
function applyTheme() {
  const light = preferences.theme === "light" || (preferences.theme === "system" && systemTheme.matches);
  document.documentElement.dataset.theme = light ? "light" : "dark";
  state.gutterSig = "";
  renderGutter();
  drawWave();
  if (window.ipc) window.ipc.postMessage("theme:" + (light ? "light" : "dark"));
}
systemTheme.addEventListener("change", applyTheme);
async function loadDecoderCatalog() {
  state.decoderCatalog = await api({ cmd: "decoder_catalog" });
}
async function loadPreferences() {
  const response = await fetch("/api/preferences");
  if (!response.ok) throw new Error("Could not load preferences");
  preferences = await response.json();
  if (preferences.export_dir) {
    exportChoice.directory = preferences.export_dir;
  } else if (exportChoice.directory) {
    rememberExportDirectory(exportChoice.directory);
  }
  paintExportFields(null, true);
  applyTheme();
}
document.getElementById("preferences-open").addEventListener("click", () => {
  document.getElementById("preferences-firmware").value = preferences.firmware_dir;
  document.getElementById("preferences-scripts").value = preferences.scripts_dir;
  document.getElementById("preferences-edge-snap").checked = preferences.edge_snap !== false;
  const theme = document.querySelector(`input[name="preferences-theme"][value="${preferences.theme}"]`);
  if (theme) theme.checked = true;
  document.getElementById("preferences-error").textContent = "";
  document.getElementById("preferences-dialog").showModal();
});
document.getElementById("preferences-cancel").addEventListener("click", () => document.getElementById("preferences-dialog").close());
document.getElementById("preferences-form").addEventListener("submit", async (ev) => {
  ev.preventDefault();
  const next = { firmware_dir: document.getElementById("preferences-firmware").value.trim(),
    scripts_dir: document.getElementById("preferences-scripts").value.trim(), edge_snap: document.getElementById("preferences-edge-snap").checked, theme: document.querySelector('input[name="preferences-theme"]:checked').value };
  try {
    const response = await fetch("/api/preferences", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(next) });
    if (!response.ok) throw new Error(await response.text());
    preferences = await response.json();
    if (!preferences.edge_snap) { state.hoverSnap = null; state.hoverSequence += 1; }
    applyTheme();
    await loadDecoderCatalog();
    if (state.tab === "decode") selectTab("decode");
    document.getElementById("preferences-dialog").close();
  } catch (err) { document.getElementById("preferences-error").textContent = err.message; }
});

let mcpState = null;
function paintMcp(data) {
  mcpState = data;
  document.getElementById("mcp-enabled").checked = data.enabled;
  document.getElementById("mcp-port").value = data.port;
  document.getElementById("mcp-address").textContent = data.address;
  document.getElementById("mcp-open").classList.toggle("enabled", data.enabled);
}
async function updateMcp(enabled, port) {
  const error = document.getElementById("mcp-error");
  error.textContent = "";
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    error.textContent = "Enter a port from 1 to 65535.";
    if (mcpState) document.getElementById("mcp-enabled").checked = mcpState.enabled;
    return;
  }
  try {
    const response = await fetch("/api/mcp", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ enabled, port }) });
    if (!response.ok) throw new Error(await response.text());
    paintMcp(await response.json());
  } catch (err) {
    error.textContent = err.message;
    if (mcpState) document.getElementById("mcp-enabled").checked = mcpState.enabled;
  }
}
document.getElementById("mcp-open").addEventListener("click", async () => {
  const flyout = document.getElementById("mcp-flyout");
  const open = flyout.classList.toggle("hidden") === false;
  document.getElementById("mcp-open").setAttribute("aria-expanded", String(open));
  if (open) {
    try { const response = await fetch("/api/mcp"); if (!response.ok) throw new Error("Could not read MCP status"); paintMcp(await response.json()); }
    catch (err) { document.getElementById("mcp-error").textContent = err.message; }
  }
});
document.getElementById("mcp-enabled").addEventListener("change", (ev) => updateMcp(ev.target.checked, Number(document.getElementById("mcp-port").value)));
document.getElementById("mcp-port").addEventListener("change", (ev) => updateMcp(!!mcpState?.enabled, Number(ev.target.value)));
document.addEventListener("click", (ev) => {
  if (!ev.target.closest("#mcp-flyout, #mcp-open")) {
    document.getElementById("mcp-flyout").classList.add("hidden");
    document.getElementById("mcp-open").setAttribute("aria-expanded", "false");
  }
});
document.addEventListener("click", (ev) => {
  const source = ev.target.nodeType === 1 ? ev.target : ev.target.parentElement;
  const button = source && source.closest(".path-browse");
  if (!button) return;
  if (window.ipc) {
    window.ipc.postMessage("pick-directory:" + button.dataset.pathTarget);
    return;
  }
  const message = "Folder selection is available in the desktop app; enter a path here.";
  if (String(button.dataset.pathTarget || "").startsWith("preferences-")) {
    document.getElementById("preferences-error").textContent = message;
  } else {
    statusEl.textContent = message;
  }
});
window.logicviewDirectorySelected = (target, path) => {
  const input = document.getElementById(target);
  if (!input) return;
  const preferences = target === "preferences-firmware" || target === "preferences-scripts";
  if (preferences && !document.getElementById("preferences-dialog").open) return;
  input.value = path;
  if (target === "panel-export-dir" || target === "dialog-export-dir") {
    syncExportChoice(target.startsWith("dialog-") ? "dialog" : "panel");
  }
};
window.logicviewNativeDrop = (path, x, y) => {
  const target = document.elementFromPoint(x / window.devicePixelRatio, y / window.devicePixelRatio);
  if (document.getElementById("preferences-dialog").open && target && (target.id === "preferences-firmware" || target.id === "preferences-scripts")) {
    if (path.isDirectory) window.logicviewDirectorySelected(target.id, path.value);
    else document.getElementById("preferences-error").textContent = "Drop a folder on the directory field.";
    return;
  }
  const row = target && target.closest && target.closest(".export-location");
  if (row) {
    const input = row.querySelector("input");
    const folder = path.isDirectory ? path.value : parentDirectory(path.value);
    if (!input || !folder) {
      statusEl.textContent = "Drop a folder on the location field.";
      return;
    }
    assignExportDirectory(input, folder);
    return;
  }
  if (target && target.closest(".wave-stage") && !path.isDirectory && isCaptureName(path.value)) openNativeCapture(path.value);
};
async function openNativeCapture(path) {
  try {
    const response = await fetch("/api/import-path", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ path }) });
    const text = await response.text();
    let json = {};
    try { json = JSON.parse(text); } catch (_) { json = { error: text }; }
    if (!response.ok || !json.ok) throw new Error(json.error || "Could not open capture");
    await applyImportedCapture(json.data, path.split(/[\\/]/).pop());
  } catch (err) { statusEl.textContent = err.message; }
}

async function loadContributors() {
  const list = document.getElementById("about-contributors");
  if (!list) return;
  try {
    const response = await fetch("/api/contributors");
    if (!response.ok) return;
    const people = await response.json();
    list.replaceChildren();
    for (const person of people) {
      const name = person && person.name ? String(person.name) : "";
      const contribution = person && person.contribution ? String(person.contribution) : "";
      if (!name) continue;
      const item = document.createElement("li");
      item.textContent = `${name} -- ${contribution}`;
      list.appendChild(item);
    }
    const box = list.parentElement;
    if (box) box.classList.toggle("is-still", list.scrollHeight <= box.clientHeight);
  } catch (_) { /* the credits list stays empty when the file cannot be read */ }
}

async function boot() {
  await loadPreferences();
  await loadContributors();
  try {
    const loaded = await Promise.race([
      fetch("/api/mcp").then((response) => (response.ok ? response.json() : null)),
      new Promise((resolve) => setTimeout(() => resolve(null), 800)),
    ]);
    if (loaded) paintMcp(loaded);
  } catch (_) { /* status is available from the flyout */ }
  await loadDecoderCatalog();
  await refreshSessions();
  const listed = await api({ cmd: "list_sessions" });
  state.active = listed.active;
  state.sessions = listed.sessions;
  const status = await api({ cmd: "status" });
  applyStatus(status, false);
  selectTab("device");
  await refreshDecoders();
  await loadAnnotations();
  await loadDeviceChoices();
  const profiles = await api({ cmd: "list_profiles" }).catch(() => []);
  const pod = state.deviceList.find((device) => device.kind === "usb" && profiles.some((profile) => profile.id === device.id && profile.hardware_tested));
  if (pod && !(state.devices || []).some((device) => device.id === pod.id)) {
    try { await useDevice(pod.id); }
    catch (err) {
      const message = `Could not open ${pod.name}: ${err.message}`;
      statusEl.textContent = message;
      // Keep Demo selected, but explain why auto-connect did not stick.
      window.alert(message);
    }
  }
  deviceSelectionReady = true;
  connectSocket();
  drawWave();
  syncTimebaseLabel();
}

fillColorSwatches();
bindCaptureDrop();
document.getElementById("export-dialog-fields").innerHTML = exportFormHtml("dialog");
bindExportForm("dialog");
document.getElementById("export-dialog-cancel").addEventListener("click", closeExportDialog);
document.getElementById("export-dialog-form").addEventListener("submit", (ev) => {
  ev.preventDefault();
  runExport("dialog");
});
document.getElementById("save-cancel").addEventListener("click", closeSaveDialog);
document.getElementById("save-form").addEventListener("submit", (ev) => confirmSave(ev));
document.getElementById("save-form").addEventListener("keydown", (ev) => {
  if (ev.key === "Escape") {
    ev.preventDefault();
    ev.stopPropagation();
    closeSaveDialog();
  }
});
document.getElementById("color-custom").addEventListener("input", (ev) => {
  const fly = document.getElementById("color-flyout");
  if (fly.dataset.row) setChannelColor(fly.dataset.row, ev.target.value);
});
document.getElementById("setup-file").addEventListener("change", (ev) => {
  const file = ev.target.files && ev.target.files[0];
  ev.target.value = "";
  if (file) openSetupFile(file);
});
document.getElementById("bus-cancel").addEventListener("click", closeBusDialog);
document.getElementById("signal-decoder-cancel").addEventListener("click", closeSignalDecoderDialog);
document.getElementById("signal-decoder-dialog").addEventListener("keydown", (ev) => {
  if (ev.key === "Escape") { ev.preventDefault(); ev.stopPropagation(); closeSignalDecoderDialog(); }
});
for (const radio of document.querySelectorAll('input[name="group-type"]')) {
  radio.addEventListener("change", syncGroupDialog);
}
document.getElementById("bus-msb-first").addEventListener("change", syncGroupDialog);
document.getElementById("bus-form").addEventListener("submit", (ev) => {
  ev.preventDefault();
  const type = document.querySelector('input[name="group-type"]:checked');
  const radix = document.querySelector('input[name="bus-radix"]:checked');
  const groupType = type ? type.value : "bus";
  const v = view();
  const fallback = (groupType === "group" ? "Group " : "Bus ") + (editingGroupId || v.nextBus || 1);
  const name = document.getElementById("bus-name").value.trim() || fallback;
  const radixValue = radix ? radix.value : "hex";
  const msbFirst = document.getElementById("bus-msb-first").checked;
  const done = editingGroupId != null
    ? applyGroupEdits(editingGroupId, groupType, name, radixValue, msbFirst)
    : createChannelGroup(groupType, name, radixValue, msbFirst);
  if (done) closeBusDialog();
});

document.getElementById("decode-config-cancel").addEventListener("click", closeDecodeConfig);
document.getElementById("decode-config-form").addEventListener("submit", async (ev) => {
  ev.preventDefault();
  const id = ev.target.dataset.id;
  const decoder = state.decoders.find((row) => row.id === id);
  if (!decoder) return;
  const channels = {};
  for (const select of ev.target.querySelectorAll("[data-signal]")) {
    channels[select.dataset.signal] = select.value;
  }
  const options = {};
  if (decoder.protocol === "spi") {
    const mode = Number(document.getElementById("decode-mode").value);
    options.cpol = mode >= 2 ? "1" : "0";
    options.cpha = mode % 2 ? "1" : "0";
    options.order = document.getElementById("decode-order").value;
    options.bits = document.getElementById("decode-bits").value;
    options.cs = document.getElementById("decode-cs").value;
  } else if (decoder.protocol === "i2c") {
    const address = document.getElementById("decode-address").value.trim();
    options.address = address || "any";
  } else if (decoder.protocol === "uart") {
    options.bit_samples = document.getElementById("decode-bit-samples").value;
  }
  for (const input of ev.target.querySelectorAll("[data-decoder-option]")) {
    options[input.dataset.decoderOption] = input.value;
  }
  const stack = document.getElementById("decode-stack");
  const overlayBox = document.getElementById("decode-overlay");
  const condenseBox = document.getElementById("decode-condense");
  const formatBox = document.getElementById("decode-format");
  const pref = decodePref(id);
  if (overlayBox) pref.overlay = overlayBox.checked;
  if (condenseBox && pref.condensed !== condenseBox.checked) { pref.condensed = condenseBox.checked; pref.lanes = {}; }
  if (formatBox && DECODE_FORMATS[formatBox.value]) pref.format = formatBox.value;
  if (formatBox && DECODE_FORMATS[formatBox.value]) {
    if (!state.spiView[id]) state.spiView[id] = { analog: false };
    state.spiView[id].analog = pref.format === "analog";
  }
  state.gutterSig = "";
  closeDecodeConfig();
  state.decoderBusy = (state.decoderBusy || 0) + 1;
  paintStatus();
  let decodeError = null;
  try {
    await api({
      cmd: "update_decoder",
      session: state.active,
      id,
      channels,
      options,
      stack_on: stack ? stack.value : null,
    });
    await refreshDecoders();
    await loadAnnotations();
    scheduleTiles();
    refreshOverview();
  } catch (err) {
    decodeError = err;
    document.getElementById("decode-config").classList.remove("hidden");
  } finally {
    state.decoderBusy = Math.max(0, state.decoderBusy - 1);
    paintStatus();
    if (decodeError) statusEl.textContent = decodeError.message;
  }
});

// Keep native WebView menus from appearing while preserving application handlers.
document.addEventListener("contextmenu", (event) => event.preventDefault());

function placeViewportMenu(menu, x, y) {
  const margin = 8;
  const left = Math.max(margin, Math.min(x, window.innerWidth - margin - menu.offsetWidth));
  const top = Math.max(margin, Math.min(y, window.innerHeight - margin - menu.offsetHeight));
  menu.style.left = left + "px";
  menu.style.top = top + "px";
}

function placeSubmenu(row) {
  const submenu = row.querySelector(":scope > .device-submenu, :scope > .decode-menu-choices");
  if (!submenu) return;
  submenu.style.visibility = "hidden";
  submenu.style.display = "block";
  submenu.style.position = "fixed";
  submenu.style.maxWidth = "calc(100vw - 16px)";
  submenu.style.maxHeight = "calc(100vh - 16px)";
  submenu.style.overflow = "auto";
  const rect = row.getBoundingClientRect();
  const x = rect.right + submenu.offsetWidth <= window.innerWidth - 8
    ? rect.right - 4 : rect.left - submenu.offsetWidth + 4;
  placeViewportMenu(submenu, x, rect.top);
  submenu.style.right = "auto";
  submenu.style.display = "";
  submenu.style.visibility = "";
}

for (const type of ["pointerover", "focusin"]) {
  document.addEventListener(type, (event) => {
    const row = event.target.closest(".device-sub, .decode-menu-sub");
    if (row) placeSubmenu(row);
  });
}

const toolbar = document.querySelector(".toolbar");
const overflowButton = document.getElementById("toolbar-overflow-button");
const overflowPanel = document.getElementById("toolbar-overflow");
const toolbarItems = [...toolbar.children].filter((item) => item !== overflowButton);

function closeToolbarOverflow() {
  overflowPanel.classList.add("hidden");
  overflowButton.setAttribute("aria-expanded", "false");
}

function layoutToolbar() {
  closeToolbarOverflow();
  for (const item of toolbarItems) toolbar.insertBefore(item, overflowButton);
  overflowButton.classList.remove("hidden");
  const style = getComputedStyle(toolbar);
  const gap = parseFloat(style.columnGap) || 0;
  const available = toolbar.clientWidth - (parseFloat(style.paddingLeft) || 0) - (parseFloat(style.paddingRight) || 0);
  const widths = toolbarItems.map((item) => item.classList.contains("spacer") ? 0 : item.getBoundingClientRect().width);
  const total = widths.reduce((sum, width) => sum + width, 0) + gap * Math.max(0, toolbarItems.length - 1);
  if (total <= available) {
    overflowButton.classList.add("hidden");
    return;
  }
  let used = overflowButton.getBoundingClientRect().width;
  let cutoff = 0;
  for (; cutoff < toolbarItems.length; cutoff++) {
    const next = widths[cutoff] + gap;
    if (used + next > available) break;
    used += next;
  }
  for (const item of toolbarItems.slice(cutoff)) overflowPanel.append(item);
}

overflowButton.addEventListener("click", (event) => {
  event.stopPropagation();
  if (!overflowPanel.classList.contains("hidden")) return closeToolbarOverflow();
  overflowPanel.classList.remove("hidden");
  const rect = overflowButton.getBoundingClientRect();
  placeViewportMenu(overflowPanel, rect.right - overflowPanel.offsetWidth, rect.bottom + 6);
  overflowButton.setAttribute("aria-expanded", "true");
});
document.addEventListener("click", (event) => {
  if (!event.target.closest("#toolbar-overflow, #toolbar-overflow-button")) closeToolbarOverflow();
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && !overflowPanel.classList.contains("hidden")) {
    closeToolbarOverflow();
    overflowButton.focus();
  }
});
new ResizeObserver(layoutToolbar).observe(toolbar);
layoutToolbar();

boot().catch((err) => {
  statusEl.textContent = err.message;
});
