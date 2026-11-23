import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root

  moduleName: "danyakmallun.openbot"
  fixedEdge: "end"

  OpenBotPoller {
    id: status
    settings: root.settings
  }

  readonly property string phaseName: status.phase
  readonly property color barForeground: bar ? (bar.barForeground !== undefined ? bar.barForeground : bar.foreground) : Color.foreground
  readonly property color urgent: bar ? (bar.urgent !== undefined ? bar.urgent : Color.urgent) : Color.urgent
  readonly property color accentColor: Color.accent
  readonly property bool isWorking: root.phaseName === "working"

  readonly property var primaryAgent: status.primary

  readonly property string headText: root.phaseName === "idle" || root.phaseName === "offline"
    ? ""
    : Model.headline(status.snapshot, 16)

  readonly property string metaText: {
    var tick = status.clockSec
    if (vertical) return ""
    if (root.phaseName === "working") {
      var a = status.primary
      return a ? Model.duration(status.liveElapsed(a)) : ""
    }
    if (root.phaseName === "stalled") {
      var b = status.primary
      return b ? "silent " + Model.ago(status.liveQuiet(b)) : ""
    }
    if (root.phaseName === "question") return status.questionCount > 1 ? status.questionCount + " asks" : "needs you"
    if (root.phaseName === "waiting") return status.waitCount > 1 ? status.waitCount + " waits" : "waiting"
    if (root.phaseName === "done") return "done"
    if (root.phaseName === "failed") return "failed"
    if (root.phaseName === "offline") return "offline"
    return ""
  }

  readonly property color glyphColor: {
    if (root.phaseName === "question" || root.phaseName === "failed") return root.urgent
    if (root.phaseName === "working") {
      if (root.primaryAgent) return Model.hueColor(root.primaryAgent.hue, 1.0)
      return root.accentColor
    }
    if (root.phaseName === "stalled" || root.phaseName === "waiting") return Util.alpha(root.urgent, 0.9)
    if (root.phaseName === "done") return Util.alpha(root.barForeground, 0.9)
    if (root.phaseName === "offline") return Util.alpha(root.barForeground, 0.45)
    return root.barForeground
  }

  readonly property color baseTextColor: {
    if (root.phaseName === "question" || root.phaseName === "failed") return root.urgent
    if (root.phaseName === "stalled" || root.phaseName === "waiting" || root.phaseName === "done") return Util.alpha(root.barForeground, 0.8)
    if (root.phaseName === "offline") return Util.alpha(root.barForeground, 0.45)
    return root.barForeground
  }

  readonly property color shimmerDimColor: Qt.darker(root.barForeground, 1.35)
  readonly property color metaColor: Util.alpha(root.barForeground, 0.55)

  readonly property string tooltipText: {
    var tick = status.clockSec
    var lines = Model.tooltipLines(status.snapshot, status.stalledAfterSec)
    if (status.failed) lines.push("· " + status.failure)
    if (root.phaseName === "offline") lines = ["OpenBot · not running", "Start OpenBot to see agent activity"]
    return lines.join("\n")
  }

  // ── panel lifecycle ─────────────────────────────────────────────────────
  readonly property bool opened: loader.item ? loader.item.opened === true : false
  readonly property bool popoutSwitchClosing: loader.item ? loader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() { if (loader.item) loader.item.closeForPopoutSwitch() }
  function open() { if (loader.item) loader.item.open() }
  function close() { if (loader.item) loader.item.close() }
  function togglePanel() { if (loader.item) loader.item.toggle() }

  function inject() {
    if (!loader.item) return
    loader.item.bar = root.bar
    loader.item.settings = root.settings
    loader.item.source = status
    loader.item.anchorItem = button
    loader.item.hostWidget = root
  }

  function refreshNow() { status.refresh() }

  Loader {
    id: loader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.inject(); Qt.callLater(root.inject) }
  }

  implicitWidth: vertical ? barSize : button.implicitWidth
  implicitHeight: vertical ? Style.bar.iconSlot : button.implicitHeight

  onBarChanged: inject()
  onSettingsChanged: inject()

  FontMetrics {
    id: labelMetrics
    font.family: bar ? bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
  }

  FontMetrics {
    id: metaMetrics
    font.family: bar ? bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.bodySmall
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: " "
    labelVisible: false
    tooltipText: root.tooltipText
    fixedWidth: vertical
      ? barSize
      : ((root.phaseName === "idle" || root.phaseName === "offline")
        ? Style.bar.iconSlot
        : Math.round(contentBox.width + Style.space(16)))
    fixedHeight: vertical
      ? Style.bar.iconSlot
      : barSize

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton || mouseButton === Qt.MiddleButton) root.refreshNow()
      else root.togglePanel()
    }

    Item {
      id: contentBox
      anchors.centerIn: parent
      width: iconSlot.width + (nameText.visible ? Style.space(6) + nameText.implicitWidth : 0) + (metaText.visible ? Style.space(5) + metaText.implicitWidth : 0)
      height: Style.bar.iconCanvas
      scale: button.pressScale

      // 1. Agent Avatar / Rotating Glyph
      Item {
        id: iconSlot
        x: 0
        y: Math.round((parent.height - height) / 2)
        width: Style.space(14)
        height: Style.space(14)

        // Multi-agent indicator dot for vertical bar
        Rectangle {
          visible: root.vertical && status.running > 1
          width: Style.space(5)
          height: Style.space(5)
          radius: width / 2
          color: root.accentColor
          anchors.top: parent.top
          anchors.right: parent.right
          z: 10
        }

        // Active agent's individual bot avatar (shown while working)
        AgentAvatar {
          id: botAvatar
          anchors.centerIn: parent
          size: Style.space(14)
          visible: root.isWorking && root.primaryAgent !== null
          avatarUrl: root.primaryAgent ? root.primaryAgent.avatarUrl : ""
          seed: root.primaryAgent ? root.primaryAgent.seed : ""
          hue: root.primaryAgent ? root.primaryAgent.hue : null
          avatarColor: root.primaryAgent ? root.primaryAgent.avatarColor : root.glyphColor
          spinning: true
        }

        // State glyph when idle, questioning, or offline
        Text {
          id: iconGlyph
          anchors.centerIn: parent
          visible: !botAvatar.visible
          textFormat: Text.PlainText
          text: Model.phaseGlyph(root.phaseName)
          color: root.glyphColor
          font.family: bar ? bar.fontFamily : Style.font.family
          font.pixelSize: Style.bar.iconFont
          transformOrigin: Item.Center

          SequentialAnimation on opacity {
            running: root.phaseName === "question" && !Style.reduceMotion
            loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: Style.duration(700); easing.type: Easing.OutCubic }
            NumberAnimation { to: 1.0; duration: Style.duration(700); easing.type: Easing.OutCubic }
          }
        }
      }

      // 2. Agent Name with Glistening Shimmer Animation
      Text {
        id: nameText
        visible: !root.vertical && root.headText !== ""
        x: iconSlot.x + iconSlot.width + Style.space(6)
        y: Math.round((parent.height - height) / 2 + (labelMetrics.descent - labelMetrics.ascent + labelMetrics.tightBoundingRect("0").height) / 2)
        textFormat: Text.PlainText
        text: root.headText
        font.family: bar ? bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        font.bold: root.phaseName === "question" || root.phaseName === "working"
        color: root.baseTextColor

        SequentialAnimation on color {
          running: root.isWorking && !Style.reduceMotion
          loops: Animation.Infinite

          ColorAnimation {
            from: root.baseTextColor
            to: "#ffffff"
            duration: Style.duration(650)
            easing.type: Easing.InOutSine
          }
          ColorAnimation {
            from: "#ffffff"
            to: root.shimmerDimColor
            duration: Style.duration(650)
            easing.type: Easing.InOutSine
          }
          ColorAnimation {
            from: root.shimmerDimColor
            to: root.baseTextColor
            duration: Style.duration(400)
            easing.type: Easing.InOutSine
          }
          PauseAnimation {
            duration: Style.duration(350)
          }
        }
      }

      // 3. Elapsed Time
      Text {
        id: metaText
        visible: !root.vertical && root.metaText !== ""
        x: nameText.visible ? Math.round(nameText.x + nameText.implicitWidth + Style.space(5)) : Math.round(iconSlot.x + iconSlot.width + Style.space(6))
        y: Math.round((parent.height - height) / 2 + (metaMetrics.descent - metaMetrics.ascent + metaMetrics.tightBoundingRect("0").height) / 2)
        textFormat: Text.PlainText
        text: root.metaText
        font.family: bar ? bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
        color: root.metaColor
      }
    }
  }

  IpcHandler {
    target: "danyakmallun.openbot.ui"
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function toggle(): string { root.togglePanel(); return "ok" }
    function refresh(): string { root.refreshNow(); return "ok" }
    function status(): string {
      return JSON.stringify({
        phase: root.phaseName,
        running: status.running,
        questions: status.questionCount,
        waits: status.waitCount,
        readAt: status.fetchedAtMs
      })
    }
  }
}
