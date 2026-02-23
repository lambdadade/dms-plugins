import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "copilotUsage"

    StyledText {
        width: parent.width
        text: "GitHub Copilot Usage"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Requires gh CLI authenticated with your GitHub account(s)."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SliderSetting {
        settingKey: "refreshInterval"
        label: "Refresh Interval"
        description: "How often to fetch data from GitHub (seconds)"
        defaultValue: 300
        minimum: 60
        maximum: 3600
        unit: "s"
        leftIcon: "schedule"
    }

    StyledText {
        width: parent.width
        text: "Work Account (Copilot Business / Enterprise)"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "workGhUser"
        label: "Work gh CLI Username"
        description: "gh CLI username for your work account (gh auth login → gh auth status to find it). Leave blank to disable."
        placeholder: "marc-seibert_uics"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "workPremiumLimit"
        label: "Monthly Premium Request Limit"
        description: "Your Copilot Business/Enterprise monthly premium request quota. Default is 300."
        placeholder: "300"
        defaultValue: "300"
    }
}
