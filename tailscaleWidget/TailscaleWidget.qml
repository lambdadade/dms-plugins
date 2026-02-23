import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // ── State ─────────────────────────────────────────────────────────────────
    property string backendState: "NoState"
    property string selfHostName: ""
    property string selfIp: ""
    property var peers: []
    property bool toggling: false

    readonly property bool connected: backendState === "Running"

    function stateColor() {
        if (backendState === "Running")   return Theme.primary
        if (backendState === "Stopped")   return Theme.error
        if (backendState === "NoState")   return Theme.surfaceVariantText
        return Theme.surfaceVariantText
    }

    // ── Data fetching ─────────────────────────────────────────────────────────
    popoutWidth: 300
    popoutHeight: 500

    function refresh() {
        if (!statusProcess.running)
            statusProcess.running = true
    }

    function toggle() {
        if (toggling) return
        toggling = true
        Quickshell.execDetached(connected ? ["tailscale", "down"] : ["tailscale", "up"])
        toggleRefreshTimer.restart()
    }

    Process {
        id: statusProcess
        command: ["tailscale", "status", "--json"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    root.backendState = d.BackendState || "NoState"
                    var self = d.Self || {}
                    root.selfHostName = self.HostName || ""
                    var ips = self.TailscaleIPs || []
                    root.selfIp = ips.length > 0 ? ips[0] : ""

                    var peerObj = d.Peer || {}
                    var arr = []
                    for (var key in peerObj) {
                        var p = peerObj[key]
                        var pIps = p.TailscaleIPs || []
                        arr.push({
                            name: p.HostName || "unknown",
                            ip:   pIps.length > 0 ? pIps[0] : "",
                            online: p.Online === true
                        })
                    }
                    arr.sort(function(a, b) {
                        if (a.online !== b.online) return (b.online ? 1 : 0) - (a.online ? 1 : 0)
                        return a.name.localeCompare(b.name)
                    })
                    root.peers = arr
                    root.toggling = false
                } catch (e) {
                    console.error("[tailscaleWidget] JSON parse error:", e)
                }
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: toggleRefreshTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: root.refresh()
    }

    // ── Bar pills ─────────────────────────────────────────────────────────────

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "vpn_lock"
                size: Theme.iconSize
                color: root.stateColor()
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.selfIp
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.connected && root.selfIp !== ""
            }
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "vpn_lock"
            size: Theme.iconSize
            color: root.stateColor()
        }
    }

    // ── Popout ────────────────────────────────────────────────────────────────

    popoutContent: Component {
        PopoutComponent {
            headerText: "Tailscale"
            detailsText: root.backendState
            showCloseButton: true

            Column {
                width: parent.width - Theme.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingM

                // ── Self card ─────────────────────────────────────────────────
                StyledRect {
                    width: parent.width
                    height: 60
                    color: Theme.surfaceContainerHigh

                    DankIcon {
                        id: selfIcon
                        name: "computer"
                        size: 28
                        color: root.stateColor()
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.left: selfIcon.right
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: toggleBtn.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            text: root.selfHostName || "—"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        StyledText {
                            text: root.selfIp || "disconnected"
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.stateColor()
                        }
                    }

                    DankButton {
                        id: toggleBtn
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.toggling ? "…" : (root.connected ? "Down" : "Up")
                        enabled: !root.toggling
                        onClicked: root.toggle()
                    }
                }

                // ── Peers ─────────────────────────────────────────────────────
                StyledText {
                    text: "Peers (" + root.peers.length + ")"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceVariantText
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    Repeater {
                        model: root.peers

                        StyledRect {
                            width: parent.width
                            height: 44
                            color: Theme.surfaceContainerHigh

                            Rectangle {
                                id: statusDot
                                width: 8
                                height: 8
                                radius: 4
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                color: modelData.online ? Theme.primary : Theme.surfaceVariant
                            }

                            Column {
                                anchors.left: statusDot.right
                                anchors.leftMargin: Theme.spacingS
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                StyledText {
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: modelData.online ? Theme.surfaceText : Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                StyledText {
                                    text: modelData.ip
                                    font.pixelSize: Theme.fontSizeXSmall
                                    color: Theme.surfaceVariantText
                                    visible: modelData.ip !== ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
