import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:     swarmDashboard
    color:  "#CC000000"
    radius: 8
    width:  300
    height: Math.min(swarmColumn.implicitHeight + 40, 600)

    property var  _vehicles:      QGroundControl.multiVehicleManager.vehicles
    property var  selectedIds:    []
    property int  leaderId:       -1
    property string leaderReason: ""
    property real takeoffAlt:     10
    property real maxSpeed:       5

    Timer {
        id: speedTimer
        interval: 600; repeat: false
        onTriggered: swarmDashboard.applySpeed()
    }

    function isSelected(id) { return selectedIds.indexOf(id) >= 0 }

    function toggleSelect(id) {
        var arr = selectedIds.slice()
        var idx = arr.indexOf(id)
        if (idx >= 0) arr.splice(idx, 1)
        else arr.push(id)
        selectedIds = arr
    }

    function selectAll() {
        var arr = []
        for (var i = 0; i < _vehicles.count; i++) arr.push(_vehicles.get(i).id)
        selectedIds = arr
    }

    function selectNone()   { selectedIds = [] }
    function selectLeader() { selectedIds = leaderId >= 0 ? [leaderId] : [] }

    function dispatch(action) {
        for (var i = 0; i < _vehicles.count; i++) {
            var v = _vehicles.get(i)
            if (!isSelected(v.id)) continue
            if      (action === "arm")     v.armed = true
            else if (action === "disarm")  v.armed = false
            else if (action === "takeoff") v.guidedModeTakeoff(takeoffAlt)
            else if (action === "land")    v.guidedModeLand()
        }
    }

    function applySpeed() {
        for (var i = 0; i < _vehicles.count; i++) {
            var v = _vehicles.get(i)
            if (!isSelected(v.id) || !v.armed) continue
            v.sendMavCommand(1, 179, true, 1, maxSpeed, -1, 0, 0, 0, 0)
        }
    }

    // Altitude absolue -> calcul du delta par rapport a l'altitude relative actuelle
    function applyAltitude() {
        for (var i = 0; i < _vehicles.count; i++) {
            var v = _vehicles.get(i)
            if (!isSelected(v.id) || !v.armed) continue
            if (v.altitudeRelative.value < 0.5) continue
            var amslAlt = v.altitudeAMSL.value - v.altitudeRelative.value + takeoffAlt
            v.sendMavCommand(
                1, 192, true,
                -1,
                0,
                0,
                -1,
                v.coordinate.latitude,
                v.coordinate.longitude,
                amslAlt
            )
        }
    }

    function fmt(val, dec) {
        try { return Number(val).toFixed(dec) }
        catch(e) { return "--" }
    }

    function getVehicleById(id) {
        for (var i = 0; i < _vehicles.count; i++)
            if (_vehicles.get(i).id === id) return _vehicles.get(i)
        return null
    }

    function flightScore(v) {
        if (!v || v.connectionLost) return -1
        if (v.armed && v.flightMode !== "Hold") return 2
        if (v.armed) return 1
        return 0
    }

    function electLeader() {
        if (!_vehicles || _vehicles.count === 0) { leaderId = -1; return }
        var bestId = -1
        for (var i = 0; i < _vehicles.count; i++) {
            var v = _vehicles.get(i)
            if (v.connectionLost) continue
            if (bestId === -1) { bestId = v.id; continue }
            var vScore    = flightScore(v)
            var bestScore = flightScore(getVehicleById(bestId))
            if (vScore > bestScore || (vScore === bestScore && v.id < bestId))
                bestId = v.id
        }
        if (bestId !== leaderId) {
            if      (leaderId === -1) leaderReason = "Election initiale -> Drone " + bestId
            else if (bestId   === -1) leaderReason = "Aucun drone actif"
            else                      leaderReason = "Failover : Drone " + leaderId + " perdu -> Drone " + bestId
            leaderId = bestId
        }
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: swarmDashboard.electLeader() }

    Connections {
        target: _vehicles
        function onCountChanged() { swarmDashboard.electLeader(); swarmDashboard.selectAll() }
    }

    Component.onCompleted: { electLeader(); selectAll() }

    Flickable {
        id:           flick
        anchors.fill: parent
        anchors.margins: 4
        contentHeight: swarmColumn.implicitHeight + 20
        clip:          true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id:      swarmColumn
            width:   flick.width - 8
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            topPadding: 6

            QGCLabel {
                text: "SWARM DASHBOARD"
                font.bold: true; color: "white"
                font.pointSize: ScreenTools.defaultFontPointSize * 1.2
            }

            QGCLabel { text: "Drones: " + _vehicles.count; color: "#00FF00" }

            Repeater {
                model: _vehicles

                Rectangle {
                    width:  swarmColumn.width
                    height: droneCol.implicitHeight + 12
                    radius: 4
                    color:  isSelected(object.id) ? "#1A3A5A" : "#1A1A2E"
                    border.color: object.id === leaderId ? "#f59e0b" :
                                  isSelected(object.id)  ? "#3b82f6" : "#444"
                    border.width: (object.id === leaderId || isSelected(object.id)) ? 2 : 1

                    property var _drone: object

                    MouseArea {
                        anchors.fill: parent
                        onClicked: swarmDashboard.toggleSelect(object.id)
                        cursorShape: Qt.PointingHandCursor
                    }

                    Column {
                        id:              droneCol
                        anchors.left:    parent.left
                        anchors.right:   parent.right
                        anchors.top:     parent.top
                        anchors.margins: 6
                        spacing:         6

                        RowLayout {
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: 14; height: 14; radius: 3
                                color:        isSelected(_drone.id) ? "#3b82f6" : "transparent"
                                border.color: isSelected(_drone.id) ? "#3b82f6" : "#888"
                                border.width: 1.5
                                QGCLabel {
                                    anchors.centerIn: parent
                                    text: "v"; color: "white"
                                    font.pointSize: ScreenTools.defaultFontPointSize * 0.7
                                    visible: isSelected(_drone.id)
                                }
                            }

                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: _drone && _drone.connectionLost ? "#666" :
                                       _drone && _drone.armed ? "#00FF00" : "#FF4444"
                            }

                            QGCLabel {
                                text: _drone ? "Drone " + _drone.id : ""
                                color: "white"; Layout.fillWidth: true
                            }

                            QGCLabel {
                                text: _drone ? _drone.flightMode : ""
                                color: "#AAAAAA"
                                font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                            }

                            QGCLabel {
                                text:  _drone && _drone.armed ? "ARMED" : "DISARMED"
                                color: _drone && _drone.armed ? "#00FF00" : "#FF4444"
                                font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                            }

                            Rectangle {
                                visible: _drone && _drone.id === leaderId
                                width: 46; height: 16; radius: 8; color: "#78350f"
                                QGCLabel {
                                    anchors.centerIn: parent
                                    text: "LEADER"; color: "#fbbf24"
                                    font.pointSize: ScreenTools.defaultFontPointSize * 0.7
                                    font.bold: true
                                }
                            }
                        }

                        Grid {
                            columns: 3; width: parent.width; spacing: 4

                            Repeater {
                                model: [
                                    { label: "LAT",   val: fmt(_drone.coordinate.latitude,  6) },
                                    { label: "LON",   val: fmt(_drone.coordinate.longitude, 6) },
                                    { label: "ALT m", val: fmt(_drone.altitudeRelative.value, 1) },
                                    { label: "SPD",   val: fmt(_drone.groundSpeed.value,    1) },
                                    { label: "CAP",   val: fmt(_drone.heading.value,        0) },
                                    { label: "BAT %", val: (function() {
                                        try { return _drone.batteries.count > 0 ?
                                            fmt(_drone.batteries.get(0).percentRemaining.value, 0) : "--"
                                        } catch(e) { return "--" } })() }
                                ]

                                Rectangle {
                                    width: (droneCol.width - 8) / 3
                                    height: 34; radius: 4; color: "#0D0D1A"
                                    Column {
                                        anchors.centerIn: parent; spacing: 2
                                        QGCLabel {
                                            text: modelData.label; color: "#666"
                                            font.pointSize: ScreenTools.defaultFontPointSize * 0.7
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        QGCLabel {
                                            text: modelData.val
                                            color: {
                                                if (modelData.label !== "BAT %") return "#DDDDDD"
                                                var b = parseInt(modelData.val)
                                                if (isNaN(b)) return "#DDDDDD"
                                                return b > 50 ? "#00FF00" : b > 20 ? "#FFA500" : "#FF4444"
                                            }
                                            font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                                            font.bold: true
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: swarmColumn.width; height: 1; color: "#444" }

            Rectangle {
                width: swarmColumn.width
                height: leaderCol.implicitHeight + 10
                color: "#0D1A0D"; radius: 4
                border.color: "#f59e0b"; border.width: 1
                visible: _vehicles.count > 0

                Column {
                    id: leaderCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                    spacing: 3

                    QGCLabel {
                        text: "LEADER ELECTION"; color: "#f59e0b"; font.bold: true
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                    }
                    QGCLabel {
                        text: leaderId >= 0 ? "Leader : Drone " + leaderId : "Aucun leader"
                        color: "#fbbf24"
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                    }
                    QGCLabel {
                        text: "Critere : en vol > arme > desarme — failover auto"
                        color: "#555"; font.pointSize: ScreenTools.defaultFontPointSize * 0.75
                    }
                    QGCLabel {
                        visible: leaderReason !== ""
                        text: leaderReason; color: "#888"
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.75
                        wrapMode: Text.WordWrap; width: parent.width
                    }
                }
            }

            Rectangle { width: swarmColumn.width; height: 1; color: "#444" }

            Rectangle {
                width: swarmColumn.width
                height: paramsCol.implicitHeight + 10
                color: "#0D0D1A"; radius: 4
                border.color: "#334"; border.width: 1

                Column {
                    id: paramsCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                    spacing: 6

                    QGCLabel {
                        text: "PARAMETRES DE VOL"; color: "#AAAAAA"; font.bold: true
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                    }

                    RowLayout {
                        width: parent.width
                        QGCLabel {
                            text: "Altitude cible"; color: "#888"
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                            Layout.fillWidth: true
                        }
                        QGCLabel {
                            text: takeoffAlt.toFixed(0) + " m"; color: "#00FF00"; font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                        }
                    }

                    Slider {
                        width: parent.width; from: 1; to: 50; stepSize: 1; value: takeoffAlt
                        onValueChanged: takeoffAlt = value
                    }

                    RowLayout {
                        width: parent.width
                        QGCButton {
                            text: "DECOLLAGE " + takeoffAlt.toFixed(0) + "m"
                            Layout.fillWidth: true
                            enabled: selectedIds.length > 0
                            opacity: selectedIds.length > 0 ? 1.0 : 0.4
                            onClicked: swarmDashboard.dispatch("takeoff")
                        }
                        QGCButton {
                            text: "CHANGER ALT"
                            Layout.fillWidth: true
                            enabled: selectedIds.length > 0
                            opacity: selectedIds.length > 0 ? 1.0 : 0.4
                            onClicked: swarmDashboard.applyAltitude()
                        }
                    }

                    RowLayout {
                        width: parent.width
                        QGCLabel {
                            text: "Vitesse max"; color: "#888"
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                            Layout.fillWidth: true
                        }
                        QGCLabel {
                            text: maxSpeed.toFixed(0) + " m/s"; color: "#00FF00"; font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                        }
                    }

                    Slider {
                        width: parent.width; from: 1; to: 20; stepSize: 1; value: maxSpeed
                        onValueChanged: { maxSpeed = value; speedTimer.restart() }
                    }
                }
            }

            Rectangle { width: swarmColumn.width; height: 1; color: "#444" }

            RowLayout {
                width: swarmColumn.width; spacing: 4
                QGCButton { text: "TOUS"; Layout.fillWidth: true; onClicked: swarmDashboard.selectAll() }
                QGCButton { text: "AUCUN"; Layout.fillWidth: true; onClicked: swarmDashboard.selectNone() }
                QGCButton { text: "LEADER"; Layout.fillWidth: true; onClicked: swarmDashboard.selectLeader() }
            }

            QGCLabel {
                text: {
                    if (selectedIds.length === 0) return "COMMANDES — aucun drone"
                    if (selectedIds.length === _vehicles.count) return "COMMANDES — tous"
                    return "COMMANDES — Drone(s) " + selectedIds.join(", ")
                }
                color: "#AAAAAA"; font.pointSize: ScreenTools.defaultFontPointSize * 0.9
            }

            RowLayout {
                width: swarmColumn.width; spacing: 4
                opacity: selectedIds.length > 0 ? 1.0 : 0.4

                QGCButton {
                    text: "ARM"; Layout.fillWidth: true
                    enabled: selectedIds.length > 0
                    onClicked: swarmDashboard.dispatch("arm")
                }
                QGCButton {
                    text: "DISARM"; Layout.fillWidth: true
                    enabled: selectedIds.length > 0
                    onClicked: swarmDashboard.dispatch("disarm")
                }
            }

            QGCButton {
                text: "LAND"; width: swarmColumn.width
                opacity: selectedIds.length > 0 ? 1.0 : 0.4
                enabled: selectedIds.length > 0
                onClicked: swarmDashboard.dispatch("land")
            }

            Item { height: 6 }
        }
    }
}
