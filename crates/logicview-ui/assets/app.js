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
  annotations: [],
  tableTab: "decoded",
  gutterSig: "",
  nextMarker: 1,
  nextMeasure: 1,
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
    try {
      const raw = sessionStorage.getItem("lv-order:" + id);
      if (raw) order = JSON.parse(raw);
    } catch (_) { /* keep the natural order */ }
    views[id] = {
      start: 0,
      spp: 1,
      userNavigated: false,
      order,
      markers: [],
      measures: [],
      selected: null,
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

function naturalRows() {
  const rows = [];
  for (const channel of state.channels) {
    rows.push({
      key: "logic:" + channel.index,
      kind: "logic",
      channel: channel.index,
      name: channel.name,
      color: channel.color,
      device: channel.device_name || "",
    });
  }
  for (const channel of state.analog) {
    rows.push({
      key: "analog:" + channel.index,
      kind: "analog",
      channel: channel.index,
      name: channel.name,
      color: channel.color,
      device: "",
    });
  }
  return rows;
}

function orderedRows() {
  const rows = naturalRows();
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

function visibleRows() {
  return orderedRows().filter((row) => !state.hidden.has(row.key));
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
  if (status.analog) state.analog = status.analog;
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

function renderGutter() {
  const rows = orderedRows();
  const selected = view().selected;
  const sig = rows.map((row) => row.key + row.color + (state.hidden.has(row.key) ? "0" : "1") + (row.key === selected ? "s" : "")).join("|");
  if (sig === state.gutterSig) return;
  state.gutterSig = sig;
  gutter.replaceChildren();
  for (const row of rows) {
    const el = document.createElement("div");
    el.className = "ch" + (row.key === selected ? " selected" : "") + (state.hidden.has(row.key) ? " dim" : "");
    el.dataset.key = row.key;
    el.title = row.device ? `${row.name} · ${row.device} · drag to reorder` : "Drag to reorder";
    const bar = document.createElement("span");
    bar.className = "bar";
    bar.style.background = row.color;
    const name = document.createElement("span");
    name.className = "name";
    name.textContent = row.name;
    name.style.color = row.color;
    const kind = document.createElement("span");
    kind.className = "kind";
    kind.textContent = row.kind === "analog" ? "Analog" : "Digital";
    const eye = document.createElement("button");
    eye.type = "button";
    eye.className = "eye";
    eye.title = state.hidden.has(row.key) ? "Show channel" : "Hide channel";
    eye.innerHTML = eyeIcon(state.hidden.has(row.key));
    eye.addEventListener("pointerdown", (ev) => ev.stopPropagation());
    eye.addEventListener("click", (ev) => {
      ev.stopPropagation();
      if (state.hidden.has(row.key)) state.hidden.delete(row.key);
      else state.hidden.add(row.key);
      state.gutterSig = "";
      renderGutter();
      scheduleTiles();
    });
    el.append(bar, name, kind, eye);
    el.addEventListener("mousedown", (ev) => {
      if (ev.button !== 0 || ev.target.closest("button")) return;
      startChannelDrag(row.key, ev.clientY);
    });
    gutter.appendChild(el);
  }
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

function prep(canvas) {
  const dpr = window.devicePixelRatio || 1;
  const w = Math.max(1, canvas.clientWidth);
  const h = Math.max(1, canvas.clientHeight);
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
    const startSec = v.start / state.rate;
    const first = Math.ceil(startSec / step) * step;
    ctx.fillStyle = "#9aa6b8";
    ctx.font = "11px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "top";
    for (let t = first; t < startSec + span + step * 0.01; t += step) {
      const x = (t * state.rate - v.start) / v.spp;
      if (x < -20 || x > w + 20) continue;
      ctx.strokeStyle = "#3a4658";
      ctx.beginPath();
      ctx.moveTo(x + 0.5, h - 7);
      ctx.lineTo(x + 0.5, h);
      ctx.stroke();
      ctx.fillText(formatSeconds(t), x, 3);
    }
  }
  if (state.triggerSample != null) {
    const x = (state.triggerSample - v.start) / v.spp;
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
  const { ctx, w, h } = prep(wave);
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "#0b0f14";
  ctx.fillRect(0, 0, w, h);
  const rows = orderedRows();
  if (state.total <= 0 || rows.length === 0) {
    ctx.fillStyle = "#8b95a6";
    ctx.font = "14px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("Press Run to capture the demo source", w / 2, h / 2);
    return;
  }
  const rowH = h / rows.length;
  drawGrid(ctx, w, h, rows, rowH);
  const endX = traceEndX(w);
  ctx.save();
  ctx.beginPath();
  ctx.rect(0, 0, Math.max(0, endX), h);
  ctx.clip();
  rows.forEach((row, index) => {
    const top = index * rowH;
    if (state.hidden.has(row.key)) return;
    const cols = state.tiles[row.key];
    if (!cols) return;
    if (row.kind === "analog") drawAnalog(ctx, cols, top, rowH, row.color);
    else drawDigital(ctx, cols, top, rowH, row.color);
  });
  drawAnnotations(ctx, w);
  ctx.restore();
  rows.forEach((row, index) => {
    if (row.kind !== "logic" || state.hidden.has(row.key)) return;
    const top = index * rowH;
    const pad = Math.max(8, rowH * 0.22);
    ctx.font = "11px sans-serif";
    ctx.textAlign = "left";
    ctx.textBaseline = "middle";
    ctx.lineWidth = 3;
    ctx.strokeStyle = "rgba(8, 12, 18, 0.9)";
    ctx.strokeText("H", 8, top + pad);
    ctx.strokeText("L", 8, top + rowH - pad);
    ctx.fillStyle = "#d5deea";
    ctx.fillText("H", 8, top + pad);
    ctx.fillText("L", 8, top + rowH - pad);
  });
  drawMeasureSpan(ctx, w, h);
  drawMarkerLines(ctx, h);
  if (state.hoverX != null) {
    ctx.strokeStyle = "rgba(255,255,255,0.28)";
    ctx.beginPath();
    ctx.moveTo(state.hoverX + 0.5, 0);
    ctx.lineTo(state.hoverX + 0.5, h);
    ctx.stroke();
  }
}

function drawGrid(ctx, w, h, rows, rowH) {
  const v = view();
  ctx.save();
  ctx.lineWidth = 1;
  if (state.rate > 0) {
    const span = (w * v.spp) / state.rate;
    const step = niceStep(span, w);
    if (step && isFinite(step)) {
      const startSec = v.start / state.rate;
      const first = Math.ceil(startSec / step) * step;
      ctx.strokeStyle = "rgba(86, 140, 190, 0.16)";
      for (let t = first; t < startSec + span + step * 0.01; t += step) {
        const x = (t * state.rate - v.start) / v.spp;
        ctx.beginPath();
        ctx.moveTo(x + 0.5, 0);
        ctx.lineTo(x + 0.5, h);
        ctx.stroke();
      }
    }
  }
  rows.forEach((row, index) => {
    const top = index * rowH;
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
    } else {
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
    }
  });
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

function drawAnnotations(ctx, w) {
  if (!state.annotations.length) return;
  const v = view();
  const viewEnd = v.start + w * v.spp;
  ctx.font = "11px sans-serif";
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  let labels = 0;
  for (const row of state.annotations) {
    if (!["address", "data", "word", "read", "write"].includes(row.class)) continue;
    if (row.end_sample < v.start || row.start_sample > viewEnd) continue;
    const x = Math.max(0, (row.start_sample - v.start) / v.spp);
    const width = Math.max(2, (row.end_sample - row.start_sample) / v.spp);
    ctx.fillStyle = "rgba(76, 141, 255, 0.22)";
    ctx.fillRect(x, 2, Math.min(width, w - x), 16);
    if (width > 48 && labels < 24) {
      ctx.fillStyle = "#d5dbea";
      ctx.fillText(row.text, x + 3, 3);
      labels += 1;
    }
  }
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
  for (let x = 0; x < cols.length; x++) {
    if (pastCapture(x)) break;
    const column = cols[x];
    if (!column || column.valid === false) break;
    if (column.toggled) {
      const yLast = yOf(column.last);
      if (prev == null) ctx.moveTo(x + 0.5, yOf(column.first));
      ctx.lineTo(x + 0.5, yTop);
      ctx.lineTo(x + 0.5, yBot);
      ctx.lineTo(x + 0.5, yLast);
      prev = yLast;
    } else {
      const y = yOf(column.last);
      if (prev == null) ctx.moveTo(x + 0.5, y);
      else if (prev !== y) {
        ctx.lineTo(x + 0.5, prev);
        ctx.lineTo(x + 0.5, y);
      } else {
        ctx.lineTo(x + 0.5, y);
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
    if (pastCapture(index) || !column || column.valid === false) return false;
    if (!Number.isFinite(column.min) || !Number.isFinite(column.max)) return false;
    if (Math.abs(column.min) > 20 || Math.abs(column.max) > 20) return false;
    return true;
  };
  ctx.beginPath();
  let started = false;
  for (let i = 0; i < cols.length; i++) {
    if (pastCapture(i)) break;
    const column = cols[i];
    if (!usable(column, i)) continue;
    const x = i + 0.5;
    if (!started) {
      ctx.moveTo(x, yOf(column.max));
      started = true;
    } else ctx.lineTo(x, yOf(column.max));
  }
  for (let i = cols.length - 1; i >= 0; i--) {
    if (pastCapture(i)) continue;
    const column = cols[i];
    if (!usable(column, i)) continue;
    ctx.lineTo(i + 0.5, yOf(column.min));
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
    if (pastCapture(i)) break;
    const column = cols[i];
    if (!usable(column, i)) continue;
    const y = yOf((column.min + column.max) / 2);
    if (!started) {
      ctx.moveTo(i + 0.5, y);
      started = true;
    } else ctx.lineTo(i + 0.5, y);
  }
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.4;
  ctx.stroke();
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
  while (tileAgain) {
    tileAgain = false;
    await fetchTiles();
  }
  tileFlight = false;
  if (tileAgain) scheduleTiles();
}

async function fetchTiles() {
  const rows = visibleRows();
  const width = Math.max(1, Math.floor(wave.clientWidth || 1));
  const v = view();
  const req = ++state.req;
  const spp = Math.max(v.spp, 1e-9);
  if (rows.length === 0) {
    state.tiles = {};
    drawWave();
    drawRuler();
    return;
  }
  const pending = { req, got: {}, expect: rows.length };
  state.pending = pending;
  const bodies = rows.map((row) => ({
    cmd: "tile",
    req,
    session: state.active,
    channel: row.channel,
    start: v.start,
    columns: width,
    samples_per_pixel: spp,
    kind: row.kind,
    key: row.key,
  }));
  const sent = socket && socket.readyState === WebSocket.OPEN;
  if (sent) {
    await new Promise((resolve) => {
      pending.done = resolve;
      pending.timer = setTimeout(async () => {
        if (state.req === req && Object.keys(pending.got).length < rows.length) {
          await httpTiles(req, bodies, pending);
        }
        resolve();
      }, 280);
      for (const body of bodies) socket.send(JSON.stringify(body));
      if (Object.keys(pending.got).length >= rows.length) {
        clearTimeout(pending.timer);
        resolve();
      }
    });
  } else {
    await httpTiles(req, bodies, pending);
  }
  if (state.req !== req) return;
  if (Object.keys(pending.got).length) {
    state.tiles = pending.got;
    drawWave();
    drawRuler();
  }
}

async function httpTiles(req, bodies, pending) {
  const results = await Promise.all(bodies.map(async (body) => {
    const data = await api(body);
    return { key: body.key, columns: data.columns };
  }));
  if (state.req !== req) return;
  for (const result of results) pending.got[result.key] = result.columns;
  if (pending.timer) clearTimeout(pending.timer);
  if (pending.done) pending.done();
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
      const o = 32 + i * 4;
      if (o + 4 > buffer.byteLength) break;
      columns.push({
        first: viewBytes.getUint8(o) !== 0,
        last: viewBytes.getUint8(o + 1) !== 0,
        toggled: viewBytes.getUint8(o + 2) !== 0,
        edges: viewBytes.getUint8(o + 3),
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
  for (const button of document.querySelectorAll(".side-tabs button")) {
    button.classList.toggle("active", button.dataset.tab === name);
  }
  sideBody.innerHTML = panelHtml(name);
  bindPanel(name);
}

function panelHtml(name) {
  if (name === "device") return devicePanel();
  if (name === "decode") {
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
      <div id="decoder-list"></div>
      <p class="hint">I2C maps SDA/SCL. SPI maps SCK/MOSI/MISO/CS, including demo:spi/ names when both pods are stacked. EEPROM reads the I2C rows.</p>`;
  }
  if (name === "cursors") {
    return `<h2>Cursors</h2>
      <h3>Markers</h3>
      <div id="marker-list"></div>
      <p class="hint">Add a marker from the toolbar, then click the waveform. Drag a marker to move it; it snaps to the nearest edge under the cursor.</p>
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
      <button class="block" id="export-csv" type="button">Download CSV</button>
      <button class="block" id="export-xlsx" type="button">Download Excel</button>
      <button class="block" id="download" type="button">Download .lvcap</button>
      <button class="block" id="download-dsl" type="button">Download .dsl</button>
      <button class="block" id="export-ann" type="button">Export annotations</button>
      <p class="hint">CSV and Excel list one row per sample: time, logic levels, and the demo sine in volts. A capture longer than Excel's row limit is cut off. Firmware stays outside this repo.</p>`;
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
  return `<h2>Device</h2>
    <div class="device-card">
      <svg class="pod" viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="6" width="18" height="12" rx="2"></rect><path d="M7 6V4M12 6V4M17 6V4M7 20v-2M12 20v-2M17 20v-2"></path></svg>
      <div>
        <strong>${title}</strong>
        <span class="connected"><i class="dot"></i> Connected</span>
        <p class="hint">${hardware ? "Opened pod. The name is the one the engine reports." : "Software demo. No pod serial number."}</p>
      </div>
    </div>
    <p id="profile-note" class="hint">Choose the source from the device menu. Demo and Demo SPI can be stacked. Untested product ids stay closed.</p>
    <h3>Acquisition</h3>
    <label class="acq-row">Sample rate
      <select id="set-rate" aria-label="Sample rate">
        <option value="100000">100 kS/s</option>
        <option value="1000000">1 MS/s</option>
        <option value="20000000">20 MS/s</option>
        <option value="100000000">100 MS/s</option>
      </select>
    </label>
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
    <div class="acq-row"><span>Analog channels</span><span class="value">${state.analog.length} · ${analog}</span></div>
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
        <input id="set-repeat" type="number" min="0" step="100" aria-label="Repeat interval">
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

function bindPanel(name) {
  if (name === "device") {
    loadDeviceChoices();
    bindSelect("set-rate", "rate", true);
    bindSelect("set-duration", "duration", true);
    bindSelect("set-depth", "depth", false);
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
    refreshDecoders();
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
    document.getElementById("export-csv").addEventListener("click", () => downloadCapture("/api/export/csv", "capture.csv"));
    document.getElementById("export-xlsx").addEventListener("click", () => downloadCapture("/api/export/xlsx", "capture.xlsx"));
    document.getElementById("download").addEventListener("click", () => downloadCapture("/api/export/lvcap", "capture.lvcap"));
    document.getElementById("download-dsl").addEventListener("click", () => downloadCapture("/api/export/dsl", "capture.dsl"));
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
    const seconds = marker.sample / Math.max(1, state.rate);
    label.textContent = `M${marker.n} · ${formatSeconds(seconds)} · sample ${marker.sample}`;
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
    row.append(dot, label, jump, remove);
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

function bindCheck(id, key) {
  const el = document.getElementById(id);
  if (!el) return;
  el.checked = !!settings[key];
  el.addEventListener("change", () => { settings[key] = el.checked; });
}

function syncDeviceSelect() {
  const select = document.getElementById("device-select");
  if (!select || !select.options.length) return;
  const key = (state.devices || []).map((device) => device.id).join("+");
  if ([...select.options].some((option) => option.value === key)) select.value = key;
}

async function loadDeviceChoices() {
  const select = document.getElementById("device-select");
  if (!select) return;
  try {
    const devices = await api({ cmd: "list_devices" });
    const previous = select.value;
    select.replaceChildren();
    const demos = devices.filter((device) => device.kind === "demo");
    for (const device of demos) {
      const option = document.createElement("option");
      option.value = device.id;
      option.textContent = device.name;
      select.append(option);
    }
    if (demos.some((device) => device.id === "demo") && demos.some((device) => device.id === "demo:spi")) {
      const stacked = document.createElement("option");
      stacked.value = "demo+demo:spi";
      stacked.textContent = "Demo + Demo SPI";
      select.append(stacked);
    }
    for (const device of devices) {
      if (device.kind === "demo") continue;
      const option = document.createElement("option");
      option.value = device.id;
      option.textContent = device.name;
      select.append(option);
    }
    syncDeviceSelect();
    if (!select.value && previous) select.value = previous;
    api({ cmd: "list_profiles" }).then((profiles) => {
      const note = document.getElementById("profile-note");
      if (!note) return;
      const untested = profiles.filter((profile) => !profile.hardware_tested).length;
      const tested = profiles.filter((profile) => profile.hardware_tested).map((profile) => profile.name);
      note.textContent = `${tested.join(", ") || "No pod"} tested on hardware. ${untested} other logic product ids stay closed.`;
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

async function addDecoder() {
  const protocol = document.getElementById("decoder-kind").value;
  try {
    await api({
      cmd: "add_decoder",
      session: state.active,
      protocol,
      channels: decoderChannels(protocol),
    });
    await refreshDecoders();
    await loadAnnotations();
  } catch (err) {
    statusEl.textContent = err.message;
  }
}

async function refreshDecoders() {
  const host = document.getElementById("decoder-list");
  if (!host) return;
  const rows = await api({ cmd: "list_decoders", session: state.active });
  host.replaceChildren();
  for (const row of rows) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "block";
    button.textContent = `Remove ${row.protocol} ${row.id}`;
    button.addEventListener("click", async () => {
      await api({ cmd: "remove_decoder", session: state.active, id: row.id });
      await refreshDecoders();
      await loadAnnotations();
    });
    host.append(button);
  }
}

async function loadAnnotations() {
  if (!state.active) return;
  const query = document.getElementById("table-search");
  const text = query ? query.value.trim() : "";
  try {
    state.annotations = await api({
      cmd: "read_annotations",
      session: state.active,
      query: text || null,
      limit: 300,
    });
  } catch (err) {
    state.annotations = [];
    statusEl.textContent = err.message;
  }
  renderTable();
  drawWave();
}

function renderTable() {
  const body = document.getElementById("table-body");
  if (!body) return;
  if (state.tableTab === "edges") {
    body.innerHTML = `<div class="table-empty">
      <p>Pattern search uses 0, 1, and x on the hovered logic channel.</p>
      <button type="button" id="edge-next-table">Next match</button>
      <button type="button" id="edge-prev-table">Previous match</button>
      <p id="edge-hit"></p>
    </div>`;
    document.getElementById("edge-next-table").addEventListener("click", () => searchFromTable(true));
    document.getElementById("edge-prev-table").addEventListener("click", () => searchFromTable(false));
    return;
  }
  if (!state.annotations.length) {
    body.innerHTML = `<div class="table-empty">No decoded rows yet. Add I2C or SPI, then capture.</div>`;
    return;
  }
  const table = document.createElement("table");
  table.className = "ann";
  for (const row of state.annotations) {
    const tr = document.createElement("tr");
    const time = (row.start_sample / Math.max(1, state.rate)).toFixed(6);
    tr.innerHTML = `<td>${time}s</td><td>${row.protocol}</td><td>${row.class}</td><td>${row.text}</td>`;
    tr.addEventListener("click", () => centerOn(row.start_sample));
    table.append(tr);
  }
  body.replaceChildren(table);
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
  const rows = orderedRows();
  if (!rows.length) return null;
  const y = clientY - rect.top;
  const index = Math.min(rows.length - 1, Math.max(0, Math.floor(y / (rect.height / rows.length))));
  return rows[index];
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

async function searchFromTable(forward) {
  const field = document.getElementById("table-search");
  const pattern = field && field.value ? field.value : settings.pattern;
  settings.pattern = pattern;
  const from = state.hoverX == null ? Math.floor(view().start) : hoverSample();
  try {
    const data = await api({
      cmd: "search_pattern",
      session: state.active,
      channel: activeLogicChannel(),
      from,
      pattern,
      forward,
    });
    const hit = document.getElementById("edge-hit");
    if (data.sample == null) {
      if (hit) hit.textContent = "no match";
      return;
    }
    if (hit) hit.textContent = `match at ${data.sample}`;
    centerOn(data.sample);
  } catch (err) {
    statusEl.textContent = err.message;
  }
}

async function exportAnnotations() {
  try {
    const query = document.getElementById("table-search");
    const data = await api({
      cmd: "export_annotations",
      session: state.active,
      format: "csv",
      query: query && query.value.trim() ? query.value.trim() : null,
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

async function stepEdge(forward) {
  if (state.total <= 0) return;
  const channel = activeLogicChannel();
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

async function downloadCapture(path, filename) {
  const res = await fetch(path);
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    statusEl.textContent = body.error || "export failed";
    return;
  }
  const blob = await res.blob();
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = filename;
  link.click();
  URL.revokeObjectURL(link.href);
  const rows = res.headers.get("x-logicview-rows");
  const total = res.headers.get("x-logicview-total");
  if (rows && total && rows !== total) {
    statusEl.textContent = `exported ${Number(rows).toLocaleString()} of ${Number(total).toLocaleString()} samples`;
  }
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

wave.addEventListener("wheel", (ev) => {
  ev.preventDefault();
  if (state.total <= 0) return;
  const v = view();
  const rect = wave.getBoundingClientRect();
  const x = ev.clientX - rect.left;
  const sample = v.start + x * v.spp;
  const factor = ev.deltaY > 0 ? 1.25 : 1 / 1.25;
  zoomAt(sample, x, factor);
}, { passive: false });

function zoomAt(sample, x, factor) {
  const v = view();
  const width = Math.max(1, wave.clientWidth);
  const minSpp = 1 / 32;
  const maxSpp = Math.max(minSpp, (Math.max(state.total, 1) / width) * 8);
  v.spp = Math.min(maxSpp, Math.max(minSpp, v.spp * factor));
  v.start = sample - x * v.spp;
  v.userNavigated = true;
  clampView();
  scheduleTiles();
  drawRuler();
  drawOverview();
  syncTimebaseLabel();
}

function zoomBy(factor) {
  const width = Math.max(1, wave.clientWidth);
  const x = width / 2;
  const sample = view().start + x * view().spp;
  zoomAt(sample, x, factor);
}

wave.addEventListener("pointerdown", (ev) => {
  if (ev.button !== 0 || state.total <= 0) return;
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
  if (pointer && pointer.kind === "measure") {
    pointer.b = sampleAt(ev.clientX);
    drawWave();
    const seconds = Math.abs(pointer.b - pointer.a) / Math.max(1, state.rate);
    showHover(ev, `measurement ${formatSeconds(seconds)}`, `<b>Measurement</b><br>${formatSeconds(seconds)}<br>${Math.abs(pointer.b - pointer.a)} samples`);
    return;
  }
  queueHover(ev);
  drawWave();
});

wave.addEventListener("pointerup", async (ev) => {
  const active = pointer;
  pointer = null;
  if (!active) return;
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
  const rows = orderedRows();
  if (rows.length === 0 || state.total <= 0) {
    hideHover();
    return;
  }
  if (x >= traceEndX(rect.width)) {
    hideHover();
    return;
  }
  const rowH = rect.height / rows.length;
  const index = Math.floor(y / rowH);
  const row = rows[index];
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
  const seconds = TIME_DIVS[index] || TIME_DIVS[0];
  const px = Math.max(40, (wave.clientWidth || 800) / 10);
  const v = view();
  const width = Math.max(1, wave.clientWidth);
  const mid = v.start + (width / 2) * v.spp;
  v.spp = (seconds * Math.max(1, state.rate)) / px;
  v.start = mid - (width / 2) * v.spp;
  v.userNavigated = true;
  clampView();
  scheduleTiles();
  drawRuler();
  drawOverview();
  const label = document.getElementById("timebase-label");
  if (label) label.textContent = formatDiv(seconds);
}

function bindSplitters() {
  const side = document.getElementById("split-side");
  const bottom = document.getElementById("split-bottom");
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
  bottom.addEventListener("pointerdown", (ev) => {
    ev.preventDefault();
    const startY = ev.clientY;
    const start = parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--bottom")) || 168;
    bottom.classList.add("drag");
    const move = (e) => {
      const next = Math.max(80, Math.min(window.innerHeight * 0.55, start - (e.clientY - startY)));
      document.documentElement.style.setProperty("--bottom", next + "px");
      scheduleTiles();
      drawRuler();
    };
    const up = () => {
      bottom.classList.remove("drag");
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
    ["Export CSV", () => downloadCapture("/api/export/csv", "capture.csv")],
    ["Export Excel", () => downloadCapture("/api/export/xlsx", "capture.xlsx")],
    ["Download .lvcap", () => downloadCapture("/api/export/lvcap", "capture.lvcap")],
    ["Download .dsl", () => downloadCapture("/api/export/dsl", "capture.dsl")],
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
    ["Zoom in", () => zoomBy(1 / 1.4)],
    ["Zoom out", () => zoomBy(1.4)],
  ],
  decode: [["Open decode", () => selectTab("decode")]],
  measure: [["Add measurement", () => setTool("measure")]],
  tools: [
    ["Previous edge", () => stepEdge(false)],
    ["Next edge", () => stepEdge(true)],
    ["Add marker", () => setTool("marker")],
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
  pop.style.left = rect.left + "px";
  pop.style.top = rect.bottom + "px";
  pop.classList.remove("hidden");
  for (const other of document.querySelectorAll(".menubar button")) {
    other.classList.toggle("open", other === button);
  }
}

for (const button of document.querySelectorAll(".table-tab")) {
  button.addEventListener("click", () => {
    state.tableTab = button.dataset.tab;
    for (const tab of document.querySelectorAll(".table-tab")) {
      tab.classList.toggle("active", tab === button);
    }
    renderTable();
  });
}

document.getElementById("table-search").addEventListener("keydown", (ev) => {
  if (ev.key !== "Enter") return;
  ev.preventDefault();
  if (state.tableTab === "edges") searchFromTable(true);
  else loadAnnotations();
});
document.getElementById("table-export").addEventListener("click", exportAnnotations);
renderTable();

document.getElementById("run").addEventListener("click", () => runCapture());
document.getElementById("stop").addEventListener("click", () => stopCapture());
document.getElementById("tab-add").addEventListener("click", () => addSession());
document.getElementById("device-select").addEventListener("change", (ev) => applyDeviceChoice(ev.target.value));
document.getElementById("channel-add").addEventListener("click", () => selectTab("device"));
document.getElementById("tool-marker").addEventListener("click", () => setTool("marker"));
document.getElementById("tool-measure").addEventListener("click", () => setTool("measure"));
document.getElementById("zoom-in").addEventListener("click", () => zoomBy(1 / 1.4));
document.getElementById("zoom-out").addEventListener("click", () => zoomBy(1.4));
document.getElementById("edge-prev").addEventListener("click", () => stepEdge(false));
document.getElementById("edge-next").addEventListener("click", () => stepEdge(true));
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

for (const button of document.querySelectorAll(".side-tabs button")) {
  button.addEventListener("click", () => selectTab(button.dataset.tab));
}
for (const button of document.querySelectorAll(".menubar button")) {
  button.addEventListener("click", (ev) => {
    ev.stopPropagation();
    openMenu(button);
  });
}
document.addEventListener("click", (ev) => {
  if (!ev.target.closest(".menu-pop") && !ev.target.closest(".menubar")) closeMenu();
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
    const search = document.getElementById("table-search");
    if (search) search.focus();
    return;
  }
  if (key === "Escape") {
    if (state.menu) closeMenu();
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
  const target = span / Math.max(1, px / 90);
  if (!(target > 0) || !isFinite(target)) return null;
  const pow = 10 ** Math.floor(Math.log10(target));
  const err = target / pow;
  const nice = err >= 5 ? 5 : err >= 2 ? 2 : 1;
  return nice * pow;
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

boot().catch((err) => {
  statusEl.textContent = err.message;
});
