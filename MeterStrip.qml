import QtQuick
import qs.Commons

Item {
  id: root

  property string edge: "top"
  property string meter: "cpu"
  property real cpu: 0
  property real ram: 0
  property real down: 0
  property real up: 0
  property real disk: 0
  property int diskPulse: 0

  readonly property bool vertical: edge === "left" || edge === "right"
  readonly property bool networkOnly: meter === "network"
  readonly property int meterPx: networkOnly ? 1 : 3
  readonly property color trackColor: networkOnly ? Color.muted : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)

  readonly property var meters: {
    if (root.meter === "network")
      return [
        { key: "up", value: root.up, baseColor: Color.bar.text },
        { key: "down", value: root.down, baseColor: Color.accent }
      ]
    if (root.meter === "ram")
      return [{ key: "ram", value: root.ram, baseColor: Color.bar.text }]
    if (root.meter === "disk")
      return [{ key: "disk", value: root.disk, baseColor: Color.muted }]
    return [{ key: "cpu", value: root.cpu, baseColor: Color.accent }]
  }

  function fillColor(baseColor, percent) {
    var p = Math.max(0, Math.min(100, Number(percent) || 0)) / 100
    var hot = Color.bar.active
    return Qt.rgba(
      baseColor.r * (1 - p) + hot.r * p,
      baseColor.g * (1 - p) + hot.g * p,
      baseColor.b * (1 - p) + hot.b * p,
      0.95
    )
  }

  Grid {
    id: grid
    anchors.fill: parent
    columns: root.vertical || root.networkOnly ? root.meters.length : 1
    rows: root.vertical || root.networkOnly ? 1 : root.meters.length
    spacing: 0

    Repeater {
      model: root.meters.length

      Rectangle {
        id: meterItem
        required property int index
        readonly property var meter: root.meters[index]
        readonly property real targetAmount: {
          var amount = Math.max(0, Math.min(1, (Number(meter.value) || 0) / 100))
          if (root.networkOnly && amount > 0 && grid.width > 0)
            amount = Math.max(amount, 2 / grid.width)
          return amount
        }
        readonly property int pulse: root.diskPulse
        property real displayedAmount: 0
        property real peakAmount: 0
        property real peakOpacity: 0
        property bool ready: false

        function applySample() {
          fillAnimation.stop()
          fillAnimation.from = displayedAmount
          fillAnimation.to = targetAmount
          fillAnimation.duration = targetAmount > displayedAmount ? 280 : 900
          fillAnimation.start()

          if (root.meter === "disk") {
            peakAmount = targetAmount
            if (peakOpacity === 0)
              peakOpacity = 0.35
          } else if (targetAmount > 0 && (targetAmount > peakAmount || peakOpacity === 0)) {
            peakAmount = targetAmount
            peakFade.stop()
            peakOpacity = 0.95
            peakHold.restart()
          }
        }

        Component.onCompleted: {
          ready = true
          applySample()
        }
        onTargetAmountChanged: {
          if (ready)
            applySample()
        }
        onPulseChanged: {
          if (ready && root.meter === "disk" && pulse > 0)
            diskFlash.restart()
        }

        width: root.vertical ? root.meterPx : root.networkOnly ? grid.width / 2 : grid.width
        height: root.vertical ? grid.height : root.meterPx
        color: root.trackColor

        NumberAnimation {
          id: fillAnimation
          target: meterItem
          property: "displayedAmount"
          easing.type: Easing.OutCubic
        }

        Timer {
          id: peakHold
          interval: 1400
          onTriggered: peakFade.start()
        }

        NumberAnimation {
          id: peakFade
          target: meterItem
          property: "peakOpacity"
          to: 0
          duration: 4200
          easing.type: Easing.OutCubic
        }

        SequentialAnimation {
          id: diskFlash
          NumberAnimation { target: meterItem; property: "peakOpacity"; to: 1; duration: 90 }
          PauseAnimation { duration: 130 }
          NumberAnimation { target: meterItem; property: "peakOpacity"; to: 0.35; duration: 650 }
        }

        Rectangle {
          x: root.vertical ? 0 : root.networkOnly ? (meterItem.index === 0 ? parent.width - width : 0) : (parent.width - width) / 2
          y: root.vertical ? parent.height - height : 0
          width: root.vertical ? parent.width : parent.width * parent.displayedAmount
          height: root.vertical ? parent.height * parent.displayedAmount : parent.height
          color: root.fillColor(parent.meter.baseColor, parent.displayedAmount * 100)
        }

        Rectangle {
          visible: root.vertical
          x: 0
          y: Math.max(0, Math.min(parent.height - height, parent.height * (1 - parent.peakAmount) - height / 2))
          width: parent.width
          height: 2
          color: root.meter === "disk" ? Color.bar.active : Color.bar.text
          opacity: parent.peakOpacity
        }

        Repeater {
          model: root.vertical ? 0 : root.networkOnly ? 1 : 2

          Rectangle {
            required property int index
            x: Math.max(0, Math.min(parent.width - width,
                                    root.networkOnly
                                      ? (meterItem.index === 0 ? parent.width * (1 - parent.peakAmount) : parent.width * parent.peakAmount) - width / 2
                                      : parent.width * (1 + (index === 0 ? -1 : 1) * parent.peakAmount) / 2 - width / 2))
            y: 0
            width: 2
            height: parent.height
            color: Color.bar.text
            opacity: parent.peakOpacity
          }
        }
      }
    }
  }
}
