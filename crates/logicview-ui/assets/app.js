const wave = document.getElementById("wave");
const ruler = document.getElementById("ruler");
const overview = document.getElementById("overview");
const gutter = document.getElementById("gutter");
const tabsEl = document.getElementById("tabs");
const statusEl = document.getElementById("status");
const summaryEl = document.getElementById("summary");
const startBtn = document.getElementById("start");
const hoverEl = document.getElementById("hover");
const drawerEl = document.getElementById("drawer");
const rail = document.getElementById("rail");

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
  drawer: null,
};

const settings = {
  rate: 1_000_000,
  duration: 2000,
  trigger: false,
  percent: 10,
};

const views = {};
let socket = null;
let tileFlight = false;
let tileAgain = false;
let commandBusy = false;
let hoverTimer = null;
let drag = null;

function view() {
  if (!views[state.active]) {
    views[state.active] = { start: 0, spp: 1, userNavigated: false };
  }
  return views[state.active];
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

function visibleRows() {
  const rows = [];
  for (const channel of state.channels) {
    const key = "logic:" + channel.index;
    if (!state.hidden.has(key)) {
      rows.push({ key, kind: "logic", channel: channel.index, name: channel.name, color: channel.color });
    }
  }
  for (const channel of state.analog) {
    const key = "analog:" + channel.index;
    if (!state.hidden.has(key)) {
      rows.push({ key, kind: "analog", channel: channel.index, name: channel.name, color: channel.color });
    }
  }
  return rows;
}

function applyStatus(status, fromLive) {
  state.phase = status.phase;
  state.rate = status.sample_rate_hz;
  state.durationMs = status.duration_ms;
  state.channels = status.channels || [];
  state.analog = status.analog || [];
  state.triggerSample = status.trigger_sample;
  const grew = status.sample_count !== state.total;
  state.total = status.sample_count;
  if (!view().userNavigated) fitView();
  renderChrome();
  if (grew || !fromLive) {
    scheduleTiles();
    refreshOverview();
  } else {
    drawOverview();
  }
}

function fitView() {
  const v = view();
  const width = Math.max(1, wave.clientWidth || 1);
  if (state.total <= 0) {
    v.start = 0;
    v.spp = 1;
    return;
  }
  v.start = 0;
  v.spp = state.total / width;
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

function renderChrome() {
  paintStatus();
  renderTabs();
  renderGutter();
  drawRuler();
}

function paintStatus() {
  const live = isLive(state.phase);
  startBtn.textContent = live ? "Stop" : "Start";
  startBtn.classList.toggle("running", live);
  const rate = formatHz(state.rate);
  const seconds = (state.durationMs / 1000).toFixed(1);
  summaryEl.textContent = `${state.channels.length} ch · ${rate} · ${seconds} s`;
  const count = state.total.toLocaleString();
  statusEl.textContent = state.hoverText
    ? `${state.phase} · ${count} samples · ${state.hoverText}`
    : `${state.phase} · ${count} samples`;
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

function renderGutter() {
  const all = allRows();
  const sig = all.map((row) => row.key + row.color + (state.hidden.has(row.key) ? "0" : "1")).join("|");
  if (sig === state.gutterSig) return;
  state.gutterSig = sig;
  gutter.replaceChildren();
  for (const row of all) {
    const el = document.createElement("div");
    el.className = "ch";
    const box = document.createElement("input");
    box.type = "checkbox";
    box.checked = !state.hidden.has(row.key);
    box.addEventListener("change", () => {
      if (box.checked) state.hidden.delete(row.key);
      else state.hidden.add(row.key);
      scheduleTiles();
      renderGutter();
    });
    const swatch = document.createElement("span");
    swatch.className = "swatch";
    swatch.style.background = row.color;
    const name = document.createElement("span");
    name.className = "name";
    name.textContent = row.name;
    name.style.color = row.color;
    el.append(box, swatch, name);
    if (state.hidden.has(row.key)) el.style.opacity = "0.35";
    gutter.appendChild(el);
  }
  if (rows.length === 0 && all.length === 0) {
    gutter.textContent = "";
  }
}

function allRows() {
  const rows = [];
  for (const channel of state.channels) {
    rows.push({ key: "logic:" + channel.index, kind: "logic", channel: channel.index, name: channel.name, color: channel.color });
  }
  for (const channel of state.analog) {
    rows.push({ key: "analog:" + channel.index, kind: "analog", channel: channel.index, name: channel.name, color: channel.color });
  }
  return rows;
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
  ctx.fillStyle = "#101218";
  ctx.fillRect(0, 0, w, h);
  ctx.strokeStyle = "#2c313c";
  ctx.beginPath();
  ctx.moveTo(0, h - 0.5);
  ctx.lineTo(w, h - 0.5);
  ctx.stroke();
  const v = view();
  if (state.total <= 0 || state.rate <= 0) return;
  const span = (w * v.spp) / state.rate;
  const step = niceStep(span, w);
  if (!step || !isFinite(step)) return;
  const startSec = v.start / state.rate;
  const first = Math.ceil(startSec / step) * step;
  ctx.fillStyle = "#9aa1ad";
  ctx.font = "11px sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  for (let t = first; t < startSec + span; t += step) {
    const x = ((t * state.rate - v.start) / v.spp);
    ctx.strokeStyle = "#3a4150";
    ctx.beginPath();
    ctx.moveTo(x + 0.5, h - 8);
    ctx.lineTo(x + 0.5, h);
    ctx.stroke();
    ctx.fillText(formatSeconds(t), x, 4);
  }
  if (state.triggerSample != null) {
    const x = (state.triggerSample - v.start) / v.spp;
    if (x >= -8 && x <= w + 8) drawDiamond(ctx, x, h / 2, "#f0c14d");
  }
}

function drawDiamond(ctx, x, y, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(x, y - 6);
  ctx.lineTo(x + 6, y);
  ctx.lineTo(x, y + 6);
  ctx.lineTo(x - 6, y);
  ctx.closePath();
  ctx.fill();
}

function drawWave() {
  const { ctx, w, h } = prep(wave);
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "#101218";
  ctx.fillRect(0, 0, w, h);
  const rows = allRows();
  if (state.total <= 0 || rows.length === 0) {
    ctx.fillStyle = "#8d94a3";
    ctx.font = "14px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("Press Start to capture the demo source", w / 2, h / 2);
    return;
  }
  const rowH = h / rows.length;
  rows.forEach((row, index) => {
    const top = index * rowH;
    ctx.fillStyle = index % 2 === 0 ? "rgba(255,255,255,0.015)" : "transparent";
    ctx.fillRect(0, top, w, rowH);
    const cols = state.tiles[row.key];
    if (!cols || state.hidden.has(row.key)) return;
    if (row.kind === "analog") drawAnalog(ctx, cols, top, rowH, row.color);
    else drawDigital(ctx, cols, top, rowH, row.color);
  });
  if (state.hoverX != null) {
    ctx.strokeStyle = "rgba(255,255,255,0.28)";
    ctx.beginPath();
    ctx.moveTo(state.hoverX + 0.5, 0);
    ctx.lineTo(state.hoverX + 0.5, h);
    ctx.stroke();
  }
}

function drawDigital(ctx, cols, top, height, color) {
  const pad = Math.max(5, height * 0.22);
  const yTop = top + pad;
  const yBot = top + height - pad;
  const yOf = (high) => (high ? yTop : yBot);
  ctx.beginPath();
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.6;
  let prev = null;
  for (let x = 0; x < cols.length; x++) {
    const column = cols[x];
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
  const pad = 6;
  const y0 = top + pad;
  const y1 = top + height - pad;
  const scaleMin = -1.25;
  const scaleMax = 1.25;
  const yOf = (value) => {
    const t = (value - scaleMin) / (scaleMax - scaleMin);
    return y1 - t * (y1 - y0);
  };
  ctx.beginPath();
  let started = false;
  for (let i = 0; i < cols.length; i++) {
    const column = cols[i];
    if (!column || column.valid === false || Number.isNaN(column.max)) continue;
    const x = i + 0.5;
    if (!started) {
      ctx.moveTo(x, yOf(column.max));
      started = true;
    } else ctx.lineTo(x, yOf(column.max));
  }
  for (let i = cols.length - 1; i >= 0; i--) {
    const column = cols[i];
    if (!column || column.valid === false || Number.isNaN(column.min)) continue;
    ctx.lineTo(i + 0.5, yOf(column.min));
  }
  ctx.closePath();
  ctx.save();
  ctx.globalAlpha = 0.22;
  ctx.fillStyle = color;
  ctx.fill();
  ctx.restore();
  ctx.beginPath();
  started = false;
  for (let i = 0; i < cols.length; i++) {
    const column = cols[i];
    if (!column || column.valid === false || Number.isNaN(column.min) || Number.isNaN(column.max)) continue;
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
  ctx.fillStyle = "#14171e";
  ctx.fillRect(0, 0, w, h);
  const cols = state.overviewCols;
  if (cols && state.total > 0) {
    ctx.strokeStyle = "#3dcc8e";
    ctx.beginPath();
    for (let i = 0; i < cols.length; i++) {
      const column = cols[i];
      const x = (i + 0.5) * (w / cols.length);
      const y = column.toggled || column.first ? 8 : h - 8;
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
      if (column.toggled) {
        ctx.lineTo(x, 8);
        ctx.lineTo(x, h - 8);
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
  const expect = {};
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
  bodies.forEach((body) => {
    expect[body.key] = true;
  });
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
  const view = new DataView(buffer);
  if (buffer.byteLength < 32) return null;
  const magic = String.fromCharCode(view.getUint8(0), view.getUint8(1), view.getUint8(2), view.getUint8(3));
  if (magic !== "LVT1") return null;
  const kind = view.getUint8(5);
  const channel = view.getUint16(6, true);
  const req = view.getUint32(8, true);
  const count = view.getUint32(12, true);
  const columns = [];
  if (kind === 1) {
    for (let i = 0; i < count; i++) {
      const o = 32 + i * 4;
      columns.push({
        first: view.getUint8(o) !== 0,
        last: view.getUint8(o + 1) !== 0,
        toggled: view.getUint8(o + 2) !== 0,
        edges: view.getUint8(o + 3),
      });
    }
  } else {
    for (let i = 0; i < count; i++) {
      const o = 32 + i * 8;
      const min = view.getFloat32(o, true);
      const max = view.getFloat32(o + 4, true);
      columns.push({ min, max, valid: !Number.isNaN(min) && !Number.isNaN(max) });
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
  const status = await api({ cmd: "status", session: id });
  applyStatus(status, false);
  await refreshSessions();
}

async function addSession() {
  const created = await api({ cmd: "create_session" });
  await selectSession(created.id);
}

async function toggleRun(instant) {
  if (commandBusy) return;
  commandBusy = true;
  try {
    if (isLive(state.phase)) {
      const status = await api({ cmd: "stop", session: state.active });
      applyStatus(status, false);
    } else {
      view().userNavigated = false;
      const status = await api({
        cmd: "configure",
        session: state.active,
        sample_rate_hz: settings.rate,
        duration_ms: settings.duration,
        realtime: true,
        trigger_enabled: settings.trigger,
        trigger_percent: settings.percent,
      });
      applyStatus(status, false);
      const started = await api({ cmd: "start", session: state.active, instant: !!instant });
      applyStatus(started, true);
    }
  } catch (err) {
    statusEl.textContent = err.message;
  } finally {
    commandBusy = false;
    await refreshSessions();
  }
}

function openDrawer(name) {
  state.drawer = state.drawer === name ? null : name;
  for (const button of rail.querySelectorAll("button")) {
    button.classList.toggle("active", button.dataset.drawer === state.drawer);
  }
  if (!state.drawer) {
    drawerEl.classList.add("hidden");
    drawerEl.replaceChildren();
    return;
  }
  drawerEl.classList.remove("hidden");
  drawerEl.innerHTML = drawerHtml(name);
  bindDrawer(name);
}

function drawerHtml(name) {
  if (name === "device") {
    return `<h2>Device</h2>
      <p>Demo source. This build does not open a USB pod, upload firmware, or program an FPGA.</p>
      <p>Channels are a clock, a UART-shaped line, an I2C-shaped pair, and a noisy 1 kHz sine.</p>
      <button class="block" id="download" type="button">Download .lvcap</button>`;
  }
  if (name === "capture") {
    return `<h2>Capture</h2>
      <label>Sample rate
        <select id="set-rate">
          <option value="100000">100 kHz</option>
          <option value="1000000">1 MHz</option>
          <option value="2000000">2 MHz</option>
        </select>
      </label>
      <label>Duration
        <select id="set-duration">
          <option value="1000">1.0 s</option>
          <option value="2000">2.0 s</option>
          <option value="5000">5.0 s</option>
        </select>
      </label>
      <p class="hint">Space starts and stops. Drag pans. The wheel zooms about the cursor. Page Up and Page Down pan.</p>`;
  }
  if (name === "trigger") {
    return `<h2>Trigger</h2>
      <label class="check"><input id="set-trigger" type="checkbox"> Arm on CLK rising</label>
      <label>Position
        <input id="set-percent" type="number" min="0" max="90" step="1">
      </label>
      <p class="hint">Instant ignores the trigger. The diamond on the ruler is the reported edge.</p>`;
  }
  if (name === "analyzers") {
    return `<h2>Analyzers</h2>
      <p>Protocol decoders are a later phase. The demo lines are already shaped like a clock, UART, and I2C so that work has a signal to land on.</p>`;
  }
  return `<h2>Measure</h2>
    <p id="measure-readout">${state.hoverText || "Hover a logic trace for width, period, frequency, and duty."}</p>
    <p class="hint">The readout follows the cursor. It is the pulse under the pointer, not a stored marker.</p>`;
}

function bindDrawer(name) {
  if (name === "device") {
    document.getElementById("download").addEventListener("click", downloadCapture);
  }
  if (name === "capture") {
    const rate = document.getElementById("set-rate");
    const duration = document.getElementById("set-duration");
    rate.value = String(settings.rate);
    duration.value = String(settings.duration);
    rate.addEventListener("change", () => { settings.rate = Number(rate.value); });
    duration.addEventListener("change", () => { settings.duration = Number(duration.value); });
  }
  if (name === "trigger") {
    const box = document.getElementById("set-trigger");
    const percent = document.getElementById("set-percent");
    box.checked = settings.trigger;
    percent.value = String(settings.percent);
    box.addEventListener("change", () => { settings.trigger = box.checked; });
    percent.addEventListener("change", () => { settings.percent = Number(percent.value); });
  }
}

async function downloadCapture() {
  const res = await fetch("/api/export/lvcap");
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    statusEl.textContent = body.error || "export failed";
    return;
  }
  const blob = await res.blob();
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = "capture.lvcap";
  link.click();
  URL.revokeObjectURL(link.href);
}

function connectSocket() {
  const proto = location.protocol === "https:" ? "wss" : "ws";
  socket = new WebSocket(`${proto}://${location.host}/ws`);
  socket.binaryType = "arraybuffer";
  socket.onmessage = (ev) => {
    if (typeof ev.data !== "string") {
      onTileFrame(parseFrame(ev.data));
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
    const statusLike = {
      phase: msg.phase || state.phase,
      sample_count: msg.sample_count,
      sample_rate_hz: state.rate,
      duration_ms: state.durationMs,
      channels: state.channels,
      analog: state.analog,
      trigger_sample: state.triggerSample,
    };
    applyStatus(statusLike, true);
  }
}

wave.addEventListener("wheel", (ev) => {
  ev.preventDefault();
  if (state.total <= 0) return;
  const v = view();
  const rect = wave.getBoundingClientRect();
  const x = ev.clientX - rect.left;
  const sample = v.start + x * v.spp;
  const factor = ev.deltaY > 0 ? 1.18 : 1 / 1.18;
  const width = Math.max(1, wave.clientWidth);
  const minSpp = 1 / 32;
  const maxSpp = Math.max(minSpp, (state.total / width) * 4);
  v.spp = Math.min(maxSpp, Math.max(minSpp, v.spp * factor));
  v.start = sample - x * v.spp;
  v.userNavigated = true;
  clampView();
  scheduleTiles();
  drawRuler();
  drawOverview();
}, { passive: false });

wave.addEventListener("pointerdown", (ev) => {
  if (ev.button !== 0) return;
  drag = { x: ev.clientX, start: view().start, pointer: ev.pointerId };
  wave.setPointerCapture(ev.pointerId);
});

wave.addEventListener("pointermove", (ev) => {
  const rect = wave.getBoundingClientRect();
  state.hoverX = ev.clientX - rect.left;
  if (drag) {
    const v = view();
    v.start = drag.start - (ev.clientX - drag.x) * v.spp;
    v.userNavigated = true;
    clampView();
    scheduleTiles();
    drawRuler();
    drawOverview();
    hideHover();
    return;
  }
  queueHover(ev);
  drawWave();
});

wave.addEventListener("pointerup", () => { drag = null; });
wave.addEventListener("pointerleave", () => {
  if (!drag) {
    state.hoverX = null;
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
  state.hoverEvent = ev;
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
  const rows = allRows();
  if (rows.length === 0 || state.total <= 0) {
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
  if (row.kind === "analog") {
    const cols = state.tiles[row.key] || [];
    const column = cols[Math.floor(x)];
    if (!column || column.valid === false) {
      hideHover();
      return;
    }
    const volts = (column.min + column.max) / 2;
    showHover(ev, `${row.name} · ${volts.toFixed(3)} V`, `<b style="color:${row.color}">${row.name}</b><br>${volts.toFixed(3)} V`);
    return;
  }
  try {
    const metrics = await api({ cmd: "measure", session: state.active, channel: row.channel, sample });
    const level = metrics.level_high ? "high" : "low";
    const width = formatSeconds(metrics.width_secs);
    const period = metrics.period_secs == null ? "—" : formatSeconds(metrics.period_secs);
    const freq = formatHz(metrics.frequency_hz);
    const duty = metrics.duty == null ? "—" : `${(metrics.duty * 100).toFixed(1)}%`;
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
  if (top + box.height + margin > window.innerHeight) top = ev.clientY - box.height - 12;
  hoverEl.style.left = left + "px";
  hoverEl.style.top = top + "px";
}

function hideHover() {
  state.hoverText = "";
  hoverEl.classList.add("hidden");
  paintStatus();
}

document.getElementById("start").addEventListener("click", () => toggleRun(false));
document.getElementById("instant").addEventListener("click", () => toggleRun(true));
document.getElementById("tab-add").addEventListener("click", () => addSession());
document.getElementById("device-chip").addEventListener("click", () => openDrawer("device"));
for (const button of rail.querySelectorAll("button")) {
  button.addEventListener("click", () => openDrawer(button.dataset.drawer));
}

window.addEventListener("keydown", (ev) => {
  if (ev.target.matches("input, select, textarea")) return;
  const key = ev.key;
  if (key === " " || key === "s" || key === "S") {
    ev.preventDefault();
    if (!ev.repeat) toggleRun(false);
    return;
  }
  if (key === "i" || key === "I") { ev.preventDefault(); toggleRun(true); return; }
  if (key === "o" || key === "O") { openDrawer("device"); return; }
  if (key === "t" || key === "T") { openDrawer("trigger"); return; }
  if (key === "d" || key === "D") { openDrawer("analyzers"); return; }
  if (key === "m" || key === "M") { openDrawer("measure"); return; }
  if (key === "Escape") { openDrawer(state.drawer); return; }
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
  connectSocket();
  drawWave();
}

boot().catch((err) => {
  statusEl.textContent = err.message;
});
