import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dmsNotifForward"

    StyledText {
        text: "Notification Forwarder"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Forward desktop notifications to an external service via a shell script. Forwarding is off by default on every DMS start — toggle it via the bar widget or IPC."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    // ── Forwarding script ─────────────────────────────────────────────────

    StyledText {
        text: "Forwarding Script"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Shell command to execute. The notification is passed as a JSON string in $1 with keys: summary, body, appName, urgency (0/1/2), timestamp."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "script"
        label: "Script / Command"
        description: "Example: curl -d \"$1\" ntfy.sh/mytopic"
        placeholder: "curl -d \"$1\" ntfy.sh/mytopic"
        defaultValue: ""
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    // ── Urgency filters ───────────────────────────────────────────────────

    StyledText {
        text: "Urgency Filters"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "forwardLow"
        label: "Forward low urgency notifications"
        description: "urgency = 0"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "forwardNormal"
        label: "Forward normal urgency notifications"
        description: "urgency = 1"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "forwardCritical"
        label: "Forward critical urgency notifications"
        description: "urgency = 2"
        defaultValue: true
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    // ── IPC usage hint ────────────────────────────────────────────────────

    StyledText {
        text: "IPC / DankHooks Integration"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Auto-enable forwarding when the screen locks and disable it on unlock by wiring the IPC commands to your dankHooks session hooks:"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: hintText.height + Theme.spacingM * 2
        color: Theme.surface
        radius: Theme.cornerRadius

        StyledText {
            id: hintText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingM
            text: "# dankHooks — Session Locked script:\ndms ipc call dmsNotifForward enableForwarding\n\n# dankHooks — Session Unlocked script:\ndms ipc call dmsNotifForward disableForwarding\n\n# Other IPC commands:\ndms ipc call dmsNotifForward toggleForwarding\ndms ipc call dmsNotifForward testForwarding"
            font.pixelSize: Theme.fontSizeSmall
            font.family: "monospace"
            color: Theme.surfaceText
            wrapMode: Text.WordWrap
            lineHeight: 1.4
        }
    }
}
