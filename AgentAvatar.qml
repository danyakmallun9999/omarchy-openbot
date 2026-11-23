import QtQuick
import qs.Commons
import "Model.js" as Model

// Native avatar for OpenBot agents: renders either a custom uploaded image
// (avatarUrl) or the procedural PlushBot character (squircle in the agent's
// signature hue with expressive bot eyes).
Item {
  id: root

  property real size: Style.space(26)
  property string avatarUrl: ""
  property string seed: ""
  property var hue: null
  property color avatarColor: Model.avatarColor(hue, seed)
  property bool showEyes: true
  property bool spinning: false
  property bool pulsing: false

  width: size
  height: size

  readonly property bool hasCustomImage: avatarUrl !== "" && avatarUrl !== null && avatarUrl !== undefined

  // Rounded squircle container
  Rectangle {
    id: body
    anchors.fill: parent
    radius: Math.round(root.size * 0.32)
    color: root.hasCustomImage ? "transparent" : root.avatarColor
    clip: true

    Behavior on color { ColorAnimation { duration: Style.duration(200) } }

    // Custom uploaded image
    Image {
      id: customImage
      anchors.fill: parent
      visible: root.hasCustomImage
      source: root.avatarUrl
      fillMode: Image.PreserveAspectCrop
      smooth: true
      mipmap: true
    }

    // Procedural PlushBot face eyes
    Row {
      id: eyes
      anchors.centerIn: parent
      visible: !root.hasCustomImage && root.showEyes
      spacing: Math.max(2, Math.round(root.size * 0.16))

      // Left eye
      Rectangle {
        width: Math.max(2, Math.round(root.size * 0.17))
        height: Math.max(2, Math.round(root.size * 0.22))
        radius: width / 2
        color: "#18181b"
      }

      // Right eye
      Rectangle {
        width: Math.max(2, Math.round(root.size * 0.17))
        height: Math.max(2, Math.round(root.size * 0.22))
        radius: width / 2
        color: "#18181b"
      }
    }
  }

  // Optional spinning halo / border when the agent is working in the bar
  Rectangle {
    id: ring
    visible: root.spinning
    anchors.fill: parent
    anchors.margins: -1
    radius: body.radius + 1
    color: "transparent"
    border.width: 1
    border.color: Util.alpha(root.avatarColor, 0.6)

    RotationAnimation on rotation {
      from: 0
      to: 360
      duration: Style.duration(1200)
      loops: Animation.Infinite
      running: root.spinning && !Style.reduceMotion
    }
  }

  // Subtle pulsing animation when asking for attention
  SequentialAnimation on opacity {
    running: root.pulsing && !Style.reduceMotion
    loops: Animation.Infinite
    NumberAnimation { to: 0.45; duration: Style.duration(700); easing.type: Easing.OutCubic }
    NumberAnimation { to: 1.0; duration: Style.duration(700); easing.type: Easing.OutCubic }
  }
}
