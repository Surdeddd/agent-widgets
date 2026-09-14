#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=10).stdout


def classify(value, warn, crit, higher_is_worse=True):
    if higher_is_worse:
        if value >= crit:
            return "critical"
        if value >= warn:
            return "warning"
        return "ok"
    if value <= crit:
        return "critical"
    if value <= warn:
        return "warning"
    return "ok"


def read_cpu_percent():
    out = run(["top", "-l", "1", "-n", "0"])
    match = re.search(r"CPU usage:\s*([\d.]+)% user,\s*([\d.]+)% sys", out)
    if not match:
        return 0.0
    return round(float(match.group(1)) + float(match.group(2)), 1)


def read_memory_percent():
    out = run(["vm_stat"])
    pages = {}
    for line in out.splitlines():
        match = re.match(r"Pages ([A-Za-z][A-Za-z ]*?):\s+(\d+)\.", line)
        if match:
            pages[match.group(1).strip()] = int(match.group(2))
    used = pages.get("active", 0) + pages.get("wired down", 0) + pages.get("occupied by compressor", 0)
    free = pages.get("free", 0) + pages.get("speculative", 0)
    total = used + free
    if total == 0:
        return 0.0
    return round(used / total * 100, 1)


def read_disk():
    out = run(["df", "-k", "/"])
    lines = [line for line in out.splitlines() if line.strip()]
    fields = lines[-1].split()
    total_kb = int(fields[1])
    avail_kb = int(fields[3])
    free_gb = avail_kb / (1024 * 1024)
    free_percent = (avail_kb / total_kb * 100) if total_kb else 0.0
    return round(free_gb, 1), round(free_percent, 1)


def read_battery():
    out = run(["pmset", "-g", "batt"])
    if "InternalBattery" not in out:
        return False, 0, "unknown"
    percent_match = re.search(r"(\d+)%", out)
    percent = int(percent_match.group(1)) if percent_match else 0
    if "not charging" in out:
        state = "charged"
    elif "discharging" in out:
        state = "discharging"
    elif "charging" in out:
        state = "charging"
    elif "charged" in out:
        state = "charged"
    else:
        state = "unknown"
    return True, percent, state


def load_cpu_history():
    path = os.environ.get("AW_PREVIOUS_PATH")
    if not path or not os.path.exists(path):
        return []
    try:
        with open(path) as handle:
            previous = json.load(handle)
        history = previous.get("cpuHistory", [])
        return [float(value) for value in history if isinstance(value, (int, float))]
    except (json.JSONDecodeError, OSError, ValueError, AttributeError):
        return []


cpu_percent = read_cpu_percent()
memory_percent = read_memory_percent()
disk_free_gb, disk_free_percent = read_disk()
has_battery, battery_percent, battery_state = read_battery()

cpu_status = classify(cpu_percent, 70, 90)
memory_status = classify(memory_percent, 75, 90)
disk_status = classify(disk_free_percent, 15, 5, higher_is_worse=False)
battery_status = "ok"
if has_battery and battery_state == "discharging":
    battery_status = classify(battery_percent, 20, 10, higher_is_worse=False)

severity = {"ok": 0, "warning": 1, "critical": 2}
candidates = [("cpu", cpu_status), ("memory", memory_status), ("disk", disk_status)]
if has_battery:
    candidates.append(("battery", battery_status))
worst_id, worst_status = max(candidates, key=lambda item: severity[item[1]])
if severity[worst_status] == 0:
    worst_id = "none"

cpu_history = load_cpu_history()
cpu_history.append(cpu_percent)
cpu_history = cpu_history[-12:]

result = {
    "overallStatus": worst_status,
    "worstMetric": worst_id,
    "cpuPercent": cpu_percent,
    "cpuStatus": cpu_status,
    "cpuHistory": cpu_history,
    "memoryPercent": memory_percent,
    "memoryStatus": memory_status,
    "diskFreeGB": disk_free_gb,
    "diskFreePercent": disk_free_percent,
    "diskStatus": disk_status,
    "hasBattery": has_battery,
    "batteryPercent": battery_percent,
    "batteryState": battery_state,
    "batteryStatus": battery_status,
}

print(json.dumps(result, ensure_ascii=False))
print("ok", file=sys.stderr)
