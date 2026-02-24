import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dmsPasswords"

    // ── Header ──────────────────────────────────────────────────────────────

    StyledText {
        width: parent.width
        text: "Passwords"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Combined Bitwarden (rbw) and Password Store (pass) launcher.\n" +
              "Enter opens a fuzzel field picker. F10 / right-click shows the context menu."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // ── Backends ─────────────────────────────────────────────────────────────

    StyledText {
        width: parent.width
        topPadding: 8
        text: "Backends"
        font.pixelSize: Theme.fontSizeNormal
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "useBitwarden"
        label: "Bitwarden  (rbw)"
        description: "Show entries from rbw (Bitwarden CLI). Icon: shield"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "usePass"
        label: "Password Store  (pass)"
        description: "Show entries from ~/.password-store. Icon: key"
        defaultValue: true
    }

    // ── Enter key action ─────────────────────────────────────────────────────

    StyledText {
        width: parent.width
        topPadding: 8
        text: "Enter Key"
        font.pixelSize: Theme.fontSizeNormal
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "enterAction"
        label: "Default action on Enter"
        description: "What happens when you press Enter on a password entry"
        defaultValue: "picker"
        options: [
            { label: "Field picker (fuzzel)",        value: "picker"   },
            { label: "Type password directly",       value: "password" },
            { label: "Type username then password",  value: "userpass" }
        ]
    }

    // ── Trigger ───────────────────────────────────────────────────────────────

    StyledText {
        width: parent.width
        topPadding: 8
        text: "Trigger"
        font.pixelSize: Theme.fontSizeNormal
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    ToggleSetting {
        id: noTriggerToggle
        settingKey: "noTrigger"
        label: "Always active (no trigger prefix)"
        description: value ? "Entries always appear in the launcher" : "Only appear after typing the trigger"
        defaultValue: false
        onValueChanged: {
            if (value)
                root.saveValue("trigger", "");
            else
                root.saveValue("trigger", triggerSetting.value || "pw");
        }
    }

    StringSetting {
        id: triggerSetting
        visible: !noTriggerToggle.value
        settingKey: "trigger"
        label: "Trigger"
        description: "Prefix to activate password search (e.g. pw, pass, !pw)"
        placeholder: "pw"
        defaultValue: "pw"
    }
}
