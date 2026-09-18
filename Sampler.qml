import QtQuick
import Quickshell.Io

Item {
  id: root
  width: 0
  height: 0
  visible: false

  property real cpu: 0
  property real ram: 0
  property real down: 0
  property real up: 0
  property real disk: 0
  property int diskPulse: 0
  property bool ready: false
  property int intervalMs: 1000

  readonly property string scriptPath: {
    var url = Qt.resolvedUrl("sample.py").toString()
    if (url.indexOf("file://") === 0)
      return decodeURIComponent(url.substring(7))
    return url
  }

  function applyLine(line) {
    var text = String(line || "").trim()
    if (!text)
      return
    try {
      var sample = JSON.parse(text)
      if (typeof sample.cpu === "number")
        root.cpu = sample.cpu
      if (typeof sample.ram === "number")
        root.ram = sample.ram
      if (typeof sample.down === "number")
        root.down = sample.down
      if (typeof sample.up === "number")
        root.up = sample.up
      if (typeof sample.disk === "number")
        root.disk = sample.disk
      if (typeof sample.diskPulse === "number")
        root.diskPulse = sample.diskPulse
      root.ready = true
    } catch (e) {}
  }

  Process {
    id: samplerProc
    running: true
    command: ["python3", "-u", root.scriptPath, "--interval", String(Math.max(0.25, root.intervalMs / 1000))]
    stdout: SplitParser {
      onRead: function(line) { root.applyLine(line) }
    }
    onExited: restartTimer.restart()
  }

  Timer {
    id: restartTimer
    interval: 1500
    repeat: false
    onTriggered: {
      if (!samplerProc.running)
        samplerProc.running = true
    }
  }
}
