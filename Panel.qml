import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: true

  readonly property bool barHidden: !!(root.shell && root.shell.bar && root.shell.bar.barHidden === true)
  readonly property bool showing: opened && !barHidden

  function open(payloadJson) {
    root.opened = true
  }

  function close() {
    root.opened = false
  }

  Sampler { id: stats; active: root.opened }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        required property var modelData
        screen: modelData
        visible: root.showing
        color: Color.bar.background
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: 3
        mask: Region {}
        WlrLayershell.namespace: "omameter-cpu"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true; right: true }
        MeterStrip { anchors.fill: parent; meter: "cpu"; cpu: stats.cpu }
      }
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        required property var modelData
        screen: modelData
        visible: root.showing
        color: Color.bar.background
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 3
        mask: Region {}
        WlrLayershell.namespace: "omameter-ram"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true }
        MeterStrip { anchors.fill: parent; meter: "ram"; vertical: true; ram: stats.ram }
      }
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        required property var modelData
        screen: modelData
        visible: root.showing
        color: Color.bar.background
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 3
        mask: Region {}
        WlrLayershell.namespace: "omameter-disk"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; bottom: true; right: true }
        MeterStrip { anchors.fill: parent; meter: "disk"; vertical: true; disk: stats.disk; diskPulse: stats.diskPulse }
      }
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        required property var modelData
        screen: modelData
        visible: root.showing
        color: Color.bar.background
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: 2
        mask: Region {}
        WlrLayershell.namespace: "omameter-network"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { bottom: true; left: true; right: true }
        MeterStrip {
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: 1
          meter: "network"
          down: stats.down
          up: stats.up
        }
      }
    }
  }
}
