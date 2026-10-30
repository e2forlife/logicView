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
  total: 0,
  rate: 1_000_000,
  durationMs: 2000,
  channels: [],
  analog: [],
  triggerSample: null,
  hidden: new Set(),
  tiles: {},
  overviewCols: null,
  req: 0,
  hoverText: "",
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
  decoders: [],
  selectedDecoder: null,
  decodeQuery: "",
  spiView: {},
  decodeView: {},
  gutterSig: "",
  nextMarker: 1,
  nextMeasure: 1,
  channelGroup: 0,
  tileView: null,
  planned: 0,
  waitKind: "",
  deviceList: [],
  profiles: [],
};

const settings = {
  rate: 1_000_000,
  duration: 2000,
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
      selected: null,
      names: {},
      colors,
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

function logicRowModel(channel, decoderId) {
  const index = channel.index;
  const tileKey = "logic:" + index;
  return {
    key: decoderId ? "logic:" + index + "@" + decoderId : tileKey,
    tileKey,
    kind: "logic",
    channel: index,
    name: channel.name,
    color: storedColor(tileKey, channel.color),
    device: channel.device_name || "",
    decoderId: decoderId || "",
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
  for (const bus of view().buses || []) {
    rows.push({
      key: "bus:" + bus.id,
      kind: "bus",
      channel: bus.channels[0] ?? 0,
      name: bus.name,
      color: storedColor("bus:" + bus.id, "#d5deea"),
      device: "",
      bus,
    });
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

function decodeBusRow(decoder, channel) {
  const analog = decodeShownAnalog(decoder.id);
  const name = protocolLabel(decoder.protocol);
  return {
    key: "decode:" + decoder.id,
    kind: "decode",
    channel,
    name,
    color: analog ? "#7dcea0" : "#8eb6ff",
    device: "",
    decoderId: decoder.id,
    bus: {
      id: "decode:" + decoder.id,
      name,
      channels: [],
      analog,
      decode: decoder.id,
    },
  };
}

function groupRows(decoder, source) {
  const indexes = indexesInOrder(decoderIndexes(decoder), source);
  const channel = indexes.length ? indexes[0] : 0;
  const rows = [decodeBusRow(decoder, channel)];
  if (decoderCondensed(decoder.id)) return rows;
  const byIndex = new Map(state.channels.map((item) => [item.index, item]));
  for (const index of indexes) {
    const signal = byIndex.get(index);
    if (!signal) continue;
    const row = logicRowModel(signal, decoder.id);
    row.child = true;
    rows.push(row);
  }
  return rows;
}

function displayRows() {
  const source = orderedSourceRows();
  const decoders = state.decoders || [];
  const groups = decoders.map((decoder) => {
    const indexes = decoderIndexes(decoder);
    let anchor = -1;
    source.forEach((row, index) => {
      if (anchor >= 0) return;
      if (row.kind === "logic" && indexes.includes(row.channel)) anchor = index;
    });
    return {
      id: decoder.id,
      anchor,
      stackOn: decoder.stack_on || "",
      rows: groupRows(decoder, source),
    };
  });
  const claimed = new Set();
  for (const decoder of decoders) {
    for (const index of decoderIndexes(decoder)) claimed.add(index);
  }
  const out = [];
  const placed = new Set();
  const waitingOnParent = (group) => group.stackOn && groups.some((item) => item.id === group.stackOn && !placed.has(item.id));
  const placeGroup = (group) => {
    if (placed.has(group.id)) return;
    out.push(...group.rows);
    placed.add(group.id);
    for (const child of groups) {
      if (!placed.has(child.id) && child.stackOn === group.id) placeGroup(child);
    }
  };
  source.forEach((row, index) => {
    for (const group of groups) {
      if (group.anchor !== index || placed.has(group.id) || waitingOnParent(group)) continue;
      placeGroup(group);
    }
    if (row.kind === "logic" && claimed.has(row.channel)) return;
    out.push(row);
  });
  let guard = groups.length + 1;
  while (placed.size < groups.length && guard-- > 0) {
    const next = groups.find((group) => !placed.has(group.id) && !waitingOnParent(group));
    if (!next) break;
    placeGroup(next);
  }
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

function channelIsEnabled(index) {
  if (!settings.channelEnable) return true;
  return (settings.channelEnable & (1 << index)) !== 0;
}

function rowEnabled(row) {
  if (row.kind === "lane" || row.kind === "condense" || row.kind === "decode") return true;
  if (row.kind === "bus") {
    if (row.bus && row.bus.decode) return true;
    return row.bus.channels.some((index) => channelIsEnabled(index));
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
  if (!settings.trigger || state.total <= 0) return 0;
  const percent = Number(settings.percent) || 0;
  if (percent > 0) {
    const raw = Math.floor(state.total * (percent / 100));
    return raw - (raw % 64);
  }
  if (typeof state.triggerSample === "number" && state.triggerSample > 0) return state.triggerSample;
  return 0;
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
    if (state.tab === "device") selectTab("device");
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

function fitView() {
  const v = view();
  const width = Math.max(1, wave.clientWidth || 1);
  if (state.total <= 0) {
    v.start = 0;
    v.spp = 1;
    return;
  }
  const fit = state.total / width;
  v.start = 0;
  v.spp = Math.min(fit, 8);
}

function clampView() {
  const v = view();
  const width = Math.max(1, wave.clientWidth || 1);
  const span = width * v.spp;
  if (state.total <= 0) {
    v.start = 0;
    return;
  }
  if (span >= state.total) {
    v.start = 0;
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
  renderTriggerChoices();
  renderMarkerList();
  renderMeasureList();
  drawRuler();
  syncTimebaseLabel();
}

function paintStatus() {
  const live = isLive(state.phase);
  runBtn.disabled = live || commandBusy;
  stopBtn.disabled = !live || commandBusy;
  const name = document.getElementById("device-name");
  if (name) name.textContent = settings.deviceName;
  const count = state.total.toLocaleString();
  const trigger = state.triggerSample == null ? "" : ` · trigger @ ${state.triggerSample}`;
  const hover = state.hoverText ? ` · ${state.hoverText}` : "";
  statusEl.textContent = `${state.phase} · ${count} samples · ${formatHz(state.rate)}${trigger}${hover}`;
}

function renderTabs() {
  tabsEl.replaceChildren();
  for (const session of state.sessions) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "tab" + (session.id === state.active ? " active" : "");
    button.textContent = session.name;
    button.addEventListener("click", () => selectSession(session.id));
    tabsEl.appendChild(button);
  }
}

function renderTriggerChoices() {
  const select = document.getElementById("trig-channel");
  if (!select) return;
  const sig = state.channels.map((channel) => channel.index + ":" + channel.name).join("|");
  if (select.dataset.sig === sig) return;
  select.dataset.sig = sig;
  select.replaceChildren();
  const rows = state.channels.length ? state.channels : [{ index: 0, name: "0" }];
  for (const channel of rows) {
    const option = document.createElement("option");
    option.value = String(channel.index);
    option.textContent = channel.name;
    select.appendChild(option);
  }
  select.value = String(settings.triggerChannel);
  if (select.value !== String(settings.triggerChannel)) {
    settings.triggerChannel = Number(select.value || 0);
  }
}

let channelDrag = null;

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
  if (!drag.moved) {
    view().selected = drag.key;
    state.gutterSig = "";
    renderGutter();
  }
}

function startChannelDrag(key, startY) {
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
  channelDrag = { key, startY, moved: false, move, up };
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
  return row.kind === "decode" && decoderCondensed(row.decoderId);
}

function foldButton(row, folded) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "fold";
  button.title = folded ? "Show waveform channels" : "Hide waveform channels";
  button.setAttribute("aria-expanded", folded ? "false" : "true");
  button.setAttribute("aria-label", button.title);
  button.innerHTML = `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 6l6 6-6 6"></path></svg>`;
  const animate = foldAnim === row.decoderId;
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
    foldAnim = row.decoderId;
    decodePref(row.decoderId).condensed = !folded;
    state.gutterSig = "";
    renderGutter();
    drawWave();
    scheduleTiles();
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

function renderGutter() {
  const metrics = rowMetrics();
  const selected = view().selected;
  const sig = metrics.layout.map((item) => item.row.key + signalName(item.row) + item.row.color + item.height + (state.hidden.has(item.row.key) ? "0" : "1") + (rowFolded(item.row) ? "c" : "") + (item.row.child ? "g" : "") + (item.row.key === selected ? "s" : "")).join("|");
  if (sig === state.gutterSig) return;
  state.gutterSig = sig;
  gutter.replaceChildren();
  for (const item of metrics.layout) {
    const row = item.row;
    const folded = rowFolded(row);
    const dim = state.hidden.has(row.key);
    const el = document.createElement("div");
    el.className = "ch" + (row.child ? " child" : "") + (row.key === selected ? " selected" : "") + (dim ? " dim" : "");
    el.dataset.key = row.key;
    el.style.height = item.height + "px";
    el.style.flex = "none";
    el.title = row.device ? `${signalName(row)} · ${row.device}` : signalName(row);
    const bar = document.createElement("span");
    bar.className = "bar";
    bar.style.background = row.color;
    bar.title = "Channel color";
    bar.addEventListener("mousedown", (ev) => {
      ev.preventDefault();
      ev.stopPropagation();
    });
    bar.addEventListener("click", (ev) => {
      ev.preventDefault();
      ev.stopPropagation();
      openColorFlyout(row, bar);
    });
    const name = document.createElement("span");
    name.className = "name";
    name.textContent = signalName(row);
    name.style.color = row.color;
    if (row.kind === "logic") {
      name.title = "Double-click to rename";
      name.addEventListener("mousedown", (ev) => ev.stopPropagation());
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
    if (row.kind === "decode") el.append(bar, foldButton(row, folded), name, kind, eye, handle);
    else el.append(bar, name, kind, eye, handle);
    el.addEventListener("mousedown", (ev) => {
      if (ev.button !== 0 || ev.target.closest("button, .row-resize, .bar")) return;
      startChannelDrag(row.key, ev.clientY);
    });
    if ((row.kind === "bus" || row.kind === "decode") && row.bus) {
      el.addEventListener("contextmenu", (ev) => {
        ev.preventDefault();
        openBusMenu(row.bus, ev.clientX, ev.clientY);
      });
    }
    gutter.appendChild(el);
  }
}

function signalName(row) {
  const names = view().names;
  return (names && names[row.key]) || row.name;
}

function startRename(row, nameEl) {
  const input = document.createElement("input");
  input.className = "rename";
  input.value = signalName(row);
  input.setAttribute("aria-label", "Signal name");
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
      if (!next || next === row.name) delete names[row.key];
      else names[row.key] = next;
    }
    state.gutterSig = "";
    renderGutter();
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
  const keys = orderedRows().map((row) => row.key);
  const from = keys.indexOf(fromKey);
  const to = keys.indexOf(toKey);
  if (from < 0 || to < 0) return;
  const [moved] = keys.splice(from, 1);
  keys.splice(to, 0, moved);
  persistOrder(keys);
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
    ctx.textBaseline = "top";
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
      ctx.fillText(formatRulerTick(t, step), x, 3);
      lastLabel = x;
    }
  }
  if (settings.trigger && state.total > 0) {
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

function drawWave() {
  const metrics = rowMetrics();
  const { ctx, w, h } = prep(wave, metrics.total);
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "#0b0f14";
  ctx.fillRect(0, 0, w, h);
  const layout = metrics.layout;
  if (state.total <= 0 || layout.length === 0) {
    ctx.fillStyle = "#8b95a6";
    ctx.font = "14px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("Press Run to capture the demo source", w / 2, h / 2);
    return;
  }
  drawGrid(ctx, w, h, layout);
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
    if (row.kind === "analog") drawAnalog(ctx, cols, item.top, item.height, row.color);
    else if (row.kind === "logic") drawDigital(ctx, cols, item.top, item.height, row.color);
  }
  drawBuses(ctx, layout);
  drawCondensedRows(ctx, w, layout);
  drawDecodeOverlay(ctx, w, metrics);
  ctx.restore();
  for (const item of layout) {
    const row = item.row;
    if (row.kind !== "logic" || state.hidden.has(row.key)) continue;
    const top = item.top;
    const pad = Math.max(8, item.height * 0.22);
    ctx.font = "11px sans-serif";
    ctx.textAlign = "left";
    ctx.textBaseline = "middle";
    ctx.lineWidth = 3;
    ctx.strokeStyle = "rgba(8, 12, 18, 0.9)";
    ctx.strokeText("H", 8, top + pad);
    ctx.strokeText("L", 8, top + item.height - pad);
    ctx.fillStyle = "#d5deea";
    ctx.fillText("H", 8, top + pad);
    ctx.fillText("L", 8, top + item.height - pad);
  }
  drawMeasureSpan(ctx, w, h);
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
    ctx.strokeStyle = "rgba(255,255,255,0.28)";
    ctx.beginPath();
    ctx.moveTo(state.hoverX + 0.5, 0);
    ctx.lineTo(state.hoverX + 0.5, h);
    ctx.stroke();
  }
}

function drawGrid(ctx, w, h, layout) {
  const v = view();
  ctx.save();
  ctx.lineWidth = 1;
  if (state.rate > 0) {
    const span = (w * v.spp) / state.rate;
    const step = niceStep(span, w);
    if (step && isFinite(step)) {
      const startSec = sampleSeconds(v.start);
      const first = Math.ceil(startSec / step) * step;
      ctx.strokeStyle = "rgba(86, 140, 190, 0.16)";
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
    ctx.strokeStyle = "rgba(255,255,255,0.045)";
    ctx.beginPath();
    ctx.moveTo(0, top + 0.5);
    ctx.lineTo(w, top + 0.5);
    ctx.stroke();
    if (row.kind === "logic") {
      const pad = Math.max(8, rowH * 0.22);
      ctx.strokeStyle = "rgba(140, 170, 200, 0.14)";
      ctx.beginPath();
      ctx.moveTo(0, top + pad + 0.5);
      ctx.lineTo(w, top + pad + 0.5);
      ctx.moveTo(0, top + rowH - pad + 0.5);
      ctx.lineTo(w, top + rowH - pad + 0.5);
      ctx.stroke();
    } else if (row.kind === "analog") {
      const mid = top + rowH / 2;
      ctx.strokeStyle = "rgba(140, 170, 200, 0.18)";
      ctx.beginPath();
      ctx.moveTo(0, mid + 0.5);
      ctx.lineTo(w, mid + 0.5);
      ctx.stroke();
      ctx.fillStyle = "rgba(176, 188, 204, 0.55)";
      ctx.font = "10px sans-serif";
      ctx.textAlign = "left";
      ctx.textBaseline = "middle";
      ctx.fillText("1 V", 6, top + 12);
      ctx.fillText("0 V", 6, mid);
      ctx.fillText("−1 V", 6, top + rowH - 12);
    } else if (row.kind === "bus" && row.bus && row.bus.analog) {
      const max = row.bus.decode ? 255 : Math.max(1, (1 << row.bus.channels.length) - 1);
      ctx.fillStyle = "rgba(176, 188, 204, 0.55)";
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
    ctx.fillStyle = "#d5e2ff";
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

function decoderCondensed(id) {
  return !!(state.decodeView[id] && state.decodeView[id].condensed);
}

function decodeFormat(id) {
  const pref = state.decodeView[id];
  return pref && DECODE_FORMATS[pref.format] ? pref.format : "hex";
}

function decoderChannelIndexes(decoder) {
  return Object.values(decoder.channels || {}).map(Number).filter((index) => Number.isFinite(index));
}

function rowHiddenByDecoder(row) {
  return row.kind === "logic" && !!row.decoderId && decoderCondensed(row.decoderId);
}

function rowKindLabel(row) {
  if (row.kind === "condense" || row.kind === "decode") {
    if (row.bus && row.bus.analog) return "Analog";
    return DECODE_FORMATS[decodeFormat(row.decoderId)] || "Hex";
  }
  if (row.kind === "analog") return "Analog";
  if (row.kind === "bus") return row.bus && row.bus.analog ? "Analog" : "Bus";
  return "Digital";
}

function valueAnnotations(decoder) {
  const rows = (state.annotations || []).filter((row) => row.decoder === decoder.id);
  const values = rows.filter((row) => !FRAME_CLASS.has(row.class));
  return values.length ? values : rows;
}

function annotationLabel(row) {
  if (row.protocol === "spi" && row.fields && (row.fields.mosi || row.fields.miso)) {
    return "0x" + (row.fields.mosi || "00") + "/0x" + (row.fields.miso || "00");
  }
  return row.text || row.class || "";
}

function logicRow(layout, channel, decoderId) {
  const index = Number(channel);
  if (!Number.isFinite(index)) return null;
  const matches = layout.filter((item) => item.row.kind === "logic" && item.row.channel === index && !state.hidden.has(item.row.key));
  if (decoderId) {
    const owned = matches.find((item) => item.row.decoderId === decoderId);
    if (owned) return owned;
  }
  return matches.find((item) => !item.row.decoderId) || matches[0] || null;
}

function dataLineTargets(decoder) {
  const channels = decoder.channels || {};
  const text = annotationLabel;
  if (decoder.protocol === "spi") {
    return [
      { channel: channels.mosi, label: (row) => (row.fields && row.fields.mosi ? "0x" + row.fields.mosi : text(row)) },
      { channel: channels.miso, label: (row) => (row.fields && row.fields.miso ? "0x" + row.fields.miso : text(row)) },
    ];
  }
  if (decoder.protocol === "i2c") return [{ channel: channels.sda, label: text }];
  if (decoder.protocol === "uart") return [{ channel: channels.rx, label: text }];
  if (decoder.protocol === "eeprom24") {
    const parent = (state.decoders || []).find((row) => row.id === decoder.stack_on);
    return [{ channel: parent && parent.channels ? parent.channels.sda : null, decoderId: parent && parent.id, label: text }];
  }
  const first = Object.values(channels)[0];
  return [{ channel: first, label: text }];
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

function drawHexagons(ctx, rows, top, bottom, color, canvasW, labelOf, alpha) {
  const height = Math.max(12, bottom - top);
  let lastLabel = -1;
  ctx.lineWidth = 1.25;
  for (const row of rows) {
    const x0 = sampleX(row.start_sample);
    const x1 = Math.max(x0 + 2, sampleX(row.end_sample));
    if (x1 < 0 || x0 > canvasW) continue;
    const width = x1 - x0;
    traceHexagon(ctx, x0, top, width, height);
    ctx.save();
    ctx.fillStyle = color || "#3d8dfd";
    ctx.globalAlpha = alpha == null ? 0.36 : alpha;
    ctx.fill();
    ctx.globalAlpha = 0.92;
    ctx.strokeStyle = color || "#c6dcff";
    ctx.stroke();
    ctx.restore();
    const label = labelOf(row);
    const point = Math.max(3, Math.min(14, height * 0.42, width * 0.28));
    if (width < point * 2 + 20 || x0 < lastLabel) continue;
    ctx.save();
    ctx.beginPath();
    ctx.rect(x0 + point, top, Math.max(0, width - point * 2), height);
    ctx.clip();
    ctx.fillStyle = "#f7fafc";
    ctx.fillText(label, x0 + point + 4, top + height / 2);
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
    if (decoderCondensed(decoder.id) || !overlayEnabled(decoder.id)) continue;
    for (const target of dataLineTargets(decoder)) {
      const item = logicRow(layout, target.channel, target.decoderId || decoder.id);
      if (!item) continue;
      const pad = Math.max(8, item.height * 0.22);
      drawHexagons(ctx, rows, item.top + pad, item.top + item.height - pad, item.row.color, canvasW, target.label);
    }
  }
  ctx.restore();
}

function annotationNumbers(row) {
  const fields = row.fields || {};
  if (row.protocol === "spi" && (fields.mosi || fields.miso)) {
    const out = [];
    if (fields.mosi) out.push(parseInt(fields.mosi, 16));
    if (fields.miso) out.push(parseInt(fields.miso, 16));
    return out.filter((value) => Number.isFinite(value));
  }
  if (fields.data) return [parseInt(fields.data, 16)].filter((value) => Number.isFinite(value));
  if (fields.address) return [parseInt(fields.address, 16)].filter((value) => Number.isFinite(value));
  return [];
}

function formatDecoded(value, format) {
  const n = value & 0xff;
  if (format === "dec") return String(n);
  if (format === "bin") return n.toString(2).padStart(8, "0");
  if (format === "oct") return n.toString(8);
  return "0x" + n.toString(16).toUpperCase().padStart(2, "0");
}

function condensedLabel(row, format) {
  const parts = annotationNumbers(row).map((value) => formatDecoded(value, format));
  return parts.length ? parts.join(" / ") : annotationLabel(row);
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
    const rows = valueAnnotations(decoder);
    const format = item.row.bus && item.row.bus.analog ? "analog" : decodeFormat(decoder.id);
    const pad = Math.max(8, item.height * 0.22);
    const bandTop = item.top + pad;
    const bandBot = item.top + item.height - pad;
    if (format === "analog") {
      const fields = rows[0] && rows[0].fields;
      if (fields && (fields.mosi || fields.miso)) {
        drawStepSeries(ctx, rows, bandTop, bandBot, "#ff6b8a", (row) => parseInt((row.fields || {}).mosi, 16));
        drawStepSeries(ctx, rows, bandTop, bandBot, "#7dcea0", (row) => parseInt((row.fields || {}).miso, 16));
      } else {
        drawStepSeries(ctx, rows, bandTop, bandBot, "#8eb6ff", (row) => {
          const values = annotationNumbers(row);
          return values.length ? values[0] : NaN;
        });
      }
      ctx.fillStyle = "rgba(176, 188, 204, 0.7)";
      ctx.font = "10px sans-serif";
      ctx.textAlign = "left";
      ctx.textBaseline = "middle";
      ctx.fillText("255", 6, bandTop + 8);
      ctx.fillText("0", 6, bandBot - 6);
      continue;
    }
    const hexH = Math.min(48, Math.max(16, bandBot - bandTop));
    const mid = (bandTop + bandBot) / 2;
    drawHexagons(ctx, rows, mid - hexH / 2, mid + hexH / 2, item.row.color, canvasW, (row) => condensedLabel(row, format), 0.82);
  }
}

function spiWords(decoderId) {
  return (state.annotations || []).filter((row) => row.decoder === decoderId && row.class === "word" && row.fields);
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

function busValueAt(bus, index) {
  let value = 0;
  for (let bit = 0; bit < bus.channels.length; bit++) {
    const cols = state.tiles["logic:" + bus.channels[bit]];
    const column = cols && cols[index];
    if (column && column.valid !== false && column.last) value |= 1 << bit;
  }
  return value;
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
    stroke("mosi", "#ff6b8a");
    stroke("miso", "#7dcea0");
    return;
  }
  ctx.font = "12px sans-serif";
  ctx.textBaseline = "middle";
  ctx.fillStyle = "#d5deea";
  let lastX = -80;
  for (const word of words) {
    const x = sampleX(word.start_sample);
    if (x < -8 || x - lastX < 72) continue;
    const label = "0x" + (word.fields.mosi || "00") + "/0x" + (word.fields.miso || "00");
    ctx.fillText(label, x + 4, (top + bot) / 2);
    lastX = x;
  }
}

function drawBuses(ctx, layout) {
  for (const item of layout) {
    const row = item.row;
    if (row.kind !== "bus" || state.hidden.has(row.key)) continue;
    const bus = row.bus;
    if (bus.decode) {
      drawDecodeBus(ctx, item, bus);
      continue;
    }
    const cols = state.tiles["logic:" + bus.channels[0]];
    if (!cols) continue;
    const pad = Math.max(8, item.height * 0.22);
    const top = item.top + pad;
    const bot = item.top + item.height - pad;
    const max = Math.max(1, (1 << bus.channels.length) - 1);
    if (bus.analog) {
      ctx.beginPath();
      ctx.strokeStyle = "#7dcea0";
      ctx.lineWidth = 1.4;
      let started = false;
      for (let i = 0; i < cols.length; i++) {
        if (tileSample(i) >= state.total) break;
        const y = bot - (busValueAt(bus, i) / max) * (bot - top);
        const x = traceX(i);
        if (!started) {
          ctx.moveTo(x, y);
          started = true;
        } else ctx.lineTo(x, y);
      }
      ctx.stroke();
      continue;
    }
    ctx.font = "12px sans-serif";
    ctx.textBaseline = "middle";
    ctx.fillStyle = "#d5deea";
    let prev = null;
    let lastX = -100;
    for (let i = 0; i < cols.length; i++) {
      if (tileSample(i) >= state.total) break;
      const value = busValueAt(bus, i);
      const x = traceX(i);
      if (prev == null) prev = value;
      if (value !== prev || i === 0) {
        if (x - lastX > 36) {
          ctx.fillText("0x" + value.toString(16).toUpperCase(), x + 4, (top + bot) / 2);
          lastX = x;
        }
        prev = value;
      }
    }
  }
}

function drawOverview() {
  const { ctx, w, h } = prep(overview);
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "#10151c";
  ctx.fillRect(0, 0, w, h);
  const cols = state.overviewCols;
  if (cols && state.total > 0) {
    ctx.strokeStyle = "#3dcc8e";
    ctx.beginPath();
    let moved = false;
    for (let i = 0; i < cols.length; i++) {
      const column = cols[i];
      if (!column || column.valid === false) break;
      const x = (i + 0.5) * (w / cols.length);
      const y = column.toggled || column.first ? 6 : h - 6;
      if (!moved) {
        ctx.moveTo(x, y);
        moved = true;
      } else ctx.lineTo(x, y);
      if (column.toggled) {
        ctx.lineTo(x, 6);
        ctx.lineTo(x, h - 6);
      }
    }
    ctx.stroke();
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
  for (const row of visibleRows()) {
    if (row.kind !== "logic" && row.kind !== "analog") continue;
    const key = row.tileKey || row.key;
    if (seen.has(key)) continue;
    seen.add(key);
    rows.push({ row, key });
  }
  return rows;
}

async function fetchTiles() {
  const requests = tileRequests();
  const width = Math.max(1, Math.floor(wave.clientWidth || 1));
  const v = view();
  const req = ++state.req;
  const spp = Math.max(v.spp, 1e-9);
  const start = v.start;
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
  const sameView = now.start === start
    && now.spp === spp
    && Math.max(1, Math.floor(wave.clientWidth || 1)) === width;
  if (!sameView) {
    tileAgain = true;
    return;
  }
  if (Object.keys(pending.got).length) {
    const previous = state.tileView;
    const sameTileView = previous
      && previous.start === start
      && previous.spp === spp
      && previous.width === width;
    state.tiles = sameTileView ? Object.assign({}, state.tiles, pending.got) : pending.got;
    state.tileView = { start, spp, width };
    drawWave();
    drawRuler();
  }
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
async function refreshOverview() {
  const token = ++overviewToken;
  if (state.total <= 0) {
    state.overviewCols = null;
    drawOverview();
    return;
  }
  const columns = Math.max(8, Math.floor(overview.clientWidth || 200));
  try {
    const data = await api({
      cmd: "tile",
      session: state.active,
      channel: 0,
      start: 0,
      columns,
      samples_per_pixel: state.total / columns,
      kind: "logic",
    });
    if (token !== overviewToken) return;
    state.overviewCols = data.columns;
    drawOverview();
  } catch (_) {
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
  state.gutterSig = "";
  const status = await api({ cmd: "status", session: id });
  applyStatus(status, false);
  await refreshSessions();
  if (state.tab === "cursors" || state.tab === "measure") selectTab(state.tab);
}

async function addSession() {
  const created = await api({ cmd: "create_session" });
  await selectSession(created.id);
}

async function runCapture() {
  if (commandBusy || isLive(state.phase)) return;
  commandBusy = true;
  paintStatus();
  try {
    view().userNavigated = false;
    state.planned = Math.floor(settings.rate * settings.duration / 1000);
    state.planned -= state.planned % 64;
    const status = await api({
      cmd: "configure",
      session: state.active,
      sample_rate_hz: settings.rate,
      duration_ms: settings.duration,
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
    statusEl.textContent = err.message;
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
  if (name === "decode") {
    const query = escapeHtml(state.decodeQuery || "");
    return `<h2>Decode</h2>
      <label class="field">Protocol
        <select id="decoder-kind">
          <option value="i2c">I2C</option>
          <option value="spi">SPI</option>
          <option value="uart">UART</option>
          <option value="eeprom24">EEPROM 24xx on I2C</option>
        </select>
      </label>
      <button class="block" id="add-decoder" type="button">Add decoder</button>
      <ul id="decoder-list" class="decoder-list"></ul>
      <label class="field">Search
        <input id="decode-search" type="search" placeholder="MOSI, 0xA5, or address" value="${query}" aria-label="Search decoded rows">
      </label>
      <div id="decode-table" class="decode-scroll"></div>
      <p class="hint">Select a decoder to show its table. The gear sets each signal’s channel and the mode. Each decoder is a bus row with its waveform channels underneath. The arrow beside the decoder name folds those channels into the bus, or shows them again. The eye hides that row’s waveform. Overlay draws decoded values on the data lines while the waveforms are visible. A channel used by two decoders appears in each group.</p>`;
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
    return `<h2>Export</h2>
      <button class="block" id="export-csv" type="button">Save CSV…</button>
      <button class="block" id="export-xlsx" type="button">Save Excel…</button>
      <button class="block" id="download" type="button">Save .lvcap…</button>
      <button class="block" id="download-dsl" type="button">Save .dsl…</button>
      <button class="block" id="export-ann" type="button">Export annotations</button>
      <p class="hint">Saving a capture asks where to put the file. CSV and Excel list one row per sample: time and logic levels. A capture longer than Excel's row limit is cut off. Firmware stays outside this repo.</p>`;
  }
  return `<h2>Measure</h2>
    <p id="measure-readout">${state.hoverText || "Hover a logic trace, or drag a measurement on the waveform."}</p>
    <button class="block" id="keep-measure" type="button">Keep hovered pulse</button>
    <h3>Drag measurements</h3>
    <div id="span-list"></div>
    <h3>Saved pulses</h3>
    <div id="saved-measures"></div>`;
}

function devicePanel() {
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
  const devices = state.devices || [];
  const title = devices.map((device) => device.name).join(" + ") || settings.deviceName || "Demo";
  const hardware = devices.some((device) => device.kind === "usb");
  const logic = state.channels.map((channel) => channel.name).join(", ") || "—";
  const analog = state.analog.length
    ? state.analog.map((channel) => channel.name).join(", ")
    : "none";
  const source = state.channels.map((channel) => `<option value="${channel.index}">${channel.name}</option>`).join("");
  const analogRow = state.analog.length
    ? `<div class="acq-row"><span>Analog channels</span><span class="value">${state.analog.length} · ${analog}</span></div>`
    : "";
  return `<h2>Device</h2>
    <button type="button" class="device-card" id="device-card">
      <svg class="pod" viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="6" width="18" height="12" rx="2"></rect><path d="M7 6V4M12 6V4M17 6V4M7 20v-2M12 20v-2M17 20v-2"></path></svg>
      <div>
        <strong>${title}</strong>
        <span class="connected"><i class="dot"></i> Connected</span>
        <p class="hint">${hardware ? "Opened pod. The name is the one the engine reports." : "Software demo. No pod serial number."}</p>
      </div>
    </button>
    <p id="plugged-in" class="hint">Looking for a DreamSourceLab pod.</p>
    <p id="profile-note" class="hint">Choose the source from the device menu. A plugged-in pod is listed above the demo devices. Demo and Demo SPI can be stacked. Untested product ids stay closed.</p>
    <h3>Acquisition</h3>
    <label class="acq-row">Sample rate
      <select id="set-rate" aria-label="Sample rate">${rateOptionsHtml()}</select>
    </label>
    <p id="rate-note" class="hint">${rateNote()}</p>
    <label class="acq-row">Length
      <select id="set-duration" aria-label="Capture length">
        <option value="10">10 ms</option>
        <option value="100">100 ms</option>
        <option value="1000">1.0 s</option>
        <option value="2000">2.0 s</option>
        <option value="5000">5.0 s</option>
      </select>
    </label>
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
    <h3>Trigger</h3>
    <label class="acq-row">Source
      <select id="panel-trig-channel" aria-label="Trigger source">${source}</select>
    </label>
    <label class="acq-row">Type
      <select id="panel-trig-edge" aria-label="Trigger type">
        <option value="rising">Rising edge</option>
        <option value="falling">Falling edge</option>
        <option value="high">High</option>
        <option value="low">Low</option>
      </select>
    </label>
    <label class="acq-row">Position
      <span>
        <input id="set-position" type="range" min="0" max="90" step="10" aria-label="Pre-trigger position">
        <span id="set-position-label"></span>
      </span>
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
      <h3>Trigger sequence</h3>
      <p class="hint">A sequence replaces the toolbar edge. Steps run in order and the mark is the last one. Each step is one arm-record stage, up to 16.</p>
      <div id="trigger-steps">${steps}</div>
      <button class="block" id="add-step" type="button"${settings.triggerSteps.length >= 16 ? " disabled" : ""}>Add edge step</button>
    </details>`;
}

function channelChecks(probes) {
  const groups = [];
  for (let i = 0; i < probes.length; i += 8) groups.push(probes.slice(i, i + 8));
  if (!groups.length) return "";
  if (state.channelGroup >= groups.length) state.channelGroup = 0;
  const tabs = groups.map((group, index) => {
    const from = index * 8;
    const to = from + group.length - 1;
    return `<button type="button" class="ch-tab${index === state.channelGroup ? " active" : ""}" data-group="${index}">${from}–${to}</button>`;
  }).join("");
  const buttons = groups[state.channelGroup].map((probe) => {
    const on = channelIsEnabled(probe.index);
    const color = storedColor("logic:" + probe.index, probe.color || "#8eb6ff");
    return `<button type="button" class="ch-en${on ? " on" : ""}" data-bit="${probe.index}" style="--ch:${color}" aria-label="Channel ${probe.index}">${probe.index}</button>`;
  }).join("");
  return `<div class="ch-tabs">${tabs}</div><div class="ch-enables">${buttons}</div>`;
}

function bindPanel(name) {
  if (name === "device") {
    loadDeviceChoices();
    bindSelect("set-rate", "rate", true);
    bindSelect("set-duration", "duration", true);
    bindSelect("set-depth", "depth", false);
    const depth = document.getElementById("set-depth");
    if (depth) {
      depth.addEventListener("change", () => {
        clampSampleRate();
        refillRateSelect();
      });
    }
    bindSelect("set-run", "run", false);
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
    const source = document.getElementById("panel-trig-channel");
    const edge = document.getElementById("panel-trig-edge");
    const position = document.getElementById("set-position");
    const positionLabel = document.getElementById("set-position-label");
    source.value = String(settings.triggerChannel);
    edge.value = settings.triggerKind;
    position.value = String(settings.percent);
    positionLabel.textContent = settings.percent + "%";
    source.addEventListener("change", () => {
      settings.triggerChannel = Number(source.value);
      const toolbar = document.getElementById("trig-channel");
      if (toolbar) toolbar.value = source.value;
    });
    edge.addEventListener("change", () => {
      settings.triggerKind = edge.value;
      const toolbar = document.getElementById("trig-edge");
      if (toolbar) toolbar.value = edge.value;
    });
    position.addEventListener("input", () => {
      settings.percent = Number(position.value);
      positionLabel.textContent = settings.percent + "%";
      const toolbar = document.getElementById("trig-percent");
      if (toolbar) toolbar.value = String(settings.percent);
    });
    const card = document.getElementById("device-card");
    if (card) card.addEventListener("click", () => openDeviceMenu(card));
    for (const tab of document.querySelectorAll("#channel-enable .ch-tab")) {
      tab.addEventListener("click", () => {
        state.channelGroup = Number(tab.dataset.group);
        selectTab("device");
      });
    }
    const sampleButtons = [...document.querySelectorAll("#channel-enable .ch-en")];
    const writeSampleMask = () => {
      const probes = state.probes.length ? state.probes : state.channels;
      const on = probes.filter((probe) => channelIsEnabled(probe.index));
      if (on.length === probes.length) settings.channelEnable = 0;
      else {
        let mask = 0;
        for (const probe of on) mask |= 1 << probe.index;
        settings.channelEnable = mask || 1;
      }
    };
    for (const button of sampleButtons) {
      button.addEventListener("click", () => {
        const bit = Number(button.dataset.bit);
        const probes = state.probes.length ? state.probes : state.channels;
        const enabled = probes.filter((probe) => channelIsEnabled(probe.index));
        const isOn = channelIsEnabled(bit);
        if (isOn && enabled.length <= 1) return;
        if (settings.channelEnable === 0) {
          let mask = 0;
          for (const probe of probes) mask |= 1 << probe.index;
          settings.channelEnable = mask;
        }
        if (isOn) settings.channelEnable &= ~(1 << bit);
        else settings.channelEnable |= 1 << bit;
        writeSampleMask();
        clampSampleRate();
        state.gutterSig = "";
        renderGutter();
        scheduleTiles();
        drawWave();
        selectTab("device");
      });
    }
    bindCheck("set-rle", "rle");
    bindCheck("set-filter", "filter");
    bindCheck("set-ext", "extClock");
    bindCheck("set-fall", "clockFalling");
    bindCheck("set-discard", "discard");
    document.getElementById("add-step").addEventListener("click", () => {
      const next = settings.triggerSteps.length === 0 ? 1 : settings.triggerSteps.length === 1 ? 3 : 0;
      settings.triggerSteps.push({ channel: next, rising: true });
      settings.trigger = true;
      const box = document.getElementById("trig-enable");
      if (box) box.checked = true;
      selectTab("device");
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
        selectTab("device");
      });
    }
  }
  if (name === "decode") {
    document.getElementById("add-decoder").addEventListener("click", addDecoder);
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
  if (name === "export") {
    document.getElementById("export-csv").addEventListener("click", () => saveCaptureExport("csv"));
    document.getElementById("export-xlsx").addEventListener("click", () => saveCaptureExport("xlsx"));
    document.getElementById("download").addEventListener("click", () => saveCaptureExport("lvcap"));
    document.getElementById("download-dsl").addEventListener("click", () => saveCaptureExport("dsl"));
    document.getElementById("export-ann").addEventListener("click", exportAnnotations);
  }
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
    const bands = stream ? profile.stream_rates : profile.buffer_rates;
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

function legalSampleRates() {
  const channels = enabledChannelCount();
  const max = maxSampleHz(activeRateBands(), channels);
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

function openDeviceMenu(anchor) {
  const menu = document.getElementById("device-menu");
  if (!menu) return;
  if (!menu.classList.contains("hidden")) {
    closeDeviceMenu();
    return;
  }
  renderDeviceMenu();
  menu.classList.remove("hidden");
  const rect = anchor.getBoundingClientRect();
  const below = rect.bottom + 6;
  menu.style.left = Math.max(8, rect.left) + "px";
  menu.style.top = below + "px";
  placeDeviceSubmenu();
}

function placeDeviceSubmenu() {
  const menu = document.getElementById("device-menu");
  const row = menu && menu.querySelector(".device-sub");
  if (!row) return;
  const rect = menu.getBoundingClientRect();
  row.classList.toggle("flip", rect.right + 196 > window.innerWidth);
}

async function loadDeviceChoices() {
  try {
    const devices = await api({ cmd: "list_devices" });
    state.deviceList = devices;
    const hardware = devices.filter((device) => device.kind !== "demo");
    const plugged = document.getElementById("plugged-in");
    if (plugged) {
      plugged.textContent = hardware.length
        ? `Plugged in: ${hardware.map((device) => device.name).join(", ")}. Pick it in the device menu to capture.`
        : "No DreamSourceLab pod is plugged in.";
    }
    syncDeviceSelect();
    api({ cmd: "list_profiles" }).then((profiles) => {
      state.profiles = profiles;
      const note = document.getElementById("profile-note");
      if (note) {
        const untested = profiles.filter((profile) => !profile.hardware_tested).length;
        const tested = profiles.filter((profile) => profile.hardware_tested).map((profile) => profile.name);
        note.textContent = `${tested.join(", ") || "No pod"} tested on hardware. ${untested} other logic product ids stay closed.`;
      }
      if (state.tab === "device") refillRateSelect();
    }).catch(() => {});
  } catch (err) {
    statusEl.textContent = err.message;
  }
}

async function applyDeviceChoice(value) {
  const ids = value.split("+").filter(Boolean);
  if (!ids.length) return;
  try {
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
  }
}

async function useDevice(id) {
  const connected = await api({ cmd: "connect", id });
  settings.device = connected.id;
  settings.deviceName = connected.name;
  const status = await api({ cmd: "status", session: state.active });
  state.gutterSig = "";
  applyStatus(status, false);
}

function decoderChannels(protocol) {
  if (protocol === "i2c") return { scl: "SCL", sda: "SDA" };
  if (protocol === "spi") {
    const prefix = state.channels.some((channel) => channel.device_id === "demo:spi") ? "demo:spi/" : "";
    return { sck: prefix + "SCK", mosi: prefix + "MOSI", miso: prefix + "MISO", cs: prefix + "CS" };
  }
  if (protocol === "uart") return { rx: "UART" };
  return {};
}

const PROTOCOL_LABEL = { i2c: "I2C", spi: "SPI", uart: "UART", eeprom24: "EEPROM 24xx" };
const GEAR_ICON = `<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="3"></circle><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M18.4 5.6L17 7M7 17l-1.4 1.4"></path></svg>`;
const TRASH_ICON = `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M9 7V5h6v2M8 7l1 13h6l1-13"></path></svg>`;

function escapeHtml(text) {
  return String(text).replace(/[&<>"']/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" })[ch]);
}

function protocolLabel(protocol) {
  return PROTOCOL_LABEL[protocol] || protocol;
}

async function addDecoder() {
  const protocol = document.getElementById("decoder-kind").value;
  try {
    const created = await api({
      cmd: "add_decoder",
      session: state.active,
      protocol,
      channels: decoderChannels(protocol),
    });
    state.selectedDecoder = created.id;
    await refreshDecoders();
    await loadAnnotations();
  } catch (err) {
    statusEl.textContent = err.message;
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
  return layout[layout.length - 1].row;
}

function boundaryAt(clientY) {
  const rect = wave.getBoundingClientRect();
  const y = clientY - rect.top;
  const { layout } = rowMetrics();
  for (let index = 0; index < layout.length - 1; index++) {
    const edge = layout[index].top + layout[index].height;
    if (Math.abs(y - edge) <= 4) return layout[index].row.key;
  }
  return null;
}

function placeEdgeButtons(clientY) {
  state.edgePointerY = clientY;
  const prev = document.getElementById("edge-prev");
  const next = document.getElementById("edge-next");
  const stage = document.querySelector(".wave-stage");
  const row = rowAt(clientY);
  if (!prev || !next || !stage || !row || row.kind !== "logic" || state.total <= 0) {
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
  prev.style.top = mid + "px";
  next.style.top = mid + "px";
  prev.classList.remove("hidden");
  next.classList.remove("hidden");
}

function hideEdgeButtons() {
  state.edgeChannel = null;
  document.getElementById("edge-prev")?.classList.add("hidden");
  document.getElementById("edge-next")?.classList.add("hidden");
}

function activeLogicChannel() {
  if (state.hoverKey && state.hoverKey.startsWith("logic:")) return state.hoverChannel;
  const selected = view().selected;
  const rows = orderedRows();
  const chosen = rows.find((row) => row.key === selected && row.kind === "logic");
  if (chosen) return chosen.channel;
  const first = rows.find((row) => row.kind === "logic");
  return first ? first.channel : 0;
}

async function exportAnnotations() {
  try {
    const query = (state.decodeQuery || "").trim();
    const data = await api({
      cmd: "export_annotations",
      session: state.active,
      format: "csv",
      query: query || null,
    });
    const blob = new Blob([data], { type: "text/csv" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = "annotations.csv";
    link.click();
    URL.revokeObjectURL(link.href);
  } catch (err) {
    statusEl.textContent = err.message;
  }
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

function saveCaptureExport(kind) {
  const spec = SAVE_KINDS[kind];
  if (!spec) return;
  openSaveDialog({
    title: spec.title,
    note: spec.note,
    filename: spec.filename,
    ext: spec.ext,
    mime: spec.mime,
    picker: spec.picker,
    produce: () => fetchCaptureBlob(spec.path),
  });
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
    selected: v.selected || null,
    colors: v.colors || {},
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

function saveSetup() {
  openSaveDialog({
    title: "Save setup",
    note: "Channel layout, colors, cursors, and decoders. This file does not include samples.",
    filename: "setup.lvsetup",
    ext: ".lvsetup",
    mime: "application/json",
    picker: { description: "LogicView setup", accept: { "application/json": [".lvsetup", ".json"] } },
    produce: () => JSON.stringify(setupDocument(), null, 2),
  });
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
  v.buses = Array.isArray(doc.buses) ? doc.buses : [];
  v.nextBus = Number(doc.nextBus) || v.nextBus || 1;
  v.selected = doc.selected || null;
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
  state.tiles = {};
  state.annotations = [];
  state.decoders = [];
  state.selectedDecoder = null;
  state.decodeView = {};
  view().userNavigated = false;
  state.gutterSig = "";
  applyStatus(json.data, false);
  await refreshDecoders();
  await loadAnnotations();
  const count = Number(json.data.sample_count || 0).toLocaleString();
  statusEl.textContent = `opened ${file.name} · ${count} samples`;
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
    if (ev.target.closest && ev.target.closest(".wave-stage")) return;
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
    statusEl.textContent = msg.message;
    renderChrome();
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
  if (!row || (row.kind !== "bus" && row.kind !== "decode") || !row.bus) return;
  ev.preventDefault();
  openBusMenu(row.bus, ev.clientX, ev.clientY);
});

wave.addEventListener("wheel", (ev) => {
  ev.preventDefault();
  if (state.total <= 0) return;
  stepZoom(ev.deltaY > 0);
}, { passive: false });

function currentTimebaseIndex() {
  syncTimebaseLabel();
  const slider = document.getElementById("timebase");
  const index = slider ? Number(slider.value) : 0;
  if (!Number.isInteger(index) || index < 0 || index >= TIME_DIVS.length) return 0;
  return index;
}

function stepZoom(out) {
  const slider = document.getElementById("timebase");
  if (!slider || state.total <= 0) return;
  const current = currentTimebaseIndex();
  const next = Math.max(0, Math.min(TIME_DIVS.length - 1, current + (out ? 1 : -1)));
  if (next === current) return;
  slider.value = String(next);
  applyTimebase(next);
  drawWave();
}

function zoomAt(sample, x, factor) {
  const v = view();
  const width = Math.max(1, wave.clientWidth);
  const minSpp = 1 / 32;
  const maxSpp = Math.max(minSpp, (Math.max(state.total, 1) / width) * 4);
  const before = v.spp;
  v.spp = Math.min(maxSpp, Math.max(minSpp, before * factor));
  if (v.spp === before) return;
  v.start = sample - x * v.spp;
  v.userNavigated = true;
  clampView();
  scheduleTiles();
  drawWave();
  drawRuler();
  drawOverview();
  syncTimebaseLabel();
}

wave.addEventListener("pointerdown", (ev) => {
  if (ev.button !== 0) return;
  const boundary = state.total > 0 ? boundaryAt(ev.clientY) : null;
  if (boundary && state.tool !== "marker" && state.tool !== "measure") {
    startRowResize(boundary, ev.clientY);
    return;
  }
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
    const sample = sampleAt(ev.clientX);
    const row = rowAt(ev.clientY);
    pointer = {
      kind: "measure",
      a: sample,
      b: sample,
      x: ev.clientX,
      channel: row && row.kind === "logic" ? row.channel : activeLogicChannel(),
    };
    wave.setPointerCapture(ev.pointerId);
    drawWave();
    return;
  }
  pointer = { kind: "pan", x: ev.clientX, start: view().start };
  wave.setPointerCapture(ev.pointerId);
});

wave.addEventListener("pointermove", (ev) => {
  const rect = wave.getBoundingClientRect();
  state.hoverX = ev.clientX - rect.left;
  if (pointer && pointer.kind === "pan") {
    const v = view();
    v.start = pointer.start - (ev.clientX - pointer.x) * v.spp;
    v.userNavigated = true;
    clampView();
    scheduleTiles();
    drawRuler();
    drawOverview();
    hideHover();
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
    pointer.b = sampleAt(ev.clientX);
    drawWave();
    const seconds = Math.abs(pointer.b - pointer.a) / Math.max(1, state.rate);
    showHover(ev, `measurement ${formatSeconds(seconds)}`, `<b>Measurement</b><br>${formatSeconds(seconds)}<br>${Math.abs(pointer.b - pointer.a)} samples`);
    return;
  }
  placeEdgeButtons(ev.clientY);
  queueHover(ev);
  drawWave();
});

wave.addEventListener("pointerup", async (ev) => {
  const active = pointer;
  pointer = null;
  if (!active) return;
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
  if (!pointer) {
    state.hoverX = null;
    state.hoverKey = null;
    hideHover();
    drawWave();
  }
});

overview.addEventListener("pointerdown", (ev) => {
  if (state.total <= 0) return;
  const rect = overview.getBoundingClientRect();
  const x = ev.clientX - rect.left;
  const v = view();
  const span = wave.clientWidth * v.spp;
  v.start = (x / rect.width) * state.total - span / 2;
  v.userNavigated = true;
  clampView();
  scheduleTiles();
  drawOverview();
});

function queueHover(ev) {
  state.hoverEvent = { clientX: ev.clientX, clientY: ev.clientY };
  if (hoverTimer) return;
  hoverTimer = setTimeout(() => {
    hoverTimer = null;
    const current = state.hoverEvent;
    if (current) runHover(current);
  }, 40);
}

async function runHover(ev) {
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
  const sample = Math.min(state.total - 1, Math.max(0, Math.floor(view().start + x * view().spp)));
  state.hoverKey = row.key;
  if (row.kind === "analog") {
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
    const metrics = await api({ cmd: "measure", session: state.active, channel: row.channel, sample });
    state.hoverChannel = row.channel;
    const level = metrics.level_high ? "high" : "low";
    const width = formatSeconds(metrics.width_secs);
    const period = metrics.period_secs == null ? "—" : formatSeconds(metrics.period_secs);
    const freq = formatHz(metrics.frequency_hz);
    const duty = metrics.duty == null ? "—" : `${(metrics.duty * 100).toFixed(1)}%`;
    state.lastMeasure = { channel: row.channel, sample };
    const line = `${row.name} ${level} · width ${width} · period ${period} · ${freq} · duty ${duty}`;
    const html = `<b style="color:${row.color}">${row.name}</b> <span class="muted">${level}</span><br>Width ${width}<br>Period ${period}<br>${freq} · duty ${duty}`;
    showHover(ev, line, html);
    const readout = document.getElementById("measure-readout");
    if (readout) readout.textContent = line;
  } catch (_) {
    hideHover();
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
  if (!state.hoverText && hoverEl.classList.contains("hidden")) return;
  state.hoverText = "";
  hoverEl.classList.add("hidden");
  paintStatus();
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
  label.textContent = formatDiv(TIME_DIVS[Number(slider.value)]);
}

function formatDiv(seconds) {
  return formatSeconds(seconds).replace(/\.000(?=\s)/, "") + "/div";
}

function applyTimebase(index) {
  if (!Number.isInteger(index) || index < 0 || index >= TIME_DIVS.length) return;
  const seconds = TIME_DIVS[index];
  const px = Math.max(40, (wave.clientWidth || 800) / 10);
  const v = view();
  const width = Math.max(1, wave.clientWidth);
  const mid = v.start + (width / 2) * v.spp;
  v.spp = (seconds * Math.max(1, state.rate)) / px;
  v.start = mid - (width / 2) * v.spp;
  v.userNavigated = true;
  clampView();
  scheduleTiles();
  drawWave();
  drawRuler();
  drawOverview();
  const label = document.getElementById("timebase-label");
  if (label) label.textContent = formatDiv(seconds);
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
    ["Save setup…", () => saveSetup()],
    ["Open setup…", () => document.getElementById("setup-file").click()],
    ["Export CSV…", () => saveCaptureExport("csv")],
    ["Export Excel…", () => saveCaptureExport("xlsx")],
    ["Save .lvcap…", () => saveCaptureExport("lvcap")],
    ["Save .dsl…", () => saveCaptureExport("dsl")],
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
  decode: [["Open decode", () => selectTab("decode")]],
  measure: [["Add measurement", () => setTool("measure")]],
  tools: [
    ["Previous edge", () => stepEdge(false)],
    ["Next edge", () => stepEdge(true)],
    ["Add marker", () => setTool("marker")],
    ["Group channels as a bus", () => openBusDialog()],
  ],
  help: [["About this demo", () => { statusEl.textContent = "LogicView demo source. Run starts a capture. Stop ends it."; }]],
};

function closeMenu() {
  state.menu = null;
  document.getElementById("menu-pop").classList.add("hidden");
  for (const button of document.querySelectorAll(".menubar button")) button.classList.remove("open");
}

function openMenu(button) {
  const name = button.dataset.menu;
  if (state.menu === name) {
    closeMenu();
    return;
  }
  state.menu = name;
  const pop = document.getElementById("menu-pop");
  pop.replaceChildren();
  for (const [label, fn] of MENUS[name]) {
    const item = document.createElement("button");
    item.type = "button";
    item.textContent = label;
    item.addEventListener("click", () => {
      closeMenu();
      fn();
    });
    pop.appendChild(item);
  }
  const rect = button.getBoundingClientRect();
  pop.classList.remove("hidden");
  const width = pop.offsetWidth;
  let left = rect.left;
  if (left + width > window.innerWidth - 8) left = Math.max(8, window.innerWidth - 8 - width);
  pop.style.left = left + "px";
  pop.style.top = rect.bottom + "px";
  for (const other of document.querySelectorAll(".menubar button")) {
    other.classList.toggle("open", other === button);
  }
}

document.getElementById("run").addEventListener("click", () => runCapture());
document.getElementById("stop").addEventListener("click", () => stopCapture());
document.getElementById("tab-add").addEventListener("click", () => addSession());
document.getElementById("device-select").addEventListener("click", (ev) => {
  ev.stopPropagation();
  openDeviceMenu(document.querySelector(".device-chip"));
});
document.getElementById("channel-add").addEventListener("click", () => openSidebar("device"));
document.getElementById("tool-marker").addEventListener("click", () => setTool("marker"));
document.getElementById("tool-measure").addEventListener("click", () => setTool("measure"));
document.getElementById("zoom-in").addEventListener("click", () => stepZoom(false));
document.getElementById("zoom-out").addEventListener("click", () => stepZoom(true));
document.getElementById("edge-prev").addEventListener("click", (ev) => {
  ev.stopPropagation();
  stepEdge(false, state.edgeChannel);
});
document.getElementById("edge-next").addEventListener("click", (ev) => {
  ev.stopPropagation();
  stepEdge(true, state.edgeChannel);
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

const trigEnable = document.getElementById("trig-enable");
const trigEdge = document.getElementById("trig-edge");
const trigChannel = document.getElementById("trig-channel");
const trigPercent = document.getElementById("trig-percent");
trigEnable.checked = settings.trigger;
trigEdge.value = settings.triggerKind;
trigPercent.value = String(settings.percent);
trigEnable.addEventListener("change", () => { settings.trigger = trigEnable.checked; });
trigEdge.addEventListener("change", () => { settings.triggerKind = trigEdge.value; });
trigChannel.addEventListener("change", () => { settings.triggerChannel = Number(trigChannel.value); });
trigPercent.addEventListener("change", () => {
  settings.percent = Number(trigPercent.value);
  const slider = document.getElementById("set-position");
  const label = document.getElementById("set-position-label");
  if (slider) slider.value = trigPercent.value;
  if (label) label.textContent = settings.percent + "%";
});

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
}
document.addEventListener("click", (ev) => {
  if (!ev.target.closest(".menu-pop") && !ev.target.closest(".menubar")) closeMenu();
  if (!ev.target.closest("#device-menu") && !ev.target.closest("#device-select") && !ev.target.closest("#device-card")) {
    closeDeviceMenu();
  }
  if (!ev.target.closest("#bus-menu")) closeBusMenu();
  if (!ev.target.closest("#color-flyout") && !ev.target.closest(".ch .bar")) closeColorFlyout();
});

window.addEventListener("keydown", (ev) => {
  if (ev.target.matches("input, select, textarea")) return;
  const key = ev.key;
  if (key === " " || key === "s" || key === "S") {
    ev.preventDefault();
    if (ev.repeat) return;
    if (isLive(state.phase)) stopCapture();
    else runCapture();
    return;
  }
  if (key === "o" || key === "O") { selectTab("device"); return; }
  if (key === "t" || key === "T") { selectTab("device"); return; }
  if (key === "d" || key === "D") { selectTab("decode"); return; }
  if (key === "m" || key === "M") { selectTab("measure"); return; }
  if (key === "r" || key === "R") {
    ev.preventDefault();
    const search = document.getElementById("decode-search");
    if (search) search.focus();
    return;
  }
  if (key === "Escape") {
    const save = document.getElementById("save-dialog");
    const fly = document.getElementById("color-flyout");
    if (save && !save.classList.contains("hidden")) closeSaveDialog();
    else if (fly && !fly.classList.contains("hidden")) closeColorFlyout();
    else if (state.menu) closeMenu();
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
  let scale = 1e9;
  let unit = "ns";
  if (basis >= 1) {
    scale = 1;
    unit = "s";
  } else if (basis >= 1e-3) {
    scale = 1e3;
    unit = "ms";
  } else if (basis >= 1e-6) {
    scale = 1e6;
    unit = "µs";
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
  return sign + (a * 1e9).toFixed(1) + " ns";
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
  if (state.waitKind === "waiting" && !waiting && (state.phase === "running" || state.phase === "stopped")) {
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
    text.textContent = "Sampling";
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

function openBusDialog() {
  const host = document.getElementById("bus-channels");
  const probes = state.probes.length ? state.probes : state.channels;
  host.replaceChildren();
  for (const probe of probes) {
    const label = document.createElement("label");
    label.className = "check";
    const box = document.createElement("input");
    box.type = "checkbox";
    box.value = String(probe.index);
    label.append(box, document.createTextNode(" " + probe.name));
    host.appendChild(label);
  }
  document.getElementById("bus-name").value = "Bus " + (view().nextBus || 1);
  document.getElementById("bus-dialog").classList.remove("hidden");
}

function closeBusDialog() {
  document.getElementById("bus-dialog").classList.add("hidden");
}

function closeBusMenu() {
  const menu = document.getElementById("bus-menu");
  if (menu) menu.classList.add("hidden");
}

function openBusMenu(bus, x, y) {
  const menu = document.getElementById("bus-menu");
  menu.replaceChildren();
  const item = document.createElement("button");
  item.type = "button";
  item.textContent = bus.analog ? "Hex view" : "Analog view";
  item.addEventListener("click", () => {
    if (bus.decode) {
      const analog = !bus.analog;
      if (!state.spiView[bus.decode]) state.spiView[bus.decode] = { analog: false };
      state.spiView[bus.decode].analog = analog;
      const pref = decodePref(bus.decode);
      if (analog) pref.format = "analog";
      else if (pref.format === "analog") pref.format = "hex";
    } else {
      bus.analog = !bus.analog;
    }
    state.gutterSig = "";
    closeBusMenu();
    renderGutter();
    drawWave();
  });
  menu.append(item);
  if (!bus.decode) {
    const remove = document.createElement("button");
    remove.type = "button";
    remove.textContent = "Remove bus";
    remove.addEventListener("click", () => {
      view().buses = view().buses.filter((entry) => entry.id !== bus.id);
      state.gutterSig = "";
      closeBusMenu();
      renderGutter();
      drawWave();
    });
    menu.append(remove);
  }
  menu.classList.remove("hidden");
  menu.style.left = x + "px";
  menu.style.top = y + "px";
}

function channelSpec(channel) {
  return channel.device_id ? channel.device_id + "/" + channel.name : channel.name;
}

function channelOptions(selectedIndex) {
  return state.channels.map((channel) => {
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
  if (Object.keys(channels).length) {
    const format = decodeFormat(decoder.id);
    const options = Object.entries(DECODE_FORMATS).map(([value, label]) => `<option value="${value}"${format === value ? " selected" : ""}>${label}</option>`).join("");
    parts.push(`<label class="check"><input id="decode-condense" type="checkbox"${pref.condensed ? " checked" : ""}> Hide channels under this decoder</label>
      <label class="field">Decoded data
        <select id="decode-format">${options}</select>
      </label>`);
  }
  parts.push(...Object.keys(channels).map((name) => signalField(name, channels[name])));
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
  } else if (decoder.protocol === "eeprom24") {
    const parents = state.decoders.filter((row) => row.protocol === "i2c");
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

async function boot() {
  await refreshSessions();
  const listed = await api({ cmd: "list_sessions" });
  state.active = listed.active;
  state.sessions = listed.sessions;
  const status = await api({ cmd: "status" });
  applyStatus(status, false);
  selectTab("device");
  loadDeviceChoices();
  connectSocket();
  drawWave();
  syncTimebaseLabel();
}

fillColorSwatches();
bindCaptureDrop();
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
document.getElementById("bus-form").addEventListener("submit", (ev) => {
  ev.preventDefault();
  const channels = [...document.querySelectorAll("#bus-channels input:checked")].map((box) => Number(box.value));
  if (channels.length < 2) {
    statusEl.textContent = "A bus needs at least two channels";
    return;
  }
  const v = view();
  const name = document.getElementById("bus-name").value.trim() || ("Bus " + v.nextBus);
  v.buses.push({ id: v.nextBus, name, channels, analog: false });
  v.nextBus += 1;
  state.gutterSig = "";
  closeBusDialog();
  renderGutter();
  drawWave();
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
  const stack = document.getElementById("decode-stack");
  const overlayBox = document.getElementById("decode-overlay");
  const condenseBox = document.getElementById("decode-condense");
  const formatBox = document.getElementById("decode-format");
  const pref = decodePref(id);
  if (overlayBox) pref.overlay = overlayBox.checked;
  if (condenseBox) pref.condensed = condenseBox.checked;
  if (formatBox && DECODE_FORMATS[formatBox.value]) pref.format = formatBox.value;
  state.gutterSig = "";
  try {
    await api({
      cmd: "update_decoder",
      session: state.active,
      id,
      channels,
      options,
      stack_on: stack ? stack.value : null,
    });
    closeDecodeConfig();
    await refreshDecoders();
    await loadAnnotations();
    scheduleTiles();
  } catch (err) {
    statusEl.textContent = err.message;
  }
});

boot().catch((err) => {
  statusEl.textContent = err.message;
});
