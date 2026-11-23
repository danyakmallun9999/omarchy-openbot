import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Detail popup for the OpenBot bar pill: what each agent is doing right now,
// what is waiting on a person, and the turns that just ended. Read-only; the
// only action is bringing the OpenBot window forward.
Panel {
  id: root

  moduleName: "danyakmallun.openbot"

  property var anchorItem: null
  property var hostWidget: null
  // Injected by BarWidget.qml. Not named `state`: Item.state is a QML built-in.
  property var source: null

  readonly property color foreground: bar ? (bar.barForeground !== undefined ? bar.barForeground : bar.foreground) : Color.foreground
  readonly property color urgent: bar ? (bar.urgent !== undefined ? bar.urgent : Color.urgent) : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool hasState: source !== null && source !== undefined
  readonly property var agents: hasState ? source.agents : []
  readonly property var questions: hasState ? source.questions : []
  readonly property var waits: hasState ? source.waits : []
  readonly property var recent: hasState ? source.recent : []
  readonly property bool anything: agents.length > 0 || questions.length > 0 || waits.length > 0

  readonly property string headline: {
    if (!hasState) return "Reading OpenBot…"
    if (!source.ok) return "OpenBot is not running"
    var parts = []
    if (agents.length > 0) parts.push(agents.length === 1 ? "1 agent working" : agents.length + " agents working")
    if (questions.length > 0) parts.push(questions.length === 1 ? "1 question waiting" : questions.length + " questions waiting")
    if (waits.length > 0) parts.push(waits.length === 1 ? "1 agent waiting" : waits.length + " agents waiting")
    if (parts.length === 0) return "Idle — no agent is working"
    return parts.join(" · ")
  }

  function openApp() {
    Quickshell.execDetached(["gtk-launch", "openbot"])
  }

  function refresh() {
    if (hasState) source.refresh()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  onOpenedChanged: if (opened) refresh()

  // ── rows ────────────────────────────────────────────────────────────────
  component AgentRow: Item {
    id: row
    required property var entry
    required property var stateRef
    required property color foreground
    required property string fontFamily
    required property bool expanded

    width: parent ? parent.width : 0
    implicitHeight: body.height + Style.space(8)

    AgentAvatar {
      id: avatar
      size: Style.space(24)
      avatarUrl: row.entry.avatarUrl
      seed: row.entry.seed
      hue: row.entry.hue
      avatarColor: row.entry.avatarColor
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.topMargin: Style.space(3)
    }

    Column {
      id: body
      anchors.left: avatar.right
      anchors.leftMargin: Style.space(11)
      anchors.right: parent.right
      spacing: Style.space(2)

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: row.entry.name
          color: row.foreground
          font.family: row.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          width: Math.min(implicitWidth, parent.width - elapsed.implicitWidth - Style.space(8))
          elide: Text.ElideRight
        }

        Text {
          id: elapsed
          textFormat: Text.PlainText
          text: {
            var tick = row.stateRef ? row.stateRef.clockSec : 0
            return row.entry.stalled
              ? "silent " + Model.ago(row.stateRef.liveQuiet(row.entry))
              : Model.duration(row.stateRef.liveElapsed(row.entry))
          }
          color: row.entry.stalled ? root.urgent : row.foreground
          font.family: row.fontFamily
          font.pixelSize: Style.font.bodySmall
          anchors.baseline: parent.children[0].baseline
        }
      }

      Text {
        textFormat: Text.PlainText
        text: {
          var parts = []
          if (row.entry.modelShort) parts.push(row.entry.modelShort)
          if (row.entry.steps > 0) parts.push(row.entry.steps + (row.entry.steps === 1 ? " step" : " steps"))
          return parts.join(" · ")
        }
        visible: text !== ""
        color: Qt.darker(row.foreground, 1.5)
        font.family: row.fontFamily
        font.pixelSize: Style.font.caption
        width: parent.width
        elide: Text.ElideRight
      }

      Text {
        textFormat: Text.PlainText
        text: row.entry.activity
        visible: row.expanded && text !== ""
        color: Qt.darker(row.foreground, 1.25)
        font.family: row.fontFamily
        font.pixelSize: Style.font.bodySmall
        width: parent.width
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        lineHeight: 1.15
      }
    }
  }

  component QuestionCard: Rectangle {
    id: card
    required property var entry
    required property color foreground
    required property color urgent
    required property string fontFamily

    width: parent ? parent.width : 0
    implicitHeight: cardBody.height + Style.space(20)
    radius: Style.cornerRadius
    color: Util.alpha(card.urgent, 0.10)
    border.width: 1
    border.color: Util.alpha(card.urgent, 0.35)

    Column {
      id: cardBody
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      spacing: Style.space(6)

      Row {
        width: parent.width
        spacing: Style.space(8)

        AgentAvatar {
          size: Style.space(20)
          avatarUrl: card.entry.avatarUrl
          seed: card.entry.seed
          hue: card.entry.hue
          avatarColor: card.entry.avatarColor
          anchors.verticalCenter: parent.verticalCenter
          pulsing: true
        }

        Text {
          textFormat: Text.PlainText
          text: card.entry.name
          color: card.urgent
          font.family: card.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          textFormat: Text.PlainText
          text: card.entry.ageText
          color: Util.alpha(card.urgent, 0.7)
          font.family: card.fontFamily
          font.pixelSize: Style.font.caption
          anchors.baseline: parent.children[0].baseline
        }
      }

      Text {
        textFormat: Text.PlainText
        text: card.entry.shortText
        visible: text !== ""
        color: card.foreground
        font.family: card.fontFamily
        font.pixelSize: Style.font.bodySmall
        width: parent.width
        wrapMode: Text.WordWrap
        maximumLineCount: 4
        elide: Text.ElideRight
        lineHeight: 1.2
      }
    }
  }

  component SectionLabel: Text {
    textFormat: Text.PlainText
    color: Qt.darker(root.foreground, 1.5)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1
  }

  component EmptyHint: Text {
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
    width: parent ? parent.width : 0
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: catcher
    contentWidth: popup.fittedContentWidth(Style.space(430))
    contentHeight: popup.fittedContentHeight(body.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: catcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: root.openApp()
      onTextKey: function(key) {
        if (key === "r") root.refresh()
        else if (key === "o") root.openApp()
      }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: body.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        Binding {
          when: scrollArea.contentItem !== null
          target: scrollArea.contentItem
          property: "interactive"
          value: body.implicitHeight > scrollArea.height
        }

        Column {
          id: body
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          PanelHero {
            width: parent.width
            foreground: root.foreground
            fontFamily: root.fontFamily
            title: "OpenBot"
            meta: root.headline
            detail: ""
            iconOpacity: root.questions.length > 0 ? 1.0 : 0.7

            iconComponent: Component {
              Item {
                width: Style.font.display
                height: Style.font.display

                Image {
                  anchors.fill: parent
                  source: Qt.resolvedUrl("assets/openbot-128.png")
                  sourceSize.width: width * 2
                  sourceSize.height: height * 2
                  smooth: true
                  mipmap: true
                  fillMode: Image.PreserveAspectFit
                  visible: root.questions.length === 0
                }

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: Model.GLYPH_QUESTION
                  visible: root.questions.length > 0
                  color: root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                }
              }
            }

            trailingControl: Component {
              Button {
                text: "Open"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.openApp()
              }
            }
          }

          // ── questions ──────────────────────────────────────────────────
          SectionLabel { visible: root.questions.length > 0; text: "NEEDS YOU" }
          Repeater {
            model: root.questions
            delegate: QuestionCard {
              required property var modelData
              entry: modelData
              foreground: root.foreground
              urgent: root.urgent
              fontFamily: root.fontFamily
            }
          }

          // ── running agents ─────────────────────────────────────────────
          SectionLabel { visible: root.agents.length > 0; text: "WORKING" }
          Repeater {
            model: root.agents
            delegate: AgentRow {
              required property var modelData
              entry: modelData
              stateRef: root.source
              foreground: root.foreground
              fontFamily: root.fontFamily
              expanded: true
            }
          }

          // ── waits ──────────────────────────────────────────────────────
          SectionLabel { visible: root.waits.length > 0; text: "WAITING" }
          Repeater {
            model: root.waits
            delegate: Row {
              required property var modelData
              width: body.width
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: Model.GLYPH_WAIT
                color: Util.alpha(root.urgent, 0.9)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                textFormat: Text.PlainText
                text: modelData.name + " · " + (modelData.note !== "" ? modelData.note : "on a teammate") + " · " + modelData.ageText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                width: body.width - Style.space(24)
                elide: Text.ElideRight
              }
            }
          }

          // ── finished ───────────────────────────────────────────────────
          SectionLabel { visible: root.recent.length > 0; text: "JUST FINISHED" }
          Repeater {
            model: root.recent
            delegate: Row {
              required property var modelData
              width: body.width
              spacing: Style.space(8)

              AgentAvatar {
                size: Style.space(16)
                avatarUrl: modelData.avatarUrl
                seed: modelData.seed
                hue: modelData.hue
                avatarColor: modelData.avatarColor
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: modelData.failed ? Model.GLYPH_FAILED : Model.GLYPH_DONE
                color: modelData.failed ? root.urgent : Util.alpha(root.foreground, 0.85)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                textFormat: Text.PlainText
                text: modelData.name + (modelData.failed ? " failed" : " finished")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                textFormat: Text.PlainText
                text: modelData.ageText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.baseline: parent.children[1].baseline
              }
            }
          }

          // ── empty / offline ────────────────────────────────────────────
          EmptyHint {
            visible: !root.hasState || !root.source.ok
            text: "Start OpenBot and any running agent shows up here automatically."
          }

          EmptyHint {
            visible: root.hasState && root.source.ok && !root.anything && root.recent.length === 0
            text: "No agent is working. Give one a task in OpenBot and this pill comes alive."
          }

          // ── actions ────────────────────────────────────────────────────
          PanelSeparator { foreground: root.foreground }

          RowLayout {
            width: parent.width
            spacing: Style.space(6)

            Button {
              text: "Open OpenBot"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.openApp()
            }

            Button {
              text: "Refresh"
              iconText: "󰑐"
              iconSpinning: root.hasState ? root.source.loading === true : false
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.refresh()
            }

            Item { Layout.fillWidth: true; height: 1 }

            Text {
              textFormat: Text.PlainText
              text: root.hasState && root.source.ok ? "read " + root.source.secondsSinceRead + "s ago" : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              Layout.alignment: Qt.AlignVCenter
            }
          }
        }
      }
    }
  }
}
