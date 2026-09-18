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
        id: overlay
        required property var modelData

        screen: modelData
        visible: root.showing
        color: "transparent"
        // Omarchy's bar (omarchy-bar) is WlrLayer.Top + ExclusionMode.Auto
        // with the same 3-edge anchors as a reserved strip. A matching thin
        // overlay is laid out in Hyprland's *usable* box, which starts on
        // the inner edge of that reservation — under a top bar, that is the
        // BOTTOM of the menubar.
        //
        // exclusiveZone: -1 is not enough: ExclusionMode.Ignore already
        // sends protocol -1, and a 3-edge surface can still be parked in
        // the usable box. Match KeyboardPanel / OSD / notifications: a
        // fullscreen Ignore overlay (covers the bar), then place the strip
        // on the output's outer edge (bezel), which is also the bar's
        // outer edge. Do not assign exclusiveZone; that setter forces
        // ExclusionMode.Normal.
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "omameter"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
          top: true
          bottom: true
          left: true
          right: true
        }

        MeterStrip {
          x: root.barPosition === "right" ? overlay.width - root.stripPx : 0
          y: root.barPosition === "bottom" ? overlay.height - root.stripPx : 0
          width: root.vertical ? root.stripPx : overlay.width
          height: root.vertical ? overlay.height : root.stripPx
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
