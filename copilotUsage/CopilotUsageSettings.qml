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
        text: "Requires the gh CLI authenticated with your personal account (gh auth login). Shows your Copilot plan, GitHub API rate limit usage, and a 7-day public-activity chart."
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
}
