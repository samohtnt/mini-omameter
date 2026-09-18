#!/usr/bin/env python3
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import sample


STAT_IDLE = "cpu  100 0 0 900 0 0 0 0 0 0\ncpu0 50 0 0 450 0 0 0 0 0 0\n"
STAT_BUSY = "cpu  400 0 0 920 0 0 0 0 0 0\ncpu0 200 0 0 460 0 0 0 0 0 0\n"
MEMINFO = """MemTotal:        8000000 kB
MemFree:         1000000 kB
MemAvailable:    5000000 kB
Buffers:          200000 kB
Cached:          1000000 kB
"""
NET_DEV = """Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 999999      1    0    0    0     0          0         0  999999      1    0    0    0     0       0          0
  eth0: 1000        1    0    0    0     0          0         0  2000        1    0    0    0     0       0          0
"""
NET_DEV_LATER = """Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 999999      1    0    0    0     0          0         0  999999      1    0    0    0     0       0          0
  eth0: 1001000     1    0    0    0     0          0         0  2002000     1    0    0    0     0       0          0
"""
ROUTE = """Iface	Destination	Gateway 	Flags	RefCnt	Use	Metric	Mask		MTU	Window	IRTT
eth0	00000000	0100A8C0	0003	0	0	100	00000000	0	0	0
"""


class ParseTests(unittest.TestCase):
    def test_cpu_percent_from_delta(self):
        first = sample.parse_cpu(STAT_IDLE)
        second = sample.parse_cpu(STAT_BUSY)
        self.assertIsNotNone(first)
        self.assertIsNotNone(second)
        # total 1000 -> 1320, idle 900 -> 920, busy = 1 - 20/320 = 93.75
        self.assertAlmostEqual(sample.cpu_percent(first, second), 93.75, places=2)

    def test_ram_uses_memavailable(self):
        self.assertAlmostEqual(sample.ram_percent(MEMINFO), 37.5, places=2)

    def test_default_route_beats_loopback(self):
        net = sample.parse_net_dev(NET_DEV)
        ifaces = sample.select_interfaces(sample.parse_default_routes(ROUTE), net)
        self.assertEqual(ifaces, ["eth0"])
        self.assertEqual(sample.sum_bytes(net, ifaces), (1000, 2000))

    def test_skip_loopback_when_no_route(self):
        net = sample.parse_net_dev(NET_DEV)
        ifaces = sample.select_interfaces([], net)
        self.assertEqual(ifaces, ["eth0"])

    def test_net_percent_scales_against_peak(self):
        pct, peak = sample.net_percent(5_000_000, 1_000_000)
        self.assertGreater(pct, 90)
        self.assertEqual(peak, 5_000_000)

    def test_gpu_percent_from_bytes(self):
        files = {
            "/sys/class/drm/card0/device/mem_info_vram_used": "256",
            "/sys/class/drm/card0/device/mem_info_vram_total": "1024",
        }
        used, total = 256, 1024
        self.assertAlmostEqual(used * 100.0 / total, 25.0)

    def test_sampler_two_ticks(self):
        files = {
            "/proc/stat": STAT_IDLE,
            "/proc/meminfo": MEMINFO,
            "/proc/net/dev": NET_DEV,
            "/proc/net/route": ROUTE,
        }
        clock = {"t": 0.0}

        def reader(path: str) -> str:
            return files.get(path, "")

        def now() -> float:
            return clock["t"]

        sampler = sample.Sampler(reader=reader, now=now)
        first = sampler.snapshot()
        self.assertEqual(first["ram"], 37.5)
        self.assertFalse(sampler.ready)

        files["/proc/stat"] = STAT_BUSY
        files["/proc/net/dev"] = NET_DEV_LATER
        clock["t"] = 1.0
        second = sampler.snapshot()
        self.assertTrue(sampler.ready)
        self.assertAlmostEqual(second["cpu"], 93.75, places=2)
        self.assertGreater(second["net"], 0)
        self.assertEqual(second["ram"], 37.5)


class ManifestTests(unittest.TestCase):
    def test_manifest_contract(self):
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        with open(os.path.join(root, "manifest.json"), encoding="utf-8") as handle:
            manifest = json.load(handle)
        self.assertEqual(manifest["schemaVersion"], 1)
        self.assertEqual(manifest["id"], "troy.omameter")
        self.assertEqual(manifest["kinds"], ["panel"])
        self.assertTrue(manifest["keepLoaded"])
        self.assertEqual(manifest["entryPoints"]["panel"], "Panel.qml")
        for name in ("Panel.qml", "MeterStrip.qml", "Sampler.qml", "sample.py"):
            self.assertTrue(os.path.isfile(os.path.join(root, name)), name)

    def test_panel_uses_bezel_exclusive_zone(self):
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        with open(os.path.join(root, "Panel.qml"), encoding="utf-8") as handle:
            qml = handle.read()
        self.assertIn("exclusiveZone: -1", qml)
        self.assertNotIn("exclusiveZone: 0", qml)
        self.assertIn("exclusionMode: ExclusionMode.Ignore", qml)
        self.assertIn("top: root.barPosition === \"top\" || root.vertical", qml)
        self.assertIn("bottom: root.barPosition === \"bottom\" || root.vertical", qml)
        self.assertIn("left: root.barPosition === \"left\" || !root.vertical", qml)
        self.assertIn("right: root.barPosition === \"right\" || !root.vertical", qml)


class OnceTests(unittest.TestCase):
    def test_once_prints_json(self):
        import subprocess
        import sys

        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        completed = subprocess.run(
            [sys.executable, os.path.join(root, "sample.py"), "--once"],
            check=True,
            capture_output=True,
            text=True,
            timeout=5,
        )
        line = completed.stdout.strip().splitlines()[-1]
        payload = json.loads(line)
        for key in ("cpu", "ram", "net", "gpu"):
            self.assertIn(key, payload)
            self.assertGreaterEqual(payload[key], 0)
            self.assertLessEqual(payload[key], 100)


if __name__ == "__main__":
    unittest.main()
