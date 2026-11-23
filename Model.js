.pragma library

// Pure helpers for the OpenBot bar widget and panel: parse the snapshot that
// scripts/state.sh prints, then turn it into short strings the bar can draw.
// Every string here is rendered with Text.PlainText, so markup in an agent's
// own wording is shown literally instead of being interpreted.

var SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]


var HUE_COLORS = {
  0: "#ea4335",
  30: "#f97316",
  55: "#eab308",
  100: "#8ece34",
  150: "#22c55e",
  185: "#06b6d4",
  215: "#3b82f6",
  245: "#5d67ee",
  280: "#a855f7",
  320: "#ec4899"
}
var PALETTE = ["#ea4335", "#f97316", "#eab308", "#8ece34", "#22c55e", "#06b6d4", "#3b82f6", "#5d67ee", "#a855f7", "#ec4899"]

function hashString(s) {
  var hash = 2166136261
  var str = String(s || "")
  for (var i = 0; i < str.length; i++) {
    hash ^= str.charCodeAt(i)
    hash = Math.imul(hash, 16777619)
  }
  return (hash >>> 0)
}

function avatarColor(hue, seed) {
  if (hue !== null && hue !== undefined && isFinite(Number(hue))) {
    var h = Math.round(Number(hue))
    if (HUE_COLORS[h]) return HUE_COLORS[h]
    var normH = ((h % 360) + 360) % 360 / 360
    return Qt.hsla(normH, 0.68, 0.52, 1.0)
  }
  var idx = hashString(seed) % PALETTE.length
  return PALETTE[idx]
}

// Literal glyphs, not \uXXXX escapes: these are five-hex-digit code points and
// a four-digit escape would split into U+F06A plus a stray digit.
var GLYPH_IDLE = "󰚩"      // nf-md-robot
var GLYPH_WORKING = "󰑐"   // nf-md-sync
var GLYPH_QUESTION = "󰘥"  // nf-md-help_circle
var GLYPH_DONE = "󰗠"      // nf-md-check_circle
var GLYPH_FAILED = "󰧠"    // nf-md-cloud_alert
var GLYPH_WAIT = "󰥔"      // nf-md-clock
var GLYPH_STALLED = "󰔟"   // nf-md-timer_sand

function asObject(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : ({})
}

function asArray(value) {
  return Array.isArray(value) ? value : []
}

function text(value, fallback) {
  var s = value === undefined || value === null ? "" : String(value)
  return s === "" ? (fallback === undefined ? "" : fallback) : s
}

function num(value, fallback) {
  var n = Number(value)
  return isFinite(n) ? n : (fallback === undefined ? 0 : fallback)
}

// Collapse whitespace and drop the markdown an agent's reasoning tends to
// carry, then cut on a word boundary. The result is display-only.
function plain(value, limit) {
  var s = String(value === undefined || value === null ? "" : value)
    .replace(/```[\s\S]*?```/g, " ")
    .replace(/`([^`]*)`/g, "$1")
    .replace(/[*_#>]+/g, "")
    .replace(/\s+/g, " ")
    .trim()
  if (!s) return ""
  var max = limit === undefined ? 0 : Math.max(8, Math.floor(limit))
  if (max > 0 && s.length > max) {
    s = s.slice(0, max)
    var cut = s.lastIndexOf(" ")
    if (cut > max * 0.55) s = s.slice(0, cut)
    s = s.replace(/[\s.,;:\-–—]+$/, "")
    s += "…"
  }
  return s
}

// "42s", "4:12", "1h04" — the bar keeps it to a few characters.
function duration(seconds) {
  var s = Math.max(0, Math.floor(num(seconds, 0)))
  if (s < 60) return s + "s"
  var m = Math.floor(s / 60)
  var r = s % 60
  if (m < 60) return m + ":" + (r < 10 ? "0" : "") + r
  var h = Math.floor(m / 60)
  var rest = m % 60
  return h + "h" + (rest < 10 ? "0" : "") + rest
}

function ago(seconds) {
  var s = Math.max(0, Math.floor(num(seconds, 0)))
  if (s < 5) return "just now"
  if (s < 60) return s + "s ago"
  if (s < 3600) return Math.floor(s / 60) + "m ago"
  if (s < 86400) return Math.floor(s / 3600) + "h ago"
  return Math.floor(s / 86400) + "d ago"
}

function modelShort(value) {
  var s = text(value)
  var slash = s.lastIndexOf("/")
  if (slash >= 0 && slash < s.length - 1) s = s.slice(slash + 1)
  return s
}

// A small, stable identity dot per agent, matching the hue OpenBot already
// stores for that agent's avatar.
function hueColor(hue, alpha) {
  var h = ((num(hue, 0) % 360) + 360) % 360 / 360
  return Qt.hsla(h, 0.45, 0.62, alpha === undefined ? 1 : alpha)
}

function agentState(agent, stalledAfterSec) {
  var a = asObject(agent)
  if (num(a.quiet, 0) >= num(stalledAfterSec, 240)) return "stalled"
  return "working"
}

function normalizeAgent(raw, stalledAfterSec) {
  var a = asObject(raw)
  var name = text(a.name, "Agent")
  return {
    turnId: text(a.turnId),
    agentId: text(a.agentId),
    name: name,
    shortName: plain(name, 16),
    thread: text(a.thread, name),
    model: text(a.model),
    modelShort: modelShort(a.model),
    hue: a.hue !== null && a.hue !== undefined ? num(a.hue) : null,
    seed: text(a.seed, a.agentId),
    avatarUrl: text(a.avatarUrl, ""),
    avatarColor: avatarColor(a.hue, a.seed),
    elapsed: num(a.elapsed, 0),
    elapsedText: duration(a.elapsed),
    steps: Math.max(0, Math.floor(num(a.steps, 0))),
    quiet: num(a.quiet, 0),
    quietText: ago(a.quiet),
    stalled: num(a.quiet, 0) >= num(stalledAfterSec, 240),
    state: agentState(a, stalledAfterSec),
    activity: plain(a.activity, 140),
    activityFull: plain(a.activity, 420)
  }
}

function normalizeQuestion(raw) {
  var q = asObject(raw)
  var body = plain(q.text, 600)
  body = body.replace(/^Question:\s*/i, "")
  return {
    turnId: text(q.turnId),
    requestId: text(q.requestId),
    agentId: text(q.agentId),
    name: text(q.name, "Agent"),
    thread: text(q.thread, ""),
    hue: q.hue !== null && q.hue !== undefined ? num(q.hue) : null,
    seed: text(q.seed, q.agentId),
    avatarUrl: text(q.avatarUrl, ""),
    avatarColor: avatarColor(q.hue, q.seed),
    age: num(q.age, 0),
    ageText: ago(q.age),
    text: body,
    shortText: plain(body, 180)
  }
}

function normalizeWait(raw) {
  var w = asObject(raw)
  return {
    agentId: text(w.agentId),
    name: text(w.name, "Agent"),
    note: plain(w.note, 160),
    age: num(w.age, 0),
    ageText: ago(w.age)
  }
}

function normalizeRecent(raw) {
  var r = asObject(raw)
  var failed = text(r.status) === "failed"
  return {
    turnId: text(r.turnId),
    name: text(r.name, "Agent"),
    thread: text(r.thread, ""),
    status: text(r.status, "completed"),
    hue: r.hue !== null && r.hue !== undefined ? num(r.hue) : null,
    seed: text(r.seed, ""),
    avatarUrl: text(r.avatarUrl, ""),
    avatarColor: avatarColor(r.hue, r.seed),
    failed: failed,
    ended: num(r.ended, 0),
    age: num(r.age, 0),
    ageText: ago(r.age)
  }
}

// Returns null when the payload is unreadable, so callers can keep the last
// good snapshot instead of blanking the bar on a single failed poll.
function parse(raw, stalledAfterSec) {
  var body = String(raw === undefined || raw === null ? "" : raw).trim()
  if (body === "") return null
  var data = null
  try {
    data = JSON.parse(body)
  } catch (e) {
    return null
  }
  if (!data || num(data.ok, 0) !== 1) return null

  var agents = []
  var rawAgents = asArray(data.agents)
  for (var i = 0; i < rawAgents.length; i++) agents.push(normalizeAgent(rawAgents[i], stalledAfterSec))

  var questions = []
  var rawQuestions = asArray(data.questions)
  for (var j = 0; j < rawQuestions.length; j++) questions.push(normalizeQuestion(rawQuestions[j]))

  var waits = []
  var rawWaits = asArray(data.waits)
  for (var k = 0; k < rawWaits.length; k++) waits.push(normalizeWait(rawWaits[k]))

  var now = num(data.now, 0)
  var recent = []
  var rawRecent = asArray(data.recent)
  for (var n = 0; n < rawRecent.length; n++) {
    var entry = normalizeRecent(rawRecent[n])
    entry.age = Math.max(0, now - entry.ended)
    entry.ageText = ago(entry.age)
    recent.push(entry)
  }

  return {
    ok: true,
    now: now,
    agents: agents,
    questions: questions,
    waits: waits,
    recent: recent,
    running: agents.length,
    questionCount: questions.length,
    waitCount: waits.length,
    recentCount: recent.length,
    stalled: agents.length > 0 && countStalled(agents) === agents.length
  }
}

function countStalled(agents) {
  var n = 0
  for (var i = 0; i < agents.length; i++) if (asObject(agents[i]).stalled === true) n++
  return n
}

// Polished 1-3 line tooltip with clear context and actionable hints.
function tooltipLines(snapshot, stalledAfterSec) {
  var s = asObject(snapshot)
  var lines = []
  var agents = asArray(s.agents)
  var questions = asArray(s.questions)
  var waits = asArray(s.waits)
  var recent = asArray(s.recent)

  if (!s.ok) {
    lines.push("OpenBot · Aplikasi belum berjalan")
    lines.push("Klik untuk membuka OpenBot")
    return lines
  }

  // 1. High priority: Question / needs confirmation
  if (questions.length > 0) {
    var q0 = questions[0]
    var qCount = questions.length > 1 ? " (" + questions.length + " pertanyaan)" : ""
    lines.push("Perlu konfirmasi: " + q0.name + qCount + " · " + q0.ageText)
    if (q0.shortText) lines.push("\"" + plain(q0.shortText, 90) + "\"")
    lines.push("Klik: buka panel konfirmasi · Klik kanan: refresh")
    return lines
  }

  // 2. Active working agents
  if (agents.length > 0) {
    var a0 = agents[0]
    if (agents.length === 1) {
      var stateLabel = a0.stalled ? "silent " + a0.quietText : "aktif " + a0.elapsedText
      lines.push("OpenBot · " + a0.name + " (" + stateLabel + ")")
      if (a0.activity) lines.push(plain(a0.activity, 95))
      else if (a0.modelShort) lines.push("Model: " + a0.modelShort + " · " + a0.steps + " steps")
    } else {
      lines.push("OpenBot · " + agents.length + " agen aktif (" + a0.name + " +" + (agents.length - 1) + ")")
      var act = a0.activity ? ": " + plain(a0.activity, 70) : ""
      lines.push(a0.name + " (" + a0.elapsedText + ")" + act)
    }
    lines.push("Klik: buka panel · Klik kanan: refresh")
    return lines
  }

  // 3. Waiting agents
  if (waits.length > 0) {
    var w0 = waits[0]
    var wCount = waits.length > 1 ? " (" + waits.length + " agen)" : ""
    lines.push("OpenBot · Menunggu" + wCount)
    lines.push(w0.name + ": " + (w0.note ? w0.note : "menunggu rekan agen"))
    lines.push("Klik: buka panel · Klik kanan: refresh")
    return lines
  }

  // 4. Recently finished turn (within doneFlash window)
  if (recent.length > 0 && num(recent[0].age, 999) <= 15) {
    var r0 = recent[0]
    var outcome = r0.failed ? "gagal" : "selesai"
    lines.push("OpenBot · " + r0.name + " " + outcome + " (" + r0.ageText + ")")
    lines.push("Klik: buka panel · Klik kanan: refresh")
    return lines
  }

  // 5. Standby / Idle
  lines.push("OpenBot · Standby (tidak ada agen aktif)")
  lines.push("Klik: buka panel · Klik kanan: refresh")
  return lines
}

function phase(snapshot, doneFlashSec) {
  var s = asObject(snapshot)
  if (!s.ok) return "offline"
  if (num(s.questionCount, 0) > 0) return "question"
  if (num(s.running, 0) > 0) return asArray(s.agents)[0].stalled === true ? "stalled" : "working"
  if (num(s.waitCount, 0) > 0) return "waiting"
  var recent = asArray(s.recent)
  if (recent.length > 0 && num(recent[0].age, 9999) <= num(doneFlashSec, 12)) {
    return recent[0].failed ? "failed" : "done"
  }
  return "idle"
}

function phaseGlyph(name) {
  if (name === "working") return GLYPH_WORKING
  if (name === "question") return GLYPH_QUESTION
  if (name === "done") return GLYPH_DONE
  if (name === "failed") return GLYPH_FAILED
  if (name === "waiting") return GLYPH_WAIT
  if (name === "stalled") return GLYPH_STALLED
  return GLYPH_IDLE
}

// Text beside the glyph. Kept short: the bar already holds a clock and a
// weather widget in the same centered group.
function headline(snapshot, limit) {
  var s = asObject(snapshot)
  var max = limit === undefined ? 14 : limit
  var agents = asArray(s.agents)
  var questions = asArray(s.questions)
  if (num(s.questionCount, 0) > 0) {
    var q = questions[0]
    if (questions.length > 1) return q.name + " +" + (questions.length - 1)
    return plain(q.name, max)
  }
  if (agents.length > 1) return plain(agents[0].name, max) + " +" + (agents.length - 1)
  if (agents.length === 1) return plain(agents[0].name, max)
  if (num(s.waitCount, 0) > 0) return "waiting"
  var recent = asArray(s.recent)
  if (recent.length > 0) {
    if (recent.length > 1) return recent.length + " finished"
    return plain(recent[0].name, max)
  }
  return ""
}

function trailing(snapshot, phaseName) {
  var s = asObject(snapshot)
  if (phaseName === "question") return "needs you"
  if (phaseName === "working" || phaseName === "stalled") {
    var agents = asArray(s.agents)
    if (agents.length === 0) return ""
    return agents[0].stalled ? agents[0].quietText : agents[0].elapsedText
  }
  if (phaseName === "waiting") return "waiting"
  if (phaseName === "done") return "done"
  if (phaseName === "failed") return "failed"
  if (phaseName === "offline") return "offline"
  return ""
}
