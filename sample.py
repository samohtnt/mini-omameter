#!/usr/bin/env python3
"""Sample CPU, RAM, network, and GPU RAM as 0–100 percentages.

Prints one JSON object per line. CPU and network are rate-based, so the
first line is emitted after two counter snapshots.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import time
from typing import Callable, Iterable


SKIP_IFACE_EXACT = {"lo"}
SKIP_IFACE_PREFIXES = (
    "docker",
    "br-",
    "veth",
    "virbr",
    "tun",
    "tap",
    "wg",
    "tailscale",
    "zt",
)


def read_text(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.read()
    except OSError:
        return ""


def parse_cpu(stat_text: str) -> tuple[int, int] | None:
    for line in stat_text.splitlines():
        if not line.startswith("cpu "):
            continue
        fields = line.split()
        if len(fields) < 5:
            return None
        values = [int(part) for part in fields[1:]]
        total = sum(values)
        idle = values[3] + (values[4] if len(values) > 4 else 0)
        return idle, total
    return None


def cpu_percent(previous: tuple[int, int], current: tuple[int, int]) -> float:
    prev_idle, prev_total = previous
    idle, total = current
    total_delta = total - prev_total
    if total_delta <= 0:
        return 0.0
    idle_delta = idle - prev_idle
    busy = 1.0 - (idle_delta / total_delta)
    return max(0.0, min(100.0, busy * 100.0))


def ram_percent(meminfo_text: str) -> float:
    total = 0
    available = None
    free = buffers = cached = 0
    for line in meminfo_text.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        key, raw = parts[0], parts[1]
        try:
            value = int(raw)
        except ValueError:
            continue
        if key == "MemTotal:":
            total = value
        elif key == "MemAvailable:":
            available = value
        elif key == "MemFree:":
            free = value
        elif key == "Buffers:":
            buffers = value
        elif key == "Cached:":
            cached = value
    if total <= 0:
        return 0.0
    if available is None:
        available = free + buffers + cached
    used = max(0, total - available)
    return max(0.0, min(100.0, used * 100.0 / total))


def parse_net_dev(text: str) -> dict[str, tuple[int, int]]:
    out: dict[str, tuple[int, int]] = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        name, rest = line.split(":", 1)
        name = name.strip()
        fields = rest.split()
        if len(fields) < 9:
            continue
        try:
            out[name] = (int(fields[0]), int(fields[8]))
        except ValueError:
            continue
    return out


def parse_default_routes(route_text: str) -> list[str]:
    found: list[str] = []
    for line in route_text.splitlines()[1:]:
        fields = line.split()
        if len(fields) > 1 and fields[1] == "00000000" and fields[0] not in found:
            found.append(fields[0])
    return found


def skip_iface(name: str) -> bool:
    if name in SKIP_IFACE_EXACT:
        return True
    return any(name.startswith(prefix) for prefix in SKIP_IFACE_PREFIXES)


def select_interfaces(route_ifaces: Iterable[str], all_ifaces: Iterable[str]) -> list[str]:
    routed = [name for name in route_ifaces if name in set(all_ifaces) and not skip_iface(name)]
    if routed:
        return routed
    return [name for name in all_ifaces if not skip_iface(name)]


def sum_bytes(net: dict[str, tuple[int, int]], ifaces: Iterable[str]) -> tuple[int, int]:
    rx = tx = 0
    for name in ifaces:
        entry = net.get(name)
        if not entry:
            continue
        rx += entry[0]
        tx += entry[1]
    return rx, tx


def net_percent(rate_bps: float, peak_bps: float, floor_bps: float = 1_000_000.0) -> tuple[float, float]:
    peak = max(peak_bps * 0.92, rate_bps, floor_bps)
    if peak <= 0:
        return 0.0, floor_bps
    return max(0.0, min(100.0, (rate_bps / peak) * 100.0)), peak


def gpu_from_sysfs(reader: Callable[[str], str] = read_text) -> tuple[int, int]:
    used = total = 0
    for used_path in sorted(glob.glob("/sys/class/drm/card*/device/mem_info_vram_used")):
        total_path = used_path[: -len("used")] + "total"
        try:
            u = int(reader(used_path).strip() or "0")
            t = int(reader(total_path).strip() or "0")
        except ValueError:
            continue
        if t > 0:
            used += max(0, u)
            total += t
    return used, total


def gpu_from_nvidia_smi(runner: Callable[..., str] | None = None) -> tuple[int, int]:
    if shutil.which("nvidia-smi") is None and runner is None:
        return 0, 0

    def run() -> str:
        if runner is not None:
            return runner()
        try:
            completed = subprocess.run(
                [
                    "nvidia-smi",
                    "--query-gpu=memory.used,memory.total",
                    "--format=csv,noheader,nounits",
                ],
                check=False,
                capture_output=True,
                text=True,
                timeout=0.6,
            )
        except (OSError, subprocess.TimeoutExpired):
            return ""
        return completed.stdout or ""

    used = total = 0
    for line in run().splitlines():
        parts = [part.strip() for part in line.split(",")]
        if len(parts) < 2:
            continue
        try:
            used += int(float(parts[0]))
            total += int(float(parts[1]))
        except ValueError:
            continue
    # nvidia-smi reports MiB; convert to bytes so it matches sysfs.
    return used * 1024 * 1024, total * 1024 * 1024


def gpu_percent(
    sysfs_reader: Callable[[str], str] = read_text,
    nvidia_runner: Callable[..., str] | None = None,
    allow_nvidia: bool = True,
) -> float:
    used, total = gpu_from_sysfs(sysfs_reader)
    if total <= 0 and allow_nvidia:
        used, total = gpu_from_nvidia_smi(nvidia_runner)
    if total <= 0:
        return 0.0
    return max(0.0, min(100.0, used * 100.0 / total))


class Sampler:
    def __init__(self, reader: Callable[[str], str] | None = None, now: Callable[[], float] | None = None):
        self.reader = reader or read_text
        self.now = now or time.monotonic
        self.prev_cpu: tuple[int, int] | None = None
        self.prev_rx = -1
        self.prev_tx = -1
        self.prev_ifaces: list[str] = []
        self.prev_stamp = 0.0
        self.net_peak = 1_000_000.0
        self.ready = False
        self._nvidia_failed = False

    def snapshot(self) -> dict[str, float]:
        stamp = self.now()
        cpu = parse_cpu(self.reader("/proc/stat"))
        ram = ram_percent(self.reader("/proc/meminfo"))
        net = parse_net_dev(self.reader("/proc/net/dev"))
        ifaces = select_interfaces(parse_default_routes(self.reader("/proc/net/route")), net.keys())
        rx, tx = sum_bytes(net, ifaces)

        cpu_pct = 0.0
        if cpu and self.prev_cpu:
            cpu_pct = cpu_percent(self.prev_cpu, cpu)
            self.ready = True
        if cpu:
            self.prev_cpu = cpu

        net_pct = 0.0
        elapsed = (stamp - self.prev_stamp) if self.prev_rx >= 0 else 0.0
        same = ifaces == self.prev_ifaces
        if self.prev_rx >= 0 and elapsed > 0 and same and rx >= self.prev_rx and tx >= self.prev_tx:
            rate = (rx + tx - self.prev_rx - self.prev_tx) / elapsed
            net_pct, self.net_peak = net_percent(rate, self.net_peak)

        self.prev_rx, self.prev_tx = rx, tx
        self.prev_ifaces = list(ifaces)
        self.prev_stamp = stamp

        allow_nvidia = not self._nvidia_failed
        gpu = gpu_percent(self.reader, allow_nvidia=allow_nvidia)
        if gpu == 0.0 and allow_nvidia and shutil.which("nvidia-smi") is not None:
            # A zero reading from nvidia-smi is valid; only disable after a hard fail.
            pass

        return {
            "cpu": round(cpu_pct, 2),
            "ram": round(ram, 2),
            "net": round(net_pct, 2),
            "gpu": round(gpu, 2),
        }


def emit(sample: dict[str, float]) -> None:
    sys.stdout.write(json.dumps(sample, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def run(interval: float) -> None:
    sampler = Sampler()
    sampler.snapshot()
    time.sleep(min(0.25, max(0.05, interval / 4)))
    emit(sampler.snapshot())
    while True:
        time.sleep(max(0.25, interval))
        emit(sampler.snapshot())


def main() -> int:
    parser = argparse.ArgumentParser(description="Emit Omameter JSON samples.")
    parser.add_argument("--interval", type=float, default=1.0, help="Seconds between samples.")
    parser.add_argument("--once", action="store_true", help="Print one sample and exit.")
    args = parser.parse_args()
    if args.once:
        sampler = Sampler()
        sampler.snapshot()
        time.sleep(0.15)
        emit(sampler.snapshot())
        return 0
    try:
        run(args.interval)
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        os._exit(0)
