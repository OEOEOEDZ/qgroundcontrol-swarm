cat > ~/swarm-only/README.md << 'ENDREADME'
# QGroundControl — SwarmDashboard v2
**Multi-UAV Swarm Management Extension for QGroundControl**

Internship project — USTH Hanoi 2026  
Student: Yacine Abdi (ITS2, EPISEN/UPEC)  
Supervisor: Prof. Pham Xuan Tung  
GitHub: github.com/OEOEOEDZ/qgroundcontrol-swarm

---

## What This Project Does

This project extends QGroundControl (QGC) with a **SwarmDashboard** — a custom QML overlay enabling real-time supervision and grouped control of a multi-UAV swarm. Validated with 3 simultaneous PX4 SITL drones in Gazebo Harmonic.

### Features
- Per-drone selection (click any card; shortcuts: ALL, NONE, LEADER)
- Real-time telemetry per drone: LAT, LON, ALT (AGL), SPD, HDG, BAT% with color coding
- Leader election algorithm with automatic failover every 2 seconds
- Configurable takeoff altitude (1–50m) and max speed (1–20 m/s)
- In-flight altitude change via `guidedModeChangeAltitude(delta, false)`
- All commands apply only to selected drones
- No C++ modifications required — pure QML implementation

---

## Repository Contents

| File | Purpose |
|------|---------|
| `SwarmDashboard.qml` | Main dashboard component — all UI and logic |
| `CMakeLists.txt` | Modified build file — adds SwarmDashboard.qml as QML resource |
| `FlyViewWidgetLayer.qml` | Modified overlay — instantiates SwarmDashboard |
| `install.sh` | Automatic installation script |

---

## Quick Install (Recommended)

If you already have a QGC source tree cloned, run:

```bash
git clone https://github.com/OEOEOEDZ/qgroundcontrol-swarm.git
cd qgroundcontrol-swarm
bash install.sh ~/qgroundcontrol
cd ~/qgroundcontrol/build && ninja -j4
```

Then relaunch QGC. The SwarmDashboard appears automatically when drones connect.

---

## Exact Changes Made to QGC

This section shows precisely what was changed inside the QGC source tree so you can apply the changes manually if needed.

### Change 1 — `src/FlyView/CMakeLists.txt`

One line was added after `MultiVehicleList.qml`:

```diff
         MultiVehicleList.qml
+        SwarmDashboard.qml
         ObstacleDistanceOverlay.qml
```

This registers `SwarmDashboard.qml` as a Qt resource so it is compiled into the QGC binary.

### Change 2 — `src/FlyView/FlyViewWidgetLayer.qml`

One block was added after the last closing brace of the existing left-panel component:

```diff
+    SwarmDashboard {
+        id:                 swarmDashboard
+        anchors.left:       toolStrip.right
+        anchors.leftMargin: _toolsMargin
+        anchors.top:        toolStrip.bottom
+        anchors.topMargin:  _toolsMargin
+        z:                  QGroundControl.zOrderWidgets
+        visible:            QGroundControl.multiVehicleManager.vehicles.count > 0
+    }
```

This instantiates the SwarmDashboard as an overlay in the QGC fly view. It is hidden when no drones are connected and appears automatically when the first drone connects.

### Change 3 — `src/FlyView/SwarmDashboard.qml`

This is a new file — it did not exist in the original QGC source. Copy it from this repository into `src/FlyView/`.

---

## System Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| OS | Ubuntu 22.04 LTS | Or WSL2 on Windows 11 |
| Qt | 6.10.3 | Installed via aqtinstall — do NOT use system Qt |
| cmake | 3.28+ | May need symlink fix (see below) |
| ninja | any | Build system |
| PX4-Autopilot | main branch 2026 | For SITL simulation |
| Gazebo | Harmonic 8.12.0 | `gz-harmonic` package |
| QGroundControl | Qt6 daily build | Cloned from source |

---

## Step 0 — Find Your WSL2 Gateway IP

> This IP changes every time you restart WSL2 or your PC. Always check before running.

```bash
cat /etc/resolv.conf | grep nameserver | awk '{print $2}'
```

This returns your Windows gateway IP (e.g. `172.27.80.1`). Replace every occurrence of `172.27.80.1` in this guide with your actual value.

---

## Step 1 — Install System Dependencies

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install -y git cmake ninja-build build-essential python3-pip \
    libsecret-1-dev libxkbcommon-dev libgl1-mesa-dev libglu1-mesa-dev \
    x11-apps

# Fix WSL2 runtime directory permissions — required for Gazebo GUI
# Run this after every system reboot
sudo chmod 700 /run/user/1000
```

---

## Step 2 — Install Qt 6.10.3

Do not use the system Qt packages — they are too old. Install Qt 6.10.3 via aqtinstall:

```bash
pip3 install aqtinstall

~/.local/bin/aqt install-qt linux desktop 6.10.3 linux_gcc_64 \
  -m qt5compat qtcharts qtimageformats qtlocation qtpositioning \
  qtsensors qtserialport qtmultimedia qtshadertools qtwebsockets \
  qtwebchannel qtwebengine qtspeech qtscxml qtremoteobjects \
  qtnetworkauth qtserialbus qtconnectivity qtvirtualkeyboard \
  qtdatavis3d qtgraphs qtquick3d qtquick3dphysics qthttpserver \
  qtlottie -O ~/Qt
```

Verify:
```bash
~/Qt/6.10.3/gcc_64/bin/qmake --version
# Expected: QMake version 3.1 / Using Qt version 6.10.3
```

---

## Step 3 — Clone and Build QGroundControl

> **CRITICAL: always use `--recursive`** — without it, submodules are missing and the build fails with cryptic errors.

```bash
git clone https://github.com/mavlink/qgroundcontrol.git --recursive
cd qgroundcontrol
```

### Fix cmake symlink if needed

```bash
sudo ln -sf /usr/local/bin/cmake /usr/bin/cmake
cmake --version
# Expected: cmake version 3.28.x or higher
```

### Configure

```bash
mkdir build && cd build
cmake .. -GNinja \
         -DCMAKE_BUILD_TYPE=Debug \
         -DCMAKE_PREFIX_PATH=~/Qt/6.10.3/gcc_64
```

### Fix SDL3 PCH error (if build fails partway)

```bash
touch ~/qgroundcontrol/build/_deps/sdl3-build/CMakeFiles/SDL3-static.dir/cmake_pch.hxx.gch
```

### Build

```bash
ninja -j4
# Full build: 20–40 minutes
# Expected final line: [1771/1771] Linking CXX executable Debug/QGroundControl
```

### Test the build

```bash
cd ~/qgroundcontrol/build
LIBGL_ALWAYS_SOFTWARE=1 QSG_RENDER_LOOP=basic ./Debug/QGroundControl
```

QGC opens with the default interface — no SwarmDashboard yet. Close it before continuing.

> `LIBGL_ALWAYS_SOFTWARE=1` — forces software OpenGL, required on Intel integrated GPUs and WSL2.  
> `QSG_RENDER_LOOP=basic` — disables async Qt render loop which crashes on some WSL2 setups.

---

## Step 4 — Integrate the SwarmDashboard

### Option A — Automatic (recommended)

```bash
cd ~
git clone https://github.com/OEOEOEDZ/qgroundcontrol-swarm.git
cd qgroundcontrol-swarm
bash install.sh ~/qgroundcontrol
```

### Option B — Manual

```bash
cp SwarmDashboard.qml    ~/qgroundcontrol/src/FlyView/
cp CMakeLists.txt        ~/qgroundcontrol/src/FlyView/
cp FlyViewWidgetLayer.qml ~/qgroundcontrol/src/FlyView/
```

### Rebuild (fast — only changed files)

```bash
cd ~/qgroundcontrol/build
ninja -j4
# Expected time: 30–60 seconds
```

> Every time you modify `SwarmDashboard.qml`, run `ninja -j4` and relaunch QGC.  
> QML files are compiled into the binary — there is no hot-reload.

---

## Step 5 — Install PX4-Autopilot and Gazebo

### Install Gazebo Harmonic

```bash
sudo apt install -y gz-harmonic
gz sim --version
# Expected: Gazebo Sim, version 8.x.x
```

### Clone PX4

```bash
cd ~
git clone https://github.com/PX4/PX4-Autopilot.git --recursive
cd PX4-Autopilot
bash ./Tools/setup/ubuntu.sh
```

Reopen terminal after setup script completes.

### First build — validates the environment

```bash
cd ~/PX4-Autopilot
HEADLESS=1 make px4_sitl gz_x500
```

First build takes 10–15 minutes. When `pxh>` appears, type `quit`. Environment is validated.

If build fails with `gz_x500 unknown target`:
```bash
rm -rf build && HEADLESS=1 make px4_sitl gz_x500
```

---

## Step 6 — Run the 3-Drone Simulation

Open **5 separate terminals**. Run in order. Wait for each to be ready before starting the next.

### Why gz sim -g in a separate terminal?

Gazebo Harmonic separates the **physics server** from the **GUI client**. PX4 starts the physics server internally when launched with `HEADLESS=0`. The command `gz sim -g` launches only the GUI client which connects to that already-running server. This is the correct and stable approach for Gazebo Harmonic (v8+).

---

### Terminal 1 — Gazebo GUI

```bash
sudo chmod 700 /run/user/1000
export DISPLAY=:0
export LIBGL_ALWAYS_SOFTWARE=1
gz sim -g
```

Wait for the Gazebo window to appear before continuing.

> **No WSLg?** If you are on Windows 10 or WSL1, install VcXsrv from sourceforge.net/projects/vcxsrv, launch it with default settings, then run `export DISPLAY=:0.0` before starting Gazebo.

---

### Terminal 2 — Drone 1 (System ID 1, position x=0m)

```bash
export DISPLAY=:0
export LIBGL_ALWAYS_SOFTWARE=1
export GZ_SIM_RESOURCE_PATH=~/PX4-Autopilot/Tools/simulation/gz/models:~/PX4-Autopilot/Tools/simulation/gz/worlds
cd ~/PX4-Autopilot
PX4_SYS_AUTOSTART=4001 PX4_GZ_MODEL_POSE="0,0,0,0,0,0" PX4_GZ_MODEL=x500 HEADLESS=0 \
  ./build/px4_sitl_default/bin/px4 -i 0
```

> **`-i 0`** assigns instance number 0 → MAVLink System ID 1.  
> **`PX4_SYS_AUTOSTART=4001`** loads the x500 quadrotor configuration profile (motors, sensors, controllers).  
> **`PX4_GZ_MODEL_POSE="0,0,0,0,0,0"`** sets position: x=0m, y=0m, z=0m, roll=0, pitch=0, yaw=0.  
> **`GZ_SIM_RESOURCE_PATH`** tells Gazebo where to find PX4 drone models and world SDF files.

Wait for `pxh>`, then type:
mavlink start -x -u 14562 -r 4000000 -t 172.27.80.1 -o 14552

---

### Terminal 5 — QGroundControl

```bash
cd ~/qgroundcontrol/build
LIBGL_ALWAYS_SOFTWARE=1 QSG_RENDER_LOOP=basic ./Debug/QGroundControl
```

### Configure QGC Comm Links for Drones 2 and 3

QGC listens on port 14550 by default. To receive telemetry from Drones 2 and 3:

1. Open QGC → **Application Settings** (gear icon) → **Comm Links**
2. Click **Add** → Type: UDP, Port: 14551, Name: Drone2 → **Connect**
3. Click **Add** → Type: UDP, Port: 14552, Name: Drone3 → **Connect**

> Alternatively, enable **AutoConnect** on all three ports so QGC connects automatically on startup.

---

## Verification Checklist

| Check | Expected | Where |
|-------|---------|-------|
| PX4 physics running | `INFO [gz_bridge] world: default, model: x500_0` | Terminal 2/3/4 |
| Sensors initialized | No `Accel/Gyro/Baro missing` warnings | Terminal 2/3/4 |
| Ready to fly | `INFO [commander] Ready for takeoff!` | Terminal 2/3/4 |
| MAVLink routed | `INFO [mavlink] partner IP: X.X.X.X` | Terminal 2/3/4 |
| Gazebo loaded | x500_0, x500_1, x500_2 in Entity Tree | Gazebo window |
| QGC connected | Drones visible on map | QGC window |
| SwarmDashboard visible | "Drones: 3" displayed | QGC overlay |

---

## SwarmDashboard Usage Guide

### Demo Sequence

1. SwarmDashboard shows Drones: 3, all DISARMED
2. Click ARM → all 3 drones arm in Gazebo
3. Set altitude slider (e.g. 10m) → click TAKEOFF 10m
4. All 3 drones lift off simultaneously in Gazebo
5. Change altitude slider to 20m → click CHANGE ALT
6. Drones adjust altitude in flight
7. Click LEADER → selects only the leader drone
8. Send individual commands to leader only
9. Click LAND → grouped landing

### Selection System

| Action | Result |
|--------|--------|
| Click drone card | Toggle selection (blue border = selected) |
| ALL button | Select all drones |
| NONE button | Clear selection |
| LEADER button | Select only the current leader |
| Orange border | Current leader drone |

### Flight Parameters

- **Altitude slider (1–50m)** — sets target AGL for TAKEOFF and CHANGE ALT
- **Speed slider (1–20 m/s)** — sends MAVLink DO_CHANGE_SPEED to selected armed drones
- **CHANGE ALT** — only works when drones are airborne (ALT > 0.5m)

---

## Code Architecture

QGroundControl (custom build)

└── src/FlyView/

├── FlyViewWidgetLayer.qml     ← MODIFIED: adds SwarmDashboard instance

├── SwarmDashboard.qml         ← NEW: all swarm UI and logic

└── CMakeLists.txt             ← MODIFIED: registers SwarmDashboard.qml
SwarmDashboard.qml

├── _vehicles    → QGroundControl.multiVehicleManager.vehicles

├── selectedIds  → array of selected System IDs

├── leaderId     → current leader System ID

├── dispatch()   → sends MAVLink only to selectedIds

├── electLeader()→ scoring algorithm, runs every 2s

└── applyAltitude() → guidedModeChangeAltitude(delta, false)
QGC Vehicle properties used:

├── .id                       System ID (1, 2, 3)

├── .armed                    bool — settable

├── .flightMode               string ("Hold", "Takeoff", etc.)

├── .connectionLost           bool — true if heartbeat lost

├── .coordinate.latitude/longitude

├── .altitudeRelative.value   AGL in meters

├── .altitudeAMSL.value       AMSL in meters

├── .groundSpeed.value        m/s

├── .heading.value            degrees

├── .batteries.get(0).percentRemaining.value

├── .guidedModeTakeoff(altAGL)

├── .guidedModeLand()

└── .guidedModeChangeAltitude(deltaMeters, pauseVehicle)


---

## Leader Election Algorithm

```javascript
// Score each drone based on operational state
function flightScore(v) {
    if (!v || v.connectionLost)             return -1  // excluded
    if (v.armed && v.flightMode !== 'Hold') return 2   // actively flying
    if (v.armed)                            return 1   // armed on ground
    return 0                                           // disarmed
}

// Elect best candidate — runs every 2 seconds
function electLeader() {
    var bestId = -1
    for (var i = 0; i < _vehicles.count; i++) {
        var v = _vehicles.get(i)
        if (v.connectionLost) continue
        if (bestId === -1) { bestId = v.id; continue }
        var vScore    = flightScore(v)
        var bestScore = flightScore(getVehicleById(bestId))
        // Higher score wins. Tie = lowest System ID wins.
        if (vScore > bestScore || (vScore === bestScore && v.id < bestId))
            bestId = v.id
    }
    if (bestId !== leaderId) {
        leaderReason = 'Failover: Drone ' + leaderId + ' lost -> Drone ' + bestId
        leaderId = bestId
    }
}

Timer { interval: 2000; running: true; repeat: true
        onTriggered: swarmDashboard.electLeader() }
```

### Altitude Change — AGL vs AMSL

```javascript
function applyAltitude() {
    for (var i = 0; i < _vehicles.count; i++) {
        var v = _vehicles.get(i)
        if (!isSelected(v.id) || !v.armed) continue
        if (v.altitudeRelative.value < 0.5) continue  // must be airborne
        // delta = target AGL - current AGL (NOT an absolute value)
        var delta = takeoffAlt - v.altitudeRelative.value
        v.guidedModeChangeAltitude(delta, false)  // false = do not pause vehicle
    }
}
// Source: Q_INVOKABLE void guidedModeChangeAltitude(double altitudeChange, bool pauseVehicle)
// Found in: src/Vehicle/Vehicle.h
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Gazebo does not open | Wrong runtime dir permissions | `sudo chmod 700 /run/user/1000` |
| cmake not found | Wrong cmake version | `sudo ln -sf /usr/local/bin/cmake /usr/bin/cmake` |
| ninja fails with SDL3 PCH error | Missing precompiled header | `touch .../SDL3-static.dir/cmake_pch.hxx.gch` |
| `gz_x500 unknown target` | Stale build cache | `rm -rf build && make px4_sitl gz_x500` |
| Arming denied, health failures | Sensors not initialized | Restart the PX4 instance, wait for `Ready for takeoff!` |
| SwarmDashboard not visible | Missing rebuild or no drones | Run `ninja -j4`, verify drones are connected |
| Default QGC view only | Files not integrated correctly | Verify the 2 diff changes above were applied |
| Drones 2 and 3 not detected | QGC not listening on ports 14551/14552 | Add Comm Links for those ports in QGC settings |
| CHANGE ALT does nothing | Drone is on ground | ARM + TAKEOFF first, then use CHANGE ALT |
| WSLg display not found | WSLg not available | Install VcXsrv, run `export DISPLAY=:0.0` |

---

## How to Shutdown Cleanly

Always stop in reverse order to avoid PX4 state corruption:

1. Close QGC window
2. Ctrl+C in Terminal 5 (QGC)
3. Ctrl+C in Terminal 4 (Drone 3) — type 'quit' if pxh> still active
4. Ctrl+C in Terminal 3 (Drone 2)
5. Ctrl+C in Terminal 2 (Drone 1)
6. Close Gazebo window or Ctrl+C in Terminal 1

If a subsequent launch shows stale state errors:
```bash
rm ~/PX4-Autopilot/build/px4_sitl_default/tmp/rootfs/dataman
```

---

## Known Limitations

- **Intel Iris Xe GPU** — two or more simultaneous Gazebo instances may cause IMU instabilities. Restart failing instances. Use a dedicated GPU for stable multi-drone rendering.
- **WSL2 gateway IP** — changes on every restart. Always re-check with `cat /etc/resolv.conf | grep nameserver`.
- **CHANGE ALT** — only works when drones are airborne (ALT > 0.5m AGL).
- **No drone-to-drone communication** — all commands route through QGC (centralized). Phase IV introduces distributed control via uXRCE-DDS.
- **No video feed** — camera visualization per drone is planned for Phase IV.

---

## Phase IV — Next Steps

### 1. Video Camera Feed Per Drone
GStreamer pipeline in Gazebo streams simulated camera output. Display in QGC using the existing `VideoReceiver` component. Each drone will have an activatable camera view.

### 2. Leader-to-Follower via uXRCE-DDS
The `uxrce_dds_client` already runs in the current SITL setup:
INFO [uxrce_dds_client] init UDP agent IP:127.0.0.1, port:8888

Phase IV broadcasts formation setpoints from leader to followers via PX4 uORB topics over DDS.

Phase III (current):  QGC → MAVLink → Drone 1, 2, 3  (centralized)

Phase IV:             QGC → MAVLink → Drone 1 (leader)

Drone 1 → uXRCE-DDS → Drone 2, 3 (distributed)

### 3. Configurable GCS-Lost Behavior
HOLD / RTL toggle in the SwarmDashboard, set before flight.

### 4. Formation Algorithms
Triangle, line, grid formations computed by the leader and broadcast to followers.

---

## References

| Resource | URL |
|----------|-----|
| QGroundControl source | github.com/mavlink/qgroundcontrol |
| PX4 Autopilot | github.com/PX4/PX4-Autopilot |
| Gazebo Harmonic | gazebosim.org/docs/harmonic |
| MAVLink protocol | mavlink.io/en |
| PX4 uXRCE-DDS | docs.px4.io/main/en/middleware/uxrce_dds.html |
| PX4 SITL Gazebo | docs.px4.io/main/en/sim_gazebo_gz |
| Qt QML docs | doc.qt.io/qt-6/qmlapplications.html |
| aqtinstall | github.com/miurahr/aqtinstall |
| VcXsrv (Windows X server) | sourceforge.net/projects/vcxsrv |
ENDREADME
echo "README done"
