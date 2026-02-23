import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dmsOrgAgenda"

    StyledText {
        text: "Org Agenda"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Read-only Emacs org-mode agenda viewer. Runs emacs --batch to export agenda items as JSON. The org-agenda-export.el elisp script is bundled in the plugin directory."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect { width: parent.width; height: 1; color: Theme.surfaceVariant }

    // ── Emacs configuration ───────────────────────────────────────────────

    StyledText {
        text: "Emacs Configuration"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "emacsCommand"
        label: "Emacs Binary"
        description: "Path or name of the Emacs executable"
        placeholder: "emacs"
        defaultValue: "emacs"
    }

    StringSetting {
        settingKey: "emacsInitFile"
        label: "Init File (optional)"
        description: "Load this file before running the export (e.g. ~/.emacs.d/init.el). Leave empty to skip."
        placeholder: "~/.emacs.d/init.el"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "orgDirectory"
        label: "Org Directory"
        description: "Directory containing your .org files"
        placeholder: "~/org"
        defaultValue: "~/org"
    }

    StyledRect { width: parent.width; height: 1; color: Theme.surfaceVariant }

    // ── Display settings ─────────────────────────────────────────────────

    StyledText {
        text: "Display"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "daysBack"
        label: "Days Back"
        description: "How many past days to include in the agenda (default: 3)"
        placeholder: "3"
        defaultValue: "3"
    }

    StringSetting {
        settingKey: "daysForward"
        label: "Days Forward"
        description: "How many future days to include in the agenda (default: 14)"
        placeholder: "14"
        defaultValue: "14"
    }

    StringSetting {
        settingKey: "refreshIntervalMinutes"
        label: "Refresh Interval (minutes)"
        description: "How often to automatically refresh from Emacs (default: 5)"
        placeholder: "5"
        defaultValue: "5"
    }

    ToggleSetting {
        settingKey: "use12hFormat"
        label: "Use 12-hour Format"
        description: "Display times as AM/PM instead of 24-hour"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showDoneItems"
        label: "Show Completed Items"
        description: "Include items with TODO state DONE"
        defaultValue: false
    }

    StyledRect { width: parent.width; height: 1; color: Theme.surfaceVariant }

    // ── Event notifications ───────────────────────────────────────────────

    StyledText {
        text: "Event Notifications"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Uses notify-send to fire desktop notifications before events. If Notification Forwarder is enabled, these will also be forwarded to your external service."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ToggleSetting {
        settingKey: "notificationsEnabled"
        label: "Enable Notifications"
        description: "Send desktop alerts for upcoming timed events"
        defaultValue: true
    }

    StyledText {
        text: "Notify Before Event"
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        color: Theme.surfaceVariantText
    }

    ToggleSetting {
        settingKey: "notifyAtStart"
        label: "At event start"
        description: "Fire when the event begins (urgency: critical)"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "notifyAt5Min"
        label: "5 minutes before"
        description: "urgency: normal"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "notifyAt15Min"
        label: "15 minutes before"
        description: "urgency: low"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "notifyAt30Min"
        label: "30 minutes before"
        description: "urgency: low"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "notifyAt60Min"
        label: "60 minutes before"
        description: "urgency: low"
        defaultValue: false
    }

    StyledRect { width: parent.width; height: 1; color: Theme.surfaceVariant }

    // ── IPC hint ──────────────────────────────────────────────────────────

    StyledText {
        text: "IPC Commands"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledRect {
        width: parent.width
        height: ipcHint.implicitHeight + Theme.spacingM * 2
        color: Theme.surface
        radius: Theme.cornerRadius

        StyledText {
            id: ipcHint
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: Theme.spacingM
            text: "dms ipc call dmsOrgAgenda refreshAgenda\ndms ipc call dmsOrgAgenda testNotification"
            font.pixelSize: Theme.fontSizeSmall
            font.family: "monospace"
            color: Theme.surfaceText
            wrapMode: Text.WordWrap
            lineHeight: 1.5
        }
    }
}
