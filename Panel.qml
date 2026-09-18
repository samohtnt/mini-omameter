import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: true

  property string configPosition: "top"

  readonly property string barPosition: {
    var pos = ""
    if (root.shell && root.shell.bar && root.shell.bar.position)
      pos = String(root.shell.bar.position)
    else if (root.shell && root.shell.barConfig && root.shell.barConfig.position)
      pos = String(root.shell.barConfig.position)
    else
      pos = root.configPosition
    if (["top", "bottom", "left", "right"].indexOf(pos) === -1)
      return "top"
    return pos
  }
  readonly property bool barHidden: !!(root.shell && root.shell.bar && root.shell.bar.barHidden === true)
  readonly property bool vertical: barPosition === "left" || barPosition === "right"
  readonly property int meterCount: 4
  readonly property int stripPx: meterCount
  readonly property bool showing: opened && !barHidden

  function open(payloadJson) {
    root.opened = true
  }

  function close() {
    root.opened = false
  }

  function readConfigPosition(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      var pos = parsed && parsed.bar ? String(parsed.bar.position || "") : ""
      if (["top", "bottom", "left", "right"].indexOf(pos) !== -1)
        root.configPosition = pos
    } catch (e) {}
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.readConfigPosition(text())
    onFileChanged: reload()
  }

  Sampler {
    id: stats
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        required property var modelData

        screen: modelData
        visible: root.showing
        color: "transparent"
        // Zone 0 yields to the bar and sits on its inner edge (under a top
        // bar). -1 is the layer-shell "real output edge" value, so meters
        // sit on the bezel side. Set last: exclusiveZone writes the protocol
        // value and would clobber Ignore if it came first as 0.
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: -1
        implicitWidth: root.vertical ? root.stripPx : 0
        implicitHeight: root.vertical ? 0 : root.stripPx
        mask: Region {}
        WlrLayershell.namespace: "omameter"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
          top: root.barPosition === "top" || root.vertical
          bottom: root.barPosition === "bottom" || root.vertical
          left: root.barPosition === "left" || !root.vertical
          right: root.barPosition === "right" || !root.vertical
        }

        MeterStrip {
          anchors.fill: parent
          edge: root.barPosition
          cpu: stats.cpu
          ram: stats.ram
          net: stats.net
          gpu: stats.gpu
        }
      }
    }
  }
}
