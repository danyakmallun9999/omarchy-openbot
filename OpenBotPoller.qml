import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// One read-only poll of the local OpenBot database, shared by the bar pill and
// its panel. scripts/state.sh does the actual query; this item only decides
// when to ask, keeps the last good snapshot through a failed poll, and exposes
// a second clock so elapsed times keep counting between reads.
Item {
  id: root

  property var settings: ({})

  property var snapshot: null
  property bool loading: false
  property bool failed: false
  property string failure: ""
  property double fetchedAtMs: 0
  property int clockSec: 0
  property int pollCount: 0

  // Read the widget's inline shell.json entry with a fallback.
  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    return Math.max(min, Math.min(max, n))
  }

  readonly property int stalledAfterSec: intSetting("stalledAfterSec", 240, 60, 3600)
  readonly property int doneFlashSec: intSetting("doneFlashSec", 14, 4, 300)
  readonly property int refreshIntervalMs: intSetting("refreshIntervalSec", 3, 1, 60) * 1000

  readonly property bool ok: snapshot !== null && snapshot.ok === true
  readonly property var agents: ok ? snapshot.agents : []
  readonly property var questions: ok ? snapshot.questions : []
  readonly property var waits: ok ? snapshot.waits : []
  readonly property var recent: ok ? snapshot.recent : []
  readonly property int running: agents.length
  readonly property int questionCount: questions.length
  readonly property int waitCount: waits.length
  readonly property bool needsYou: questionCount > 0
  readonly property bool active: running > 0 || questionCount > 0 || waitCount > 0
  readonly property int secondsSinceRead: {
    var tick = clockSec
    return fetchedAtMs > 0 ? Math.max(0, Math.round((Date.now() - fetchedAtMs) / 1000)) : 0
  }

  // Seconds since the last read, for bindings that must keep moving (elapsed
  // counters, the done flash) without polling the database for it.
  readonly property real drift: fetchedAtMs > 0 ? Math.max(0, (Date.now() - fetchedAtMs) / 1000) : 0

  function liveElapsed(agent) {
    var base = agent && isFinite(agent.elapsed) ? Number(agent.elapsed) : 0
    return Math.max(0, base + drift)
  }

  function liveQuiet(agent) {
    var base = agent && isFinite(agent.quiet) ? Number(agent.quiet) : 0
    return Math.max(0, base + drift)
  }

  function liveAge(item) {
    var base = item && isFinite(item.age) ? Number(item.age) : 0
    return Math.max(0, base + drift)
  }

  readonly property string phase: {
    // Depend on clockSec so the binding re-runs every second.
    var tick = clockSec
    if (!ok) return "offline"
    if (questionCount > 0) return "question"
    if (running > 0) {
      var stalled = true
      for (var i = 0; i < agents.length; i++) if (agents[i].stalled !== true) stalled = false
      return stalled ? "stalled" : "working"
    }
    if (waitCount > 0) return "waiting"
    if (recent.length > 0 && liveAge(recent[0]) <= doneFlashSec) return recent[0].failed ? "failed" : "done"
    return "idle"
  }

  readonly property var primary: {
    var tick = clockSec
    if (questions.length > 0) return null
    if (agents.length === 0) return null
    return agents[0]
  }

  readonly property string scriptPath: {
    var url = Qt.resolvedUrl("scripts/state.sh").toString()
    return url.replace(/^file:\/\//, "")
  }

  function refresh() {
    if (poll.running) return
    poll.running = true
  }

  function consume(raw) {
    var parsed = Model.parse(raw, stalledAfterSec)
    if (parsed === null) {
      failed = true
      failure = "unreadable snapshot"
      return
    }
    snapshot = parsed
    fetchedAtMs = Date.now()
    pollCount = pollCount + 1
    failed = false
    failure = ""
  }

  Process {
    id: poll
    command: [root.scriptPath]
    stdout: StdioCollector {
      id: pollStdout
      waitForEnd: true
      onStreamFinished: root.consume(text)
    }
    onRunningChanged: if (running) root.loading = true
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0 && root.snapshot === null) {
        root.failed = true
        root.failure = "poll exited " + exitCode
      }
    }
  }

  // Poll fast while something is happening, and slowly enough to stay out of
  // the way when the bar is idle.
  Timer {
    id: pollTimer
    interval: root.active ? Math.max(1000, Math.min(root.refreshIntervalMs, 2000)) : Math.max(3000, root.refreshIntervalMs)
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // A single second, so elapsed counters and the finished flash move between
  // polls without touching the database.
  Timer {
    id: clock
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.clockSec = root.clockSec + 1
  }

  // A wedged sqlite3 must not stall the loop forever.
  Timer {
    id: watchdog
    interval: 8000
    repeat: false
    running: poll.running
    onTriggered: if (poll.running) poll.running = false
  }

  Component.onCompleted: refresh()
}
