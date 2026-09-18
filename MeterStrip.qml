import QtQuick
import qs.Commons

Item {
  id: root

  property string edge: "top"
  property real cpu: 0
  property real ram: 0
  property real net: 0
  property real gpu: 0

  readonly property bool vertical: edge === "left" || edge === "right"
  readonly property bool fromBezelEnd: edge === "bottom" || edge === "right"
  readonly property int meterPx: 1
  readonly property color trackColor: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)

  readonly property var meters: {
    var seq = [
      { key: "cpu", value: root.cpu, hue: 0.38 },
      { key: "ram", value: root.ram, hue: 0.58 },
      { key: "net", value: root.net, hue: 0.83 },
      { key: "gpu", value: root.gpu, hue: 0.10 }
    ]
    if (root.fromBezelEnd)
      return [seq[3], seq[2], seq[1], seq[0]]
    return seq
  }

  function fillColor(hue, percent) {
    var p = Math.max(0, Math.min(100, Number(percent) || 0)) / 100
    return Qt.hsla(hue * (1 - p), 0.72 + 0.22 * p, 0.48, 0.95)
  }

  Grid {
    id: grid
    anchors.fill: parent
    columns: root.vertical ? root.meters.length : 1
    rows: root.vertical ? 1 : root.meters.length
    spacing: 0

    Repeater {
      model: root.meters.length

      Rectangle {
        required property int index
        readonly property var meter: root.meters[index]
        readonly property real amount: Math.max(0, Math.min(1, (Number(meter.value) || 0) / 100))

        width: root.vertical ? root.meterPx : grid.width
        height: root.vertical ? grid.height : root.meterPx
        color: root.trackColor

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          width: root.vertical ? parent.width : parent.width * parent.amount
          height: root.vertical ? parent.height * parent.amount : parent.height
          color: root.fillColor(parent.meter.hue, parent.meter.value)
        }
      }
    }
  }
}
