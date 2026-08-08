#!/bin/bash
# SwarmDashboard v2 — Automatic installer
# Usage: bash install.sh /path/to/qgroundcontrol
set -e
QGC_PATH="${1:-$HOME/qgroundcontrol}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Installing SwarmDashboard into: $QGC_PATH"

if [ ! -d "$QGC_PATH/src/FlyView" ]; then
    echo "ERROR: $QGC_PATH/src/FlyView not found."
    echo "Make sure you cloned QGroundControl first:"
    echo "  git clone https://github.com/mavlink/qgroundcontrol.git --recursive"
    exit 1
fi

# 1. Copy SwarmDashboard.qml
cp "$SCRIPT_DIR/SwarmDashboard.qml" "$QGC_PATH/src/FlyView/"
echo "Copied SwarmDashboard.qml"

# 2. Copy CMakeLists.txt (adds SwarmDashboard.qml to QML module)
cp "$SCRIPT_DIR/CMakeLists.txt" "$QGC_PATH/src/FlyView/"
echo "Copied CMakeLists.txt"

# 3. Inject SwarmDashboard into existing FlyViewWidgetLayer.qml
WIDGET_LAYER="$QGC_PATH/src/FlyView/FlyViewWidgetLayer.qml"
if grep -q "SwarmDashboard" "$WIDGET_LAYER"; then
    echo "SwarmDashboard already present in FlyViewWidgetLayer.qml — skipping injection"
else
    python3 - << PYEOF
path = '$WIDGET_LAYER'
content = open(path).read()
old = content.rstrip()
last = old.rfind('}')
new = old[:last] + """
    SwarmDashboard {
        id:                 swarmDashboard
        anchors.left:       toolStrip.right
        anchors.leftMargin: _toolsMargin
        anchors.top:        toolStrip.bottom
        anchors.topMargin:  _toolsMargin
        z:                  QGroundControl.zOrderWidgets
        visible:            QGroundControl.multiVehicleManager.vehicles.count > 0
    }
}"""
open(path, 'w').write(new)
print("Injected SwarmDashboard into FlyViewWidgetLayer.qml")
PYEOF
fi

echo ""
echo "Installation complete."
echo ""
echo "Now rebuild QGC:"
echo "  cd $QGC_PATH/build && ninja -j$(nproc)"
echo ""
echo "Then launch QGC:"
echo "  export DISPLAY=:1"
echo "  ./Debug/QGroundControl"
