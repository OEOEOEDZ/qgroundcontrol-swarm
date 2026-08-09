# QGroundControl — SwarmDashboard v2

**Multi-UAV Swarm Management Extension for QGroundControl**

> Internship Research Project — University of Science and Technology of Hanoi (USTH) 2026  
> Student: Yacine Abdi — ITS2 Cybersecurity & AI, EPISEN / UPEC  
> Supervisor: Prof. Pham Xuan Tung  
> Repository: github.com/OEOEOEDZ/qgroundcontrol-swarm

---

## Table of Contents

1. [What This Project Does](#1-what-this-project-does)
2. [Repository Contents](#2-repository-contents)
3. [System Requirements](#3-system-requirements)
4. [Step-by-Step Installation](#4-step-by-step-installation)
   - [Step 0 — Fix System Dependencies](#step-0--fix-system-dependencies)
   - [Step 1 — Install Qt](#step-1--install-qt)
   - [Step 2 — Clone and Build QGroundControl](#step-2--clone-and-build-qgroundcontrol)
   - [Step 3 — Install SwarmDashboard](#step-3--install-swarmdashboard)
   - [Step 4 — Install PX4 Autopilot](#step-4--install-px4-autopilot)
5. [Option A — Gazebo Classic (1 drone + live video)](#5-option-a--gazebo-classic-1-drone--live-video)
6. [Option B — Gazebo Harmonic (3 drones simultaneously)](#6-option-b--gazebo-harmonic-3-drones-simultaneously)
7. [SwarmDashboard Usage Guide](#7-swarmdashboard-usage-guide)
8. [Leader Election Algorithm](#8-leader-election-algorithm)
9. [Troubleshooting](#9-troubleshooting)
10. [Clean Shutdown](#10-clean-shutdown)

---

## 1. What This Project Does

This project adds a **SwarmDashboard** panel directly inside QGroundControl (QGC). It lets you supervise and control multiple drones at the same time from a single screen.

**Features:**
- See all your drones at once with their live telemetry (position, altitude, speed, battery)
- Click on a drone card to select it — send commands to one, two, or all drones
- Automatic leader election every 2 seconds — the best drone becomes the leader
- CAM button on each drone card to switch the live video feed
- Takeoff, land, change altitude, change speed — all from the same panel
- 100% written in QML — no C++ code was modified in QGroundControl

**What you will see at the end:**

With Gazebo Classic: 1 drone flying with a live H.264 camera feed displayed inside QGC.

With Gazebo Harmonic: 3 drones flying simultaneously, all supervised from the SwarmDashboard.

---

## 2. Repository Contents

| File | What it does |
|------|-------------|
| `SwarmDashboard.qml` | The main dashboard panel — all UI and logic |
| `CMakeLists.txt` | Tells QGC build system to include SwarmDashboard.qml |
| `install.sh` | Automatic installer — run this instead of copying files manually |
| `swarm_camera_stream.py` | Python synthetic camera streamer (backup if Gazebo camera does not work) |
| `README.md` | This file |

---

## 3. System Requirements

Before starting, make sure your machine meets these requirements:

| Component | Minimum Version | Where to check |
|-----------|----------------|----------------|
| Operating System | Ubuntu 22.04 LTS | `lsb_release -a` |
| RAM | 16 GB recommended | `free -h` |
| CPU | 8+ cores recommended | `nproc` |
| Disk space | 30 GB free | `df -h` |
| Internet | Required for downloads | — |

> **WSL2 users (Windows):** Everything works on WSL2 with Windows 11. Add `export DISPLAY=:0` and `export LIBGL_ALWAYS_SOFTWARE=1` before every command that opens a window. Also run `sudo chmod 700 /run/user/1000` after each reboot.

> **Native Ubuntu users:** Use `export DISPLAY=:1` (check yours with the `who` command).

---

## 4. Step-by-Step Installation

### Step 0 — Fix System Dependencies

Open a terminal and run these commands one by one. Copy and paste each block exactly.

**Update your system first:**
```bash
sudo apt update && sudo apt upgrade -y
```

**Install required libraries:**
```bash
sudo apt install -y git ninja-build build-essential python3-pip \
    libsecret-1-dev libxkbcommon-dev libgl1-mesa-dev libglu1-mesa-dev \
    libxcb-cursor0 x11-apps
```

**Install a recent version of cmake** (the system version is too old):
```bash
pip3 install cmake --upgrade
export PATH=~/.local/bin:$PATH
cmake --version
```
You should see `cmake version 3.28` or higher. If you still see an old version, run:
```bash
sudo ln -sf $(python3 -c "import cmake; print(cmake.CMAKE_BIN_DIR)")/cmake /usr/local/bin/cmake
cmake --version
```

**Fix the jsoncpp cmake compatibility issue** (required for PX4 to compile):
```bash
sudo bash -c 'cat > /usr/lib/x86_64-linux-gnu/cmake/jsoncpp/jsoncppConfig.cmake << JSEOF
cmake_minimum_required(VERSION 3.10...3.28)
find_package(PkgConfig REQUIRED)
pkg_check_modules(JSONCPP jsoncpp)
if(NOT TARGET jsoncpp_lib)
  add_library(jsoncpp_lib INTERFACE IMPORTED)
  set_target_properties(jsoncpp_lib PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${JSONCPP_INCLUDE_DIRS}"
    INTERFACE_LINK_LIBRARIES "${JSONCPP_LIBRARIES}")
endif()
if(NOT TARGET jsoncpp_static)
  add_library(jsoncpp_static INTERFACE IMPORTED)
  set_target_properties(jsoncpp_static PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${JSONCPP_INCLUDE_DIRS}"
    INTERFACE_LINK_LIBRARIES "${JSONCPP_LIBRARIES}")
endif()
JSEOF'
echo "jsoncpp fixed"
```

---

### Step 1 — Install Qt

QGroundControl requires Qt 6.11.1 or higher. Do NOT use the Qt version from apt — it is too old. Use aqtinstall instead.

**Install aqtinstall:**
```bash
pip3 install aqtinstall
```

**Install Qt 6.11.1** (this will take 10-20 minutes and download about 3 GB):
```bash
aqt install-qt linux desktop 6.11.1 linux_gcc_64 \
  -m qt5compat qtcharts qtimageformats qtlocation qtpositioning \
  qtsensors qtserialport qtmultimedia qtshadertools qtwebsockets \
  qtwebchannel qtwebengine qtspeech qtscxml qtremoteobjects \
  qtnetworkauth qtserialbus qtconnectivity qtvirtualkeyboard \
  qtdatavis3d qtgraphs qtquick3d qtquick3dphysics qthttpserver \
  qtlottie -O ~/Qt
```

If the download fails halfway through, just run the same command again — it will continue from where it stopped.

**Verify Qt was installed correctly:**
```bash
~/Qt/6.11.1/gcc_64/bin/qmake --version
```
You should see: `Using Qt version 6.11.1`

---

### Step 2 — Clone and Build QGroundControl

**IMPORTANT:** Always use `--recursive` when cloning. Without it, the build will fail.

```bash
cd ~
git clone https://github.com/mavlink/qgroundcontrol.git --recursive
```

This downloads about 500 MB and will take a few minutes.

**Configure the build:**
```bash
cd ~/qgroundcontrol
mkdir build && cd build
cmake .. -GNinja \
         -DCMAKE_BUILD_TYPE=Debug \
         -DCMAKE_PREFIX_PATH=~/Qt/6.11.1/gcc_64
```

You should see `-- Configuring done` and `-- Build files have been written` at the end. If you see errors, check the Troubleshooting section below.

**Compile QGroundControl** (this takes 15-40 minutes depending on your CPU):
```bash
ninja -j$(nproc)
```

When it finishes you will see:
```
[2135/2135] Linking CXX executable Debug/QGroundControl
```

If you see a GPSProvider error during compilation, apply this fix and run ninja again:
```bash
cd ~/qgroundcontrol
python3 - << 'PY'
path = 'src/GPS/GPSProvider.cc'
content = open(path).read()
old = "        gpsDriver = new GPSDriverUBX(GPSDriverUBX::Interface::UART, &_callbackEntry, this, &_sensorGps, &_satelliteInfo);"
new = "        {\n            GPSDriverUBX::Settings settings{};\n            gpsDriver = new GPSDriverUBX(GPSDriverUBX::Interface::UART, &_callbackEntry, this, &_sensorGps, &_satelliteInfo, std::move(settings));\n        }"
open(path, 'w').write(content.replace(old, new))
print("Fixed GPSProvider.cc")
PY
cd build
ninja -j$(nproc)
```

**Test that QGC opens** (no drones yet, just checking it launches):
```bash
export DISPLAY=:1
cd ~/qgroundcontrol/build
./Debug/QGroundControl
```
You should see the QGroundControl map. Close it for now.

---

### Step 3 — Install SwarmDashboard

Clone the SwarmDashboard repository. Replace YOUR_TOKEN with a GitHub personal access token (generate one at github.com → Settings → Developer settings → Personal access tokens → Tokens classic → scope: repo):

```bash
cd ~
git clone -b master https://YOUR_TOKEN@github.com/OEOEOEDZ/qgroundcontrol-swarm.git
```

Run the installer:
```bash
bash ~/qgroundcontrol-swarm/install.sh ~/qgroundcontrol
```

You should see:
```
Copied SwarmDashboard.qml
Copied CMakeLists.txt
Injected SwarmDashboard into FlyViewWidgetLayer.qml
Installation complete.
```

Rebuild QGC to include SwarmDashboard:
```bash
cd ~/qgroundcontrol/build
rm -rf *
cmake .. -GNinja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=~/Qt/6.11.1/gcc_64
ninja -j$(nproc)
```

---

### Step 4 — Install PX4 Autopilot

**Clone PX4:**
```bash
cd ~
git clone https://github.com/PX4/PX4-Autopilot.git --recursive
cd PX4-Autopilot
bash ./Tools/setup/ubuntu.sh
```

When the setup script finishes, **close your terminal and open a new one**. This is important — the script sets environment variables that only work in a new terminal.

**Compile PX4 with Gazebo Harmonic** (first build, verifies everything works):
```bash
cd ~/PX4-Autopilot
make px4_sitl gz_x500 -j$(nproc)
```

When `pxh>` appears, type `quit` to exit. PX4 is now compiled and ready.

---

## 5. Option A — Gazebo Classic (1 drone + live video)

This option gives you **1 drone with a real H.264 camera feed** displayed live inside QGroundControl.

### Why Gazebo Classic for video?

Gazebo Classic uses the OGRE 1 rendering engine which works with software OpenGL (no GPU required). It includes a GStreamer plugin that streams the camera feed directly as H.264 UDP to QGroundControl.

### Install Gazebo Classic

```bash
sudo apt install -y gazebo libgazebo-dev
gazebo --version
```
You should see: `Gazebo multi-robot simulator, version 11.10.2`

### Fix cmake compatibility for Gazebo Classic build

```bash
find ~/PX4-Autopilot/Tools/simulation/gazebo-classic -name "CMakeLists.txt" \
  -exec sed -i 's/cmake_minimum_required( VERSION 2\.[0-9.]*/cmake_minimum_required( VERSION 3.5/g' {} \;
find ~/PX4-Autopilot/Tools/simulation/gazebo-classic -name "CMakeLists.txt" \
  -exec sed -i 's/cmake_minimum_required(VERSION 2\.[0-9.]*/cmake_minimum_required(VERSION 3.5/g' {} \;
echo "cmake fixes applied"
```

### Launch — Open 3 terminals in order

**IMPORTANT:** Disconnect any VPN before starting. VPN blocks the UDP video stream.

**Terminal 1 — PX4 + Gazebo Classic** (this opens Gazebo automatically):
```bash
export DISPLAY=:1
export LIBGL_ALWAYS_SOFTWARE=1  # only needed on WSL2 or machines without GPU
export GAZEBO_PLUGIN_PATH=~/PX4-Autopilot/build/px4_sitl_default/build_gazebo-classic
cd ~/PX4-Autopilot
make px4_sitl gazebo-classic_typhoon_h480
```

Wait until Gazebo opens with the Typhoon H480 drone visible.

**Inside Gazebo:** Click the green **VIDEO: ON** button in the top-left corner. This activates the GStreamer H.264 stream on UDP port 5600. The blue triangle (camera field of view) will appear on the drone.

When `pxh>` appears in the terminal:
```bash
mavlink start -x -u 14560 -r 4000000 -t 127.0.0.1 -o 14550
```
> On WSL2: replace `127.0.0.1` with your gateway IP: `cat /etc/resolv.conf | grep nameserver | awk '{print $2}'`

**Terminal 2 — QGroundControl** (launch AFTER clicking Video ON in Gazebo):
```bash
export DISPLAY=:1
cd ~/qgroundcontrol/build
./Debug/QGroundControl
```

**Configure video in QGC:**
1. Click the QGC icon (top left) → Application Settings
2. Go to **Video** section
3. Set Source to: **UDP h.264 Video Stream**
4. Set UDP URL to: `0.0.0.0:5600`
5. Close settings and return to Fly View

The camera feed from Gazebo will appear as the background of the QGC Fly View.

**Terminal 3 — Add MAVLink Comm Links for more drones (optional):**

If you want QGC to accept connections from drones 2 and 3:
1. In QGC: Application Settings → Comm Links → Add
2. Name: Drone2, Type: UDP, Port: 14551
3. Add another: Name: Drone3, Type: UDP, Port: 14552

---

## 6. Option B — Gazebo Harmonic (3 drones simultaneously)

This option gives you **3 drones flying simultaneously** in Gazebo Harmonic, all supervised from the SwarmDashboard. Video streaming from Gazebo Harmonic is currently under development.

### Install Gazebo Harmonic

```bash
sudo curl https://packages.osrfoundation.org/gazebo.gpg \
  --output /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] \
http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null

sudo apt update && sudo apt install -y gz-harmonic
gz sim --versions
```
You should see version 8.x.x.

**Recompile PX4 with Gazebo Harmonic support:**
```bash
cd ~/PX4-Autopilot
rm -rf build
make px4_sitl gz_x500 -j$(nproc)
```
When `pxh>` appears, type `quit`.

### Find your display number

```bash
who
```
Look for a line like `tungpx2 :1` — your display is `:1`. Use that number in the commands below.

### Launch — Open 5 terminals in order

Wait for each terminal to be fully ready before opening the next one.

---

**Terminal 1 — Gazebo Harmonic GUI:**
```bash
export DISPLAY=:1
gz sim -g
```
Wait for the Gazebo Sim window to open. It will show a black/grey world at first — that is normal.

---

**Terminal 2 — Drone 1 (position x=0m):**
```bash
export DISPLAY=:1
export GZ_SIM_RESOURCE_PATH=~/PX4-Autopilot/Tools/simulation/gz/models:~/PX4-Autopilot/Tools/simulation/gz/worlds
cd ~/PX4-Autopilot
PX4_SYS_AUTOSTART=4001 \
PX4_GZ_MODEL_POSE="0,0,0,0,0,0" \
PX4_GZ_MODEL=x500_mono_cam \
HEADLESS=0 \
./build/px4_sitl_default/bin/px4 -i 0
```

Wait until you see `pxh>` and `INFO [commander] Ready for takeoff!`

Then type this command in the same terminal:
```bash
mavlink start -x -u 14560 -r 4000000 -t 127.0.0.1 -o 14550
```
> On WSL2: replace 127.0.0.1 with your gateway IP

---

**Terminal 3 — Drone 2 (position x=2m):**
```bash
export DISPLAY=:1
export GZ_SIM_RESOURCE_PATH=~/PX4-Autopilot/Tools/simulation/gz/models:~/PX4-Autopilot/Tools/simulation/gz/worlds
cd ~/PX4-Autopilot
PX4_SYS_AUTOSTART=4001 \
PX4_GZ_MODEL_POSE="2,0,0,0,0,0" \
PX4_GZ_MODEL=x500_mono_cam \
HEADLESS=0 \
./build/px4_sitl_default/bin/px4 -i 1
```

When `pxh>` appears:
```bash
mavlink start -x -u 14561 -r 4000000 -t 127.0.0.1 -o 14551
```

---

**Terminal 4 — Drone 3 (position x=4m):**
```bash
export DISPLAY=:1
export GZ_SIM_RESOURCE_PATH=~/PX4-Autopilot/Tools/simulation/gz/models:~/PX4-Autopilot/Tools/simulation/gz/worlds
cd ~/PX4-Autopilot
PX4_SYS_AUTOSTART=4001 \
PX4_GZ_MODEL_POSE="4,0,0,0,0,0" \
PX4_GZ_MODEL=x500_mono_cam \
HEADLESS=0 \
./build/px4_sitl_default/bin/px4 -i 2
```

When `pxh>` appears:
```bash
mavlink start -x -u 14562 -r 4000000 -t 127.0.0.1 -o 14552
```

---

**Terminal 5 — QGroundControl:**
```bash
export DISPLAY=:1
cd ~/qgroundcontrol/build
./Debug/QGroundControl
```

**Expected result:** The SwarmDashboard appears on the left side of the QGC window showing **Drones: 3** with all three drones listed.

**Add Comm Links for drones 2 and 3 in QGC:**
1. Application Settings → Comm Links → Add
2. Name: Drone2, Type: UDP, Port: 14551 → OK → Connect
3. Add another: Name: Drone3, Type: UDP, Port: 14552 → OK → Connect

---

### Demo Sequence (Gazebo Harmonic)

Once all 3 drones show as DISARMED in the SwarmDashboard:

1. Click **ALL** to select all drones
2. Click **ARM** — all 3 drones arm simultaneously
3. Set altitude slider to **10m**
4. Click **TAKEOFF 10m** — all 3 drones take off together
5. Set altitude slider to **20m**
6. Click **CHANGE ALT** — all 3 drones climb to 20m
7. Click **LEADER** — select only the elected leader
8. Click **LAND** — leader lands

---

## 7. SwarmDashboard Usage Guide

### Drone Cards

Each drone has its own card showing:

| Field | Description |
|-------|-------------|
| LAT | Latitude in decimal degrees |
| LON | Longitude in decimal degrees |
| ALT (m) | Altitude Above Ground Level |
| SPD | Ground speed in m/s |
| HDG | Heading in degrees (0-360) |
| BAT (%) | Battery — green >50%, orange 20-50%, red <20% |

### Card Colors

- **Orange border** = this drone is the current LEADER
- **Blue border** = this drone is selected
- **No border** = not selected

### Selection Buttons

- **ALL** = select all connected drones
- **NONE** = deselect everything
- **LEADER** = select only the current leader drone

### Commands

All commands apply only to selected drones.

| Button | What it does | Requirement |
|--------|-------------|-------------|
| ARM | Arms the motors | Drone must be DISARMED |
| DISARM | Disarms the motors | Drone must be on ground |
| TAKEOFF Xm | Takes off to X meters AGL | Drone must be ARMED |
| CHANGE ALT | Changes altitude to slider value | Drone must be AIRBORNE |
| LAND | Lands the drone | Drone must be AIRBORNE |
| CAM | Switches QGC video to this drone | Video stream must be active |

### Flight Parameters

- **Altitude slider (1-50m):** Sets the target altitude for TAKEOFF and CHANGE ALT
- **Speed slider (1-20 m/s):** Sends DO_CHANGE_SPEED to armed drones

### Important Notes

- CHANGE ALT only works when the drone is airborne (ALT > 0.5m)
- CHANGE ALT uses delta altitude (target - current), not absolute altitude
- All commands are sent via MAVLink — the drone must be connected

---

## 8. Leader Election Algorithm

The algorithm runs automatically every 2 seconds. You do not need to do anything — it works by itself.

### How it works

Each drone gets a score based on its current state:

| Drone state | Score | Priority |
|-------------|-------|----------|
| Armed + actively flying | 2 | Best candidate |
| Armed on ground | 1 | Standby |
| Disarmed | 0 | Idle |
| Connection lost | -1 (excluded) | Cannot be leader |

The drone with the highest score becomes the leader. If two drones have the same score, the one with the **lowest System ID** wins.

### Failover

If the leader loses its connection (heartbeat timeout), the election runs immediately and the next best drone becomes the new leader. The SwarmDashboard shows the failover event in the LEADER ELECTION panel.

### QML Code

```javascript
function flightScore(v) {
    if (!v || v.connectionLost)             return -1  // excluded
    if (v.armed && v.flightMode !== 'Hold') return 2   // actively flying
    if (v.armed)                            return 1   // armed on ground
    return 0                                           // disarmed
}

Timer {
    interval: 2000
    running: true; repeat: true
    onTriggered: electLeader()
}
```

---

## 9. Troubleshooting

### QGroundControl does not open

```
qt.qpa.xcb: could not connect to display
```
Fix:
```bash
export DISPLAY=:1     # or :0 on WSL2
sudo apt install -y libxcb-cursor0
```

### cmake version too old

```
CMake 3.25 or higher is required
```
Fix:
```bash
pip3 install cmake --upgrade
export PATH=~/.local/bin:$PATH
cmake --version  # must show 3.25+
```

### Qt LocationPrivate not found

```
Failed to find required Qt component "LocationPrivate"
```
Fix — this means your QGC clone is too recent and has a known bug. Use qt-cmake instead:
```bash
cd ~/qgroundcontrol/build
rm -rf *
~/Qt/6.11.1/gcc_64/bin/qt-cmake .. -GNinja -DCMAKE_BUILD_TYPE=Debug
ninja -j$(nproc)
```

### gz_bridge not found

```
gz_bridge: not found
ERROR [init] gz_bridge failed to start
```
Fix — PX4 was compiled before Gazebo Harmonic was installed:
```bash
cd ~/PX4-Autopilot
rm -rf build
make px4_sitl gz_x500 -j$(nproc)
```

### SwarmDashboard not visible

The SwarmDashboard only appears when at least one drone is connected. If drones are connected but you still do not see it:
```bash
cd ~/qgroundcontrol/build
rm -rf *
cmake .. -GNinja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=~/Qt/6.11.1/gcc_64
ninja -j$(nproc)
```

### Video shows WAITING FOR VIDEO

The most common causes:
1. You launched QGC before clicking Video ON in Gazebo Classic → Close QGC, click Video ON first, then reopen QGC
2. VPN is active → Disconnect VPN completely
3. Wrong UDP URL → Set it to `0.0.0.0:5600` in QGC Settings → Video

### Drone 2 or 3 not detected in QGC

Add Comm Links manually:
1. QGC → Application Settings → Comm Links → Add
2. Type: UDP, Port: 14551 for Drone 2, 14552 for Drone 3
3. Click Connect after adding each one

### Black screen in Gazebo

```bash
export DISPLAY=:1
pkill -f "gz sim"
sleep 1
gz sim -g
```

### Stale PX4 state after crash

```bash
rm ~/PX4-Autopilot/build/px4_sitl_default/tmp/rootfs/dataman
rm -rf ~/PX4-Autopilot/build/px4_sitl_default/rootfs/
```

---

## 10. Clean Shutdown

Always shut down in this order to avoid state corruption:

```
1. Close QGroundControl window
2. In each PX4 terminal: press Ctrl+C, then type quit if pxh> is still active
3. Close the Gazebo window (or Ctrl+C in Gazebo terminal)
```

After a clean shutdown you can relaunch immediately.

After a crash or unexpected shutdown, run this before relaunching:
```bash
pkill -f "px4" 2>/dev/null
pkill -f "gz sim" 2>/dev/null
pkill -f "gzserver" 2>/dev/null
sleep 2
rm -f ~/PX4-Autopilot/build/px4_sitl_default/tmp/rootfs/dataman
echo "Ready to relaunch"
```

---

## Architecture Overview

```
Option A — Gazebo Classic (video stream)
    PX4 SITL → Gazebo Classic 11 → GStreamer plugin → H.264 UDP :5600 → QGC VideoReceiver
    MAVLink: UDP :14550 ← QGroundControl

Option B — Gazebo Harmonic (3 drones)
    PX4 SITL x3 → Gazebo Harmonic 8 → gz_bridge → uXRCE-DDS
    MAVLink: UDP :14550/:14551/:14552 ← QGroundControl + SwarmDashboard
```

---

## References

| Resource | Link |
|----------|------|
| QGroundControl | github.com/mavlink/qgroundcontrol |
| PX4 Autopilot | github.com/PX4/PX4-Autopilot |
| PX4 Gazebo Classic docs | docs.px4.io/main/en/sim_gazebo_classic |
| PX4 Gazebo Harmonic docs | docs.px4.io/main/en/sim_gazebo_gz |
| Gazebo Harmonic | gazebosim.org/docs/harmonic |
| MAVLink protocol | mavlink.io/en |
| Qt QML docs | doc.qt.io/qt-6 |
| aqtinstall | github.com/miurahr/aqtinstall |

---

*Supervisor: Prof. Pham Xuan Tung — University of Science and Technology of Hanoi 2026*
