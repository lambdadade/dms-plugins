import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Volatile runtime flag - resets to false on every DMS start
    property bool forwardingEnabled: false

    // Read settings from pluginData (set via the Settings panel)
    property string forwardScript: pluginData.script || ""
    property bool forwardLow: pluginData.forwardLow ?? true
    property bool forwardNormal: pluginData.forwardNormal ?? true
    property bool forwardCritical: pluginData.forwardCritical ?? true

    // Track live notification count to detect new arrivals.
    // Uses NotificationService.notifications (live list) rather than historyList
    // so forwarding works regardless of notification history settings.
    property int lastNotifCount: 0

    Component.onCompleted: {
        // Snapshot current count so we don't forward existing notifications on startup
        lastNotifCount = NotificationService.notifications.length
    }

    Connections {
        target: NotificationService

        function onNotificationsChanged() {
            const currentCount = NotificationService.notifications.length
            if (currentCount > root.lastNotifCount) {
                // New notification arrived — it's the last item in the list
                const wrapper = NotificationService.notifications[currentCount - 1]
                if (wrapper) root.forwardWrapper(wrapper)
            }
            root.lastNotifCount = currentCount
        }
    }

    function forwardWrapper(wrapper) {
        if (!root.forwardingEnabled) return
        if (!root.forwardScript) return

        // Urgency: 0 = low, 1 = normal, 2 = critical
        const urgency = typeof wrapper.urgency === "number" ? wrapper.urgency : 1
        if (urgency === 0 && !root.forwardLow) return
        if (urgency === 1 && !root.forwardNormal) return
        if (urgency === 2 && !root.forwardCritical) return

        const payload = JSON.stringify({
            summary: wrapper.summary || "",
            body: wrapper.body || "",
            appName: wrapper.appName || "",
            urgency: urgency,
            timestamp: wrapper.time ? wrapper.time.toISOString() : new Date().toISOString()
        })

        // sh -lc <script> sh <json-payload>  →  payload is $1 in the script
        Quickshell.execDetached(["sh", "-lc", root.forwardScript, "sh", payload])
    }

    function sendTest() {
        if (!root.forwardScript) {
            ToastService.showWarning("Notification Forwarder", "No forwarding script configured")
            return
        }
        const payload = JSON.stringify({
            summary: "Test Notification",
            body: "Test from Notification Forwarder (DMS)",
            appName: "dms",
            urgency: 1,
            timestamp: new Date().toISOString()
        })
        Quickshell.execDetached(["sh", "-lc", root.forwardScript, "sh", payload])
        ToastService.showInfo("Notification Forwarder", "Test notification sent")
    }

    onForwardingEnabledChanged: {
        if (forwardingEnabled) {
            ToastService.showInfo(
                "Notification forwarding enabled",
                "Notifications will be forwarded to external service"
            )
        } else {
            ToastService.showInfo(
                "Notification forwarding disabled",
                "Notifications will no longer be forwarded"
            )
        }
    }

    // IPC — same commands as the noctalia plugin, adjusted target name.
    // Usage: dms ipc call dmsNotifForward <method>
    // For lock/unlock hooks in dankHooks, pair with onSessionLocked/Unlocked.
    IpcHandler {
        target: "dmsNotifForward"

        function toggleForwarding() {
            root.forwardingEnabled = !root.forwardingEnabled
        }

        function enableForwarding() {
            root.forwardingEnabled = true
        }

        function disableForwarding() {
            root.forwardingEnabled = false
        }

        function testForwarding() {
            root.sendTest()
        }
    }

    // ── Bar widget ──────────────────────────────────────────────────────────

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "send"
                size: Theme.iconSize - 6
                color: root.forwardingEnabled ? Theme.primary : Theme.surfaceVariantText
                opacity: root.forwardingEnabled ? 1.0 : 0.4
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            DankIcon {
                name: "send"
                size: Theme.iconSize - 6
                color: root.forwardingEnabled ? Theme.primary : Theme.surfaceVariantText
                opacity: root.forwardingEnabled ? 1.0 : 0.4
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ── Popout panel ────────────────────────────────────────────────────────

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Notification Forwarder"
            detailsText: root.forwardingEnabled ? "Forwarding active" : "Forwarding inactive"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                // Status row
                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "send"
                        size: Theme.iconSize
                        color: root.forwardingEnabled ? Theme.primary : Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: root.forwardingEnabled ? "Forwarding active" : "Forwarding inactive"
                        font.pixelSize: Theme.fontSizeMedium
                        color: root.forwardingEnabled ? Theme.primary : Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Toggle button
                DankButton {
                    width: parent.width
                    text: root.forwardingEnabled ? "Disable Forwarding" : "Enable Forwarding"
                    iconName: "send"
                    onClicked: root.forwardingEnabled = !root.forwardingEnabled
                }

                // Test button
                DankButton {
                    width: parent.width
                    text: "Send Test Notification"
                    iconName: "send"
                    enabled: root.forwardScript !== ""
                    onClicked: root.sendTest()
                }

                StyledRect {
                    width: parent.width
                    height: 1
                    color: Theme.surfaceVariant
                }

                // Script status
                StyledText {
                    width: parent.width
                    text: root.forwardScript
                        ? "Script: " + root.forwardScript
                        : "No script configured — set one in Settings."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
