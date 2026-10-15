pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Загрузка CPU/RAM/GPU и температуры, с историей для графиков (последние 60 замеров, раз в 2 с).
Singleton {
    id: root

    property real cpu: 0
    property real ram: 0
    property real ramUsedGb: 0
    property real ramTotalGb: 0
    property real gpu: 0
    property real cpuTemp: 0
    property real gpuTemp: 0

    property var cpuHistory: new Array(60).fill(0)
    property var ramHistory: new Array(60).fill(0)
    property var gpuHistory: new Array(60).fill(0)

    property var prevIdle: 0
    property var prevTotal: 0

    // пути к датчикам ищем один раз
    property string gpuBusyPath: ""
    property string gpuTempPath: ""
    property string cpuTempPath: ""

    function push(arr, v): var { const a = arr.concat([v]); return a.length > 60 ? a.slice(a.length - 60) : a; }

    Process {
        running: true
        command: ["sh", "-c",
            "for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$f\" ] && echo \"gpu=$f\" && break; done;" +
            "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name); " +
            "case $n in amdgpu|nouveau|radeon) echo \"gputemp=$h/temp1_input\";; " +
            "coretemp|k10temp|zenpower) for t in temp1_input temp2_input; do [ -r $h/$t ] && echo \"cputemp=$h/$t\" && break; done;; esac; done"]
        stdout: SplitParser {
            onRead: line => {
                const [k, v] = line.split("=");
                if (k === "gpu") root.gpuBusyPath = v;
                else if (k === "gputemp" && !root.gpuTempPath) root.gpuTempPath = v;
                else if (k === "cputemp" && !root.cpuTempPath) root.cpuTempPath = v;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            mem.reload();
            if (root.gpuBusyPath) gpuBusy.reload();
            if (root.gpuTempPath) gpuT.reload();
            if (root.cpuTempPath) cpuT.reload();
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const p = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = p[3] + p[4], total = p.reduce((s, x) => s + x, 0);
            if (root.prevTotal > 0) {
                const dt = total - root.prevTotal, di = idle - root.prevIdle;
                root.cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0;
                root.cpuHistory = root.push(root.cpuHistory, root.cpu);
            }
            root.prevIdle = idle;
            root.prevTotal = total;
        }
    }
    FileView {
        id: mem
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const get = k => Number((t.match(new RegExp(`^${k}:\\s+(\\d+)`, "m")) ?? [0, 0])[1]);
            const total = get("MemTotal"), avail = get("MemAvailable");
            root.ramTotalGb = total / 1048576;
            root.ramUsedGb = (total - avail) / 1048576;
            root.ram = total > 0 ? (total - avail) / total : 0;
            root.ramHistory = root.push(root.ramHistory, root.ram);
        }
    }
    FileView {
        id: gpuBusy
        path: root.gpuBusyPath
        onLoaded: {
            root.gpu = Number(text().trim()) / 100;
            root.gpuHistory = root.push(root.gpuHistory, root.gpu);
        }
    }
    FileView { id: gpuT; path: root.gpuTempPath; onLoaded: root.gpuTemp = Number(text().trim()) / 1000 }
    FileView { id: cpuT; path: root.cpuTempPath; onLoaded: root.cpuTemp = Number(text().trim()) / 1000 }
}
