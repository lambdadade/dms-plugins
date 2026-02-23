import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // ── Settings ────────────────────────────────────────────────────────────
    property int refreshInterval: (pluginData.refreshInterval || 300) * 1000

    // ── Data ────────────────────────────────────────────────────────────────
    property string githubUser: ""
    property string githubName: ""
    property string planType: "unknown"
    property real   rateUtil: 0
    property int    rateUsed: 0
    property int    rateLimit: 5000
    property string rateReset: ""
    property int    graphqlUsed: 0
    property int    graphqlLimit: 5000
    property var    dailyEvents: [0, 0, 0, 0, 0, 0, 0]

    property bool isLoading: true

    // ── Live countdown to rate-limit reset ──────────────────────────────────
    property real countdownNow: Date.now()

    property string rateResetCountdown: {
        if (!rateReset) return ""
        var resetMs = new Date(rateReset).getTime()
        var remaining = Math.max(0, resetMs - countdownNow)
        if (remaining <= 0) return "Resetting…"
        var mins = Math.floor(remaining / 60000)
        var secs = Math.floor((remaining % 60000) / 1000)
        return mins + "m " + (secs < 10 ? "0" : "") + secs + "s"
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.countdownNow = Date.now()
    }

    // ── Rolling day labels (index 0 = 6 days ago, 6 = today) ────────────────
    property var dayLabels: {
        var days = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        var labels = []
        var now = new Date()
        for (var i = 6; i >= 0; i--) {
            var d = new Date(now.getTime() - i * 86400000)
            labels.push(days[d.getDay()])
        }
        return labels
    }

    readonly property real maxDaily: Math.max.apply(null, dailyEvents) || 1

    property string scriptPath: PluginService.pluginDirectory + "/copilotUsage/get-copilot-usage"

    popoutWidth: 380
    popoutHeight: 520

    // ── Helpers ──────────────────────────────────────────────────────────────

    function formatPlan(plan) {
        if (plan === "individual")  return "Individual"
        if (plan === "business")    return "Business"
        if (plan === "enterprise")  return "Enterprise"
        if (plan === "unknown")     return "—"
        return plan
    }

    function rateColor(pct) {
        if (pct > 80) return Theme.error
        if (pct > 50) return Theme.warning
        return Theme.primary
    }

    function parseLine(line) {
        var idx = line.indexOf("=")
        if (idx < 0) return
        var key = line.substring(0, idx)
        var val = line.substring(idx + 1)
        switch (key) {
        case "GITHUB_USER":   githubUser   = val; break
        case "GITHUB_NAME":   githubName   = val; break
        case "PLAN_TYPE":     planType     = val; break
        case "RATE_UTIL":     rateUtil     = parseFloat(val) || 0; break
        case "RATE_USED":     rateUsed     = parseInt(val) || 0; break
        case "RATE_LIMIT":    rateLimit    = parseInt(val) || 5000; break
        case "RATE_RESET":    rateReset    = val; break
        case "GRAPHQL_USED":  graphqlUsed  = parseInt(val) || 0; break
        case "GRAPHQL_LIMIT": graphqlLimit = parseInt(val) || 5000; break
        case "DAILY_EVENTS":
            var parts = val.split(",")
            var arr = []
            for (var j = 0; j < 7; j++)
                arr.push(j < parts.length ? (parseFloat(parts[j]) || 0) : 0)
            dailyEvents = arr
            break
        }
    }

    // ── Data fetching ────────────────────────────────────────────────────────

    Process {
        id: usageProcess
        command: ["bash", root.scriptPath]
        running: false

        stdout: SplitParser {
            onRead: data => root.parseLine(data.trim())
        }

        onExited: root.isLoading = false
    }

    Timer {
        interval: root.refreshInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!usageProcess.running)
                usageProcess.running = true
        }
    }

    // ── Bar pills ────────────────────────────────────────────────────────────

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            Canvas {
                id: hRing
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                renderStrategy: Canvas.Cooperative

                property real percent: root.rateUtil
                onPercentChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var cx = width / 2, cy = height / 2, r = 7.5, lw = 2.5

                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                    ctx.lineWidth = lw
                    ctx.strokeStyle = Theme.surfaceVariant
                    ctx.stroke()

                    var pct = percent / 100
                    if (pct > 0) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, -Math.PI / 2,
                                -Math.PI / 2 + 2 * Math.PI * Math.min(pct, 1))
                        ctx.lineWidth = lw
                        ctx.strokeStyle = root.rateColor(percent)
                        ctx.lineCap = "round"
                        ctx.stroke()
                    }
                }
            }

            StyledText {
                text: Math.round(root.rateUtil) + "%"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS || 4

            Canvas {
                id: vRing
                width: 20
                height: 20
                anchors.horizontalCenter: parent.horizontalCenter
                renderStrategy: Canvas.Cooperative

                property real percent: root.rateUtil
                onPercentChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var cx = width / 2, cy = height / 2, r = 7.5, lw = 2.5

                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                    ctx.lineWidth = lw
                    ctx.strokeStyle = Theme.surfaceVariant
                    ctx.stroke()

                    var pct = percent / 100
                    if (pct > 0) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, -Math.PI / 2,
                                -Math.PI / 2 + 2 * Math.PI * Math.min(pct, 1))
                        ctx.lineWidth = lw
                        ctx.strokeStyle = root.rateColor(percent)
                        ctx.lineCap = "round"
                        ctx.stroke()
                    }
                }
            }

            StyledText {
                text: Math.round(root.rateUtil) + "%"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ── Popout ───────────────────────────────────────────────────────────────

    popoutContent: Component {
        PopoutComponent {
            headerText: "GitHub Copilot"
            detailsText: root.githubUser ? "@" + root.githubUser : ""
            showCloseButton: true

            Column {
                width: parent.width - Theme.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingL

                // ── Plan / identity card ─────────────────────────────────────
                StyledRect {
                    width: parent.width
                    height: planRow.implicitHeight + Theme.spacingS * 2
                    color: Theme.surfaceContainerHigh

                    Row {
                        id: planRow
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "smart_toy"
                            size: 36
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            StyledText {
                                text: root.formatPlan(root.planType) + " Plan"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: {
                                    var parts = []
                                    if (root.githubName) parts.push(root.githubName)
                                    if (root.githubUser) parts.push("@" + root.githubUser)
                                    return parts.join("  ·  ")
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                visible: root.githubUser !== "" && root.githubUser !== "unknown"
                            }
                        }
                    }
                }

                // ── API rate limit card ──────────────────────────────────────
                StyledRect {
                    width: parent.width
                    height: rateRow.implicitHeight + Theme.spacingS * 2
                    color: Theme.surfaceContainerHigh

                    Row {
                        id: rateRow
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingM

                        Canvas {
                            id: bigRing
                            width: 100
                            height: 100
                            anchors.verticalCenter: parent.verticalCenter
                            renderStrategy: Canvas.Cooperative

                            property real percent: root.rateUtil
                            onPercentChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var cx = width / 2, cy = height / 2, r = 38, lw = 8

                                ctx.beginPath()
                                ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                                ctx.lineWidth = lw
                                ctx.strokeStyle = Theme.surfaceVariant
                                ctx.stroke()

                                var pct = percent / 100
                                if (pct > 0) {
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, r, -Math.PI / 2,
                                            -Math.PI / 2 + 2 * Math.PI * Math.min(pct, 1))
                                    ctx.lineWidth = lw
                                    ctx.strokeStyle = root.rateColor(percent)
                                    ctx.lineCap = "round"
                                    ctx.stroke()
                                }
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: Math.round(root.rateUtil) + "%"
                                font.pixelSize: Theme.fontSizeXLarge
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            StyledText {
                                text: "API Rate Limit"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: root.rateUsed.toLocaleString() + " / " + root.rateLimit.toLocaleString() + " used"
                                font.pixelSize: Theme.fontSizeSmall
                                color: root.rateColor(root.rateUtil)
                            }

                            StyledText {
                                text: root.rateResetCountdown
                                    ? "Resets in " + root.rateResetCountdown
                                    : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                visible: root.rateResetCountdown !== ""
                            }

                            StyledText {
                                text: "GraphQL: " + root.graphqlUsed + " / " + root.graphqlLimit
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                visible: root.graphqlLimit > 0
                            }
                        }
                    }
                }

                // ── Daily GitHub activity chart ──────────────────────────────
                StyledRect {
                    width: parent.width
                    height: activityCol.implicitHeight + Theme.spacingM * 2
                    color: Theme.surfaceContainerHigh

                    Column {
                        id: activityCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Daily GitHub Activity (7 days)"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Item {
                            width: parent.width
                            height: 70

                            Row {
                                id: chartRow
                                anchors.fill: parent
                                spacing: 4

                                Repeater {
                                    model: 7
                                    delegate: Column {
                                        width: (chartRow.width - 6 * 4) / 7
                                        height: chartRow.height
                                        spacing: 2

                                        Item {
                                            width: parent.width
                                            height: parent.height - dayLbl.height - 2

                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: Math.max(parent.width - 4, 4)
                                                height: root.maxDaily > 0
                                                    ? Math.max(
                                                        root.dailyEvents[index] / root.maxDaily * parent.height,
                                                        root.dailyEvents[index] > 0 ? 3 : 0)
                                                    : 0
                                                radius: 2
                                                color: index === 6 ? Theme.primary : Theme.surfaceVariant
                                            }
                                        }

                                        StyledText {
                                            id: dayLbl
                                            text: root.dayLabels[index]
                                            font.pixelSize: 11
                                            color: index === 6 ? Theme.primary : Theme.surfaceVariantText
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
