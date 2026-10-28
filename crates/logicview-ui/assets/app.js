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
  lastMeasure: null,
  drawer: null,
  cursors: [null, null],
  devices: [],
  annotations: [],
  tableTab: "decoded",
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
  const previous = state.phase;
  state.phase = status.phase;
  state.rate = status.sample_rate_hz;
  state.durationMs = status.duration_ms;
  state.channels = status.channels || [];
  state.analog = status.analog || [];
  if (status.devices) {
    state.devices = status.devices;
    settings.deviceName = status.devices.map((device) => device.name).join(" + ") || settings.deviceName;
  }
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
  const span = state.durationMs < 1000 ? `${state.durationMs} ms` : `${(state.durationMs / 1000).toFixed(1)} s`;
  summaryEl.textContent = `${settings.deviceName} · ${state.channels.length} ch · ${rate} · ${span}`;
  const chip = document.querySelector("#device-chip span:last-child");
  if (chip) chip.textContent = settings.deviceName;
  const count = state.total.toLocaleString();
  const trigger = state.triggerSample == null ? "" : ` · trigger @ ${state.triggerSample}`;
  statusEl.textContent = state.hoverText
    ? `${state.phase} · ${count} samples${trigger} · ${state.hoverText}`
    : `${state.phase} · ${count} samples${trigger}`;
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
  const sig = all.map((row) => row.key + row.color + (row.device || "") + (state.hidden.has(row.key) ? "0" : "1")).join("|");
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
    const label = document.createElement("span");
    label.className = "ch-label";
    const name = document.createElement("span");
    name.className = "name";
    name.textContent = row.name;
    name.style.color = row.color;
    label.append(name);
    if (row.device) {
      const device = document.createElement("span");
      device.className = "dev";
      device.textContent = row.device;
      label.append(device);
    }
    el.append(box, swatch, label);
    if (state.hidden.has(row.key)) el.style.opacity = "0.35";
    gutter.appendChild(el);
  }
}

function allRows() {
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
  for (const [index, sample] of state.cursors.entries()) {
    if (sample == null) continue;
    const x = (sample - v.start) / v.spp;
    if (x >= -8 && x <= w + 8) drawDiamond(ctx, x, h / 2, index === 0 ? "#5aa2ff" : "#ff8a5b");
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
  drawAnnotations(ctx, w);
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
        trigger_steps: settings.triggerSteps,
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

function refreshTriggerDrawer() {
  state.drawer = "trigger";
  drawerEl.classList.remove("hidden");
  drawerEl.innerHTML = drawerHtml("trigger");
  bindDrawer("trigger");
  for (const button of rail.querySelectorAll("button")) {
    button.classList.toggle("active", button.dataset.drawer === "trigger");
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
      <div id="device-list"><p>Looking for pods…</p></div>
      <p class="hint">Stack Demo and Demo SPI to put both pods on one waveform. Other product ids are listed as untested and are not opened. Firmware stays outside this repo.</p>
      <button class="block" id="download" type="button">Download .lvcap</button>
      <button class="block" id="download-dsl" type="button">Download .dsl</button>`;
  }
  if (name === "capture") {
    return `<h2>Capture</h2>
      <label>Sample rate
        <select id="set-rate">
          <option value="100000">100 kHz</option>
          <option value="1000000">1 MHz</option>
          <option value="20000000">20 MHz</option>
          <option value="100000000">100 MHz</option>
        </select>
      </label>
      <label>Duration
        <select id="set-duration">
          <option value="10">10 ms</option>
          <option value="100">100 ms</option>
          <option value="1000">1.0 s</option>
          <option value="2000">2.0 s</option>
          <option value="5000">5.0 s</option>
        </select>
      </label>
      <label>Depth
        <select id="set-depth">
          <option value="buffer">Buffer</option>
          <option value="stream">Stream</option>
        </select>
      </label>
      <label>Run
        <select id="set-run">
          <option value="single">Single</option>
          <option value="repeat">Repeat</option>
          <option value="loop">Loop</option>
        </select>
      </label>
      <label>Repeat interval (ms)
        <input id="set-repeat" type="number" min="0" step="100">
      </label>
      <label>Threshold (V)
        <input id="set-threshold" type="number" min="0" max="5" step="0.1">
      </label>
      <label class="check"><input id="set-rle" type="checkbox"> RLE</label>
      <label class="check"><input id="set-filter" type="checkbox"> One-sample filter</label>
      <label class="check"><input id="set-ext" type="checkbox"> External clock</label>
      <label class="check"><input id="set-fall" type="checkbox"> Clock falling edge</label>
      <label class="check"><input id="set-discard" type="checkbox"> Discard on stop</label>
      <p class="hint">Stop uploads the record unless discard is set. A short RLE capture is reported on the status line.</p>`;
  }
  if (name === "trigger") {
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
    const single = settings.triggerSteps.length ? " disabled" : "";
    return `<h2>Trigger</h2>
      <label class="check"><input id="set-trigger" type="checkbox"> Enable trigger</label>
      <label>Single edge
        <select id="set-kind"${single}>
          <option value="rising">Rising</option>
          <option value="falling">Falling</option>
          <option value="high">High</option>
          <option value="low">Low</option>
        </select>
      </label>
      <p class="hint">A sequence replaces the single edge. Steps run in order and the mark is the last one.</p>
      <div id="trigger-steps">${steps}</div>
      <button class="block" id="add-step" type="button"${settings.triggerSteps.length >= 16 ? " disabled" : ""}>Add edge step</button>
      <label>Position
        <input id="set-percent" type="number" min="0" max="90" step="1">
      </label>
      <p class="hint">Each step is one arm-record stage, up to 16. Demo captures search the stored samples for that sequence. A pod is sent the same stages; that sequence has not been run on hardware. Instant ignores the trigger.</p>`;
  }
  if (name === "analyzers") {
    return `<h2>Analyzers</h2>
      <label>Protocol
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
  return `<h2>Measure</h2>
    <p id="measure-readout">${state.hoverText || "Hover a logic trace for width, period, frequency, and duty."}</p>
    <label>Pattern (0, 1, x)
      <input id="set-pattern" type="text" value="${settings.pattern}">
    </label>
    <button class="block" id="pat-next" type="button">Next match</button>
    <button class="block" id="pat-prev" type="button">Previous match</button>
    <button class="block" id="cur-a" type="button">Cursor A at hover</button>
    <button class="block" id="cur-b" type="button">Cursor B at hover</button>
    <p id="cursor-readout">Cursors are not set.</p>
    <button class="block" id="keep-measure" type="button">Keep this measurement</button>
    <div id="saved-measures"></div>`;
}

function bindDrawer(name) {
  if (name === "device") {
    document.getElementById("download").addEventListener("click", () => downloadCapture("/api/export/lvcap", "capture.lvcap"));
    document.getElementById("download-dsl").addEventListener("click", () => downloadCapture("/api/export/dsl", "capture.dsl"));
    loadDevices();
  }
  if (name === "analyzers") {
    document.getElementById("add-decoder").addEventListener("click", addDecoder);
    refreshDecoders();
  }
  if (name === "capture") {
    bindSelect("set-rate", "rate", true);
    bindSelect("set-duration", "duration", true);
    bindSelect("set-depth", "depth", false);
    bindSelect("set-run", "run", false);
    const repeat = document.getElementById("set-repeat");
    const threshold = document.getElementById("set-threshold");
    repeat.value = String(settings.repeatMs);
    threshold.value = String(settings.threshold);
    repeat.addEventListener("change", () => { settings.repeatMs = Number(repeat.value); });
    threshold.addEventListener("change", () => { settings.threshold = Number(threshold.value); });
    bindCheck("set-rle", "rle");
    bindCheck("set-filter", "filter");
    bindCheck("set-ext", "extClock");
    bindCheck("set-fall", "clockFalling");
    bindCheck("set-discard", "discard");
  }
  if (name === "trigger") {
    const box = document.getElementById("set-trigger");
    const percent = document.getElementById("set-percent");
    const kind = document.getElementById("set-kind");
    box.checked = settings.trigger;
    percent.value = String(settings.percent);
    kind.value = settings.triggerKind;
    box.addEventListener("change", () => { settings.trigger = box.checked; });
    percent.addEventListener("change", () => { settings.percent = Number(percent.value); });
    kind.addEventListener("change", () => { settings.triggerKind = kind.value; });
    document.getElementById("add-step").addEventListener("click", () => {
      const next = settings.triggerSteps.length === 0 ? 1 : settings.triggerSteps.length === 1 ? 3 : 0;
      settings.triggerSteps.push({ channel: next, rising: true });
      settings.trigger = true;
      refreshTriggerDrawer();
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
        refreshTriggerDrawer();
      });
    }
  }
  if (name === "measure") {
    document.getElementById("pat-next").addEventListener("click", () => searchPattern(true));
    document.getElementById("pat-prev").addEventListener("click", () => searchPattern(false));
    document.getElementById("cur-a").addEventListener("click", () => dropCursor(0));
    document.getElementById("cur-b").addEventListener("click", () => dropCursor(1));
    document.getElementById("keep-measure").addEventListener("click", keepMeasurement);
    refreshMeasurements();
  }
}

function bindSelect(id, key, numeric) {
  const el = document.getElementById(id);
  el.value = String(settings[key]);
  el.addEventListener("change", () => {
    settings[key] = numeric ? Number(el.value) : el.value;
  });
}

function bindCheck(id, key) {
  const el = document.getElementById(id);
  el.checked = !!settings[key];
  el.addEventListener("change", () => { settings[key] = el.checked; });
}

async function loadDevices() {
  const list = document.getElementById("device-list");
  if (!list) return;
  try {
    const devices = await api({ cmd: "list_devices" });
    list.replaceChildren();
    const attached = new Set((state.devices || []).map((device) => device.id));
    for (const device of devices) {
      const row = document.createElement("div");
      const use = document.createElement("button");
      use.type = "button";
      use.className = "block";
      use.textContent = attached.has(device.id) ? `${device.name} (in session)` : `Use ${device.name}`;
      use.addEventListener("click", () => useDevice(device.id));
      row.append(use);
      if (device.kind === "demo") {
        const stack = document.createElement("button");
        stack.type = "button";
        stack.className = "block";
        stack.textContent = attached.has(device.id) ? `Remove ${device.name}` : `Stack ${device.name}`;
        stack.addEventListener("click", () => stackDevice(device, attached.has(device.id)));
        row.append(stack);
      }
      list.append(row);
    }
    api({ cmd: "list_profiles" }).then((profiles) => {
      const note = document.createElement("p");
      note.className = "hint";
      const untested = profiles.filter((profile) => !profile.hardware_tested).length;
      const tested = profiles.filter((profile) => profile.hardware_tested).map((profile) => profile.name);
      note.textContent = `${tested.join(", ") || "No pod"} tested on hardware. ${untested} other logic product ids stay closed.`;
      list.append(note);
    }).catch(() => {});
  } catch (err) {
    list.textContent = err.message;
  }
}

async function useDevice(id) {
  try {
    const connected = await api({ cmd: "connect", id });
    settings.device = connected.id;
    settings.deviceName = connected.name;
    const status = await api({ cmd: "status", session: state.active });
    applyStatus(status, false);
    state.gutterSig = "";
    renderGutter();
  } catch (err) {
    statusEl.textContent = err.message;
  }
}

async function stackDevice(device, remove) {
  try {
    const status = await api({
      cmd: remove ? "detach_device" : "attach_device",
      id: device.id,
      session: state.active,
    });
    applyStatus(status, false);
    state.gutterSig = "";
    renderGutter();
    loadDevices();
  } catch (err) {
    statusEl.textContent = err.message;
  }
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
    const line = document.createElement("p");
    const button = document.createElement("button");
    button.type = "button";
    button.className = "block";
    button.textContent = `Remove ${row.protocol} ${row.id}`;
    button.addEventListener("click", async () => {
      await api({ cmd: "remove_decoder", session: state.active, id: row.id });
      await refreshDecoders();
      await loadAnnotations();
    });
    line.append(button);
    host.append(line);
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
      <button type="button" id="edge-next">Next match</button>
      <button type="button" id="edge-prev">Previous match</button>
      <p id="edge-hit"></p>
    </div>`;
    document.getElementById("edge-next").addEventListener("click", () => searchFromTable(true));
    document.getElementById("edge-prev").addEventListener("click", () => searchFromTable(false));
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
    tr.addEventListener("click", () => panTo(row.start_sample));
    table.append(tr);
  }
  body.replaceChildren(table);
}

function panTo(sample) {
  const v = view();
  v.start = Math.max(0, sample - wave.clientWidth * v.spp * 0.2);
  v.userNavigated = true;
  clampView();
  scheduleTiles();
  drawRuler();
}

async function searchFromTable(forward) {
  const field = document.getElementById("table-search");
  const pattern = field && field.value ? field.value : settings.pattern;
  settings.pattern = pattern;
  const from = hoverSample();
  try {
    const data = await api({
      cmd: "search_pattern",
      session: state.active,
      channel: state.hoverChannel || 0,
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
    panTo(data.sample);
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

function hoverSample() {
  if (state.hoverX == null || state.total <= 0) return 0;
  return Math.min(state.total - 1, Math.max(0, Math.floor(view().start + state.hoverX * view().spp)));
}

async function searchPattern(forward) {
  const field = document.getElementById("set-pattern");
  settings.pattern = field.value;
  const from = hoverSample();
  try {
    const data = await api({
      cmd: "search_pattern",
      session: state.active,
      channel: 0,
      from,
      pattern: settings.pattern,
      forward,
    });
    if (data.sample == null) {
      statusEl.textContent = "no match";
      return;
    }
    const v = view();
    v.start = Math.max(0, data.sample - wave.clientWidth * v.spp * 0.25);
    v.userNavigated = true;
    clampView();
    scheduleTiles();
    statusEl.textContent = `match at ${data.sample}`;
  } catch (err) {
    statusEl.textContent = err.message;
  }
}

async function dropCursor(which) {
  const sample = hoverSample();
  try {
    const data = await api({ cmd: "set_cursor", session: state.active, which, sample });
    state.cursors = [data.a, data.b];
    drawRuler();
    const span = await api({ cmd: "cursor_span", session: state.active, channel: 0 });
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
  if (top + box.height + margin > window.innerHeight) top = ev.clientY - box.height - 12;
  hoverEl.style.left = left + "px";
  hoverEl.style.top = top + "px";
}

function hideHover() {
  state.hoverText = "";
  hoverEl.classList.add("hidden");
  paintStatus();
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
const tableSearch = document.getElementById("table-search");
tableSearch.addEventListener("keydown", (ev) => {
  if (ev.key !== "Enter") return;
  ev.preventDefault();
  if (state.tableTab === "edges") searchFromTable(true);
  else loadAnnotations();
});
document.getElementById("table-export").addEventListener("click", exportAnnotations);
renderTable();

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
  if (key === "r" || key === "R") {
    ev.preventDefault();
    const search = document.getElementById("table-search");
    if (search) search.focus();
    return;
  }
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
