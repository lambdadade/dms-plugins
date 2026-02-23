import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // ── Popout size ─────────────────────────────────────────────────────────
    popoutWidth: 560
    popoutHeight: 700

    // ── Data state ──────────────────────────────────────────────────────────
    property var agendaItems: []
    property bool loading: false
    property bool hasError: false
    property string errorMessage: ""
    property int agendaRevision: 0

    // ── Todo state ───────────────────────────────────────────────────────────
    property var todoItems: []
    property bool todoLoading: false
    property int todoRevision: 0

    // ── Navigation state ────────────────────────────────────────────────────
    property date viewDate: new Date()
    property int viewSpan: 7  // 1 = day, 7 = week

    // ── Notification state ──────────────────────────────────────────────────
    property var firedNotifications: ({})
    property bool startupGracePeriod: true
    property string lastCheckDate: ""

    // ── Settings (from pluginData, set via Settings panel) ──────────────────
    property string emacsCommand: pluginData.emacsCommand || "emacs"
    property string emacsInitFile: pluginData.emacsInitFile || ""
    property string orgDirectory: pluginData.orgDirectory || "~/org"
    property int daysBack: parseInt(pluginData.daysBack) || 3
    property int daysForward: parseInt(pluginData.daysForward) || 14
    property int refreshIntervalMinutes: parseInt(pluginData.refreshIntervalMinutes) || 5
    property string timeFormat: (pluginData.use12hFormat ?? false) ? "12h" : "24h"
    property bool showDoneItems: pluginData.showDoneItems ?? false
    property bool notificationsEnabled: pluginData.notificationsEnabled ?? true
    property bool notifyAtStart: pluginData.notifyAtStart ?? true
    property bool notifyAt5Min: pluginData.notifyAt5Min ?? false
    property bool notifyAt15Min: pluginData.notifyAt15Min ?? true
    property bool notifyAt30Min: pluginData.notifyAt30Min ?? false
    property bool notifyAt60Min: pluginData.notifyAt60Min ?? false
    property string todoKeywords: pluginData.todoKeywords || "NEXT,TODO"

    // ── Derived properties ───────────────────────────────────────────────────
    readonly property var todayItems: {
        const rev = agendaRevision;
        const todayStr = formatDateStr(new Date());
        return agendaItems.filter(item => item.date === todayStr);
    }
    readonly property int todayCount: todayItems.length

    readonly property var overdueItems: {
        const rev = agendaRevision;
        return agendaItems.filter(item => item.isOverdue);
    }
    readonly property int overdueCount: overdueItems.length

    readonly property color statusDotColor: {
        if (overdueCount > 0) return "#EF5350";
        if (todayCount > 0) return "#FFC107";
        return "#4CAF50";
    }

    readonly property string nextEventText: {
        const rev = agendaRevision;
        const nowTime = formatTimeStr(new Date());
        const upcoming = todayItems
            .filter(item => item.time && item.time >= nowTime)
            .sort((a, b) => a.time.localeCompare(b.time));
        if (upcoming.length > 0) {
            const ev = upcoming[0];
            return (ev.time ? ev.time + " " : "") + ev.title;
        }
        if (overdueCount > 0) return "OVERDUE: " + overdueItems[0].title;
        return "";
    }

    readonly property var visibleItems: {
        const rev = agendaRevision;
        const startStr = formatDateStr(viewDate);
        const endDate = new Date(viewDate);
        endDate.setDate(endDate.getDate() + viewSpan);
        const endStr = formatDateStr(endDate);
        return agendaItems.filter(item => item.date >= startStr && item.date < endStr);
    }

    readonly property var dayGroups: {
        const rev = agendaRevision;
        const groups = {};
        const order = [];
        visibleItems.forEach(item => {
            if (!groups[item.date]) {
                groups[item.date] = [];
                order.push(item.date);
            }
            groups[item.date].push(item);
        });
        return order.map(date => ({
            date: date,
            isToday: date === formatDateStr(new Date()),
            items: groups[date]
        }));
    }

    // ── Initialisation ───────────────────────────────────────────────────────
    Component.onCompleted: {
        refresh();
        refreshTodo();
    }

    // ── Auto-refresh timer ───────────────────────────────────────────────────
    Timer {
        id: refreshTimer
        interval: root.refreshIntervalMinutes * 60 * 1000
        running: true
        repeat: true
        onTriggered: {
            root.refresh();
            root.refreshTodo();
        }
    }

    // ── Notification check timer ─────────────────────────────────────────────
    Timer {
        id: notificationTimer
        interval: 60 * 1000
        running: root.notificationsEnabled
        repeat: true
        onTriggered: root.checkNotifications()
    }

    // ── Emacs process ────────────────────────────────────────────────────────
    Process {
        id: emacsProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            timeoutTimer.stop();
            root.loading = false;

            if (exitCode !== 0) {
                root.hasError = true;
                root.errorMessage = String(stderr.text).trim() || "Emacs exited with code " + exitCode;
                root.agendaItems = [];
                root.agendaRevision++;
                ToastService.showError("Org Agenda", root.errorMessage);
                return;
            }

            try {
                const output = String(stdout.text).trim();
                if (!output || output === "[]" || output === "null") {
                    root.agendaItems = [];
                } else {
                    const parsed = JSON.parse(output);
                    root.agendaItems = root.showDoneItems
                        ? parsed
                        : parsed.filter(item => item.todoState !== "DONE");
                }
                root.hasError = false;
                root.errorMessage = "";
            } catch (e) {
                root.hasError = true;
                root.errorMessage = "JSON parse error: " + e.message;
                root.agendaItems = [];
            }

            root.agendaRevision++;
            root.checkNotifications();
        }
    }

    // ── Timeout guard ────────────────────────────────────────────────────────
    Timer {
        id: timeoutTimer
        interval: 30000
        running: false
        repeat: false
        onTriggered: {
            if (emacsProc.running) {
                emacsProc.signal(15);
                root.loading = false;
                root.hasError = true;
                root.errorMessage = "Emacs timed out (30s)";
                root.agendaRevision++;
            }
        }
    }

    // ── Todo emacs process ───────────────────────────────────────────────────
    Process {
        id: todoProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            todoTimeoutTimer.stop();
            root.todoLoading = false;

            if (exitCode !== 0) {
                root.todoItems = [];
                root.todoRevision++;
                ToastService.showError("Org Todo", "exit " + exitCode + ": " + String(stderr.text).trim().slice(0, 100));
                return;
            }

            try {
                const output = String(stdout.text).trim();
                if (output && output !== "[]" && output !== "null") {
                    root.todoItems = JSON.parse(output);
                } else {
                    root.todoItems = [];
                }
            } catch (e) {
                root.todoItems = [];
            }

            root.todoRevision++;
        }
    }

    // ── Todo timeout guard ───────────────────────────────────────────────────
    Timer {
        id: todoTimeoutTimer
        interval: 30000
        running: false
        repeat: false
        onTriggered: {
            if (todoProc.running) {
                todoProc.signal(15);
                root.todoLoading = false;
                root.todoRevision++;
            }
        }
    }

    // ── Public functions ─────────────────────────────────────────────────────
    function refresh() {
        if (emacsProc.running) return;

        root.loading = true;
        root.hasError = false;

        const home = Quickshell.env("HOME");
        const orgDir = root.orgDirectory.replace("~", home);

        // Resolve the elisp script path from the plugin directory
        const elispUrl = Qt.resolvedUrl("./org-agenda-export.el").toString();
        const elispPath = elispUrl.startsWith("file://") ? elispUrl.slice(7) : elispUrl;

        var cmd = root.emacsCommand + " --batch";
        if (root.emacsInitFile) {
            const initPath = root.emacsInitFile.replace("~", home);
            cmd += " -l '" + initPath + "'";
        }
        cmd += " -l '" + elispPath + "'";
        cmd += " --eval '(org-agenda-export-json " + root.daysBack + " " + root.daysForward + " \"" + orgDir + "\")'";

        emacsProc.command = ["sh", "-c", cmd];
        emacsProc.running = true;
        timeoutTimer.start();
    }

    function refreshTodo() {
        if (todoProc.running) return;

        root.todoLoading = true;

        const home = Quickshell.env("HOME");
        const orgDir = root.orgDirectory.replace("~", home);

        const elispUrl = Qt.resolvedUrl("./org-agenda-export.el").toString();
        const elispPath = elispUrl.startsWith("file://") ? elispUrl.slice(7) : elispUrl;

        // Convert comma-separated keywords to space-separated for elisp
        const keywords = root.todoKeywords.split(",").map(k => k.trim()).join(" ");

        var cmd = root.emacsCommand + " --batch";
        if (root.emacsInitFile) {
            const initPath = root.emacsInitFile.replace("~", home);
            cmd += " -l '" + initPath + "'";
        }
        cmd += " -l '" + elispPath + "'";
        cmd += " --eval '(org-todo-export-json \"" + keywords + "\" \"" + orgDir + "\")'";

        todoProc.command = ["sh", "-c", cmd];
        todoProc.running = true;
        todoTimeoutTimer.start();
    }

    function checkNotifications() {
        if (!root.notificationsEnabled) return;

        const now = new Date();
        const todayStr = formatDateStr(now);
        const nowMinutes = now.getHours() * 60 + now.getMinutes();

        if (lastCheckDate !== todayStr) {
            firedNotifications = {};
            lastCheckDate = todayStr;
        }

        const intervals = [];
        if (root.notifyAtStart) intervals.push(0);
        if (root.notifyAt5Min) intervals.push(5);
        if (root.notifyAt15Min) intervals.push(15);
        if (root.notifyAt30Min) intervals.push(30);
        if (root.notifyAt60Min) intervals.push(60);
        if (intervals.length === 0) return;

        const items = agendaItems.filter(item =>
            item.date === todayStr && item.time && item.time !== ""
        );

        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            const timeParts = item.time.split(":");
            const eventMinutes = parseInt(timeParts[0]) * 60 + parseInt(timeParts[1]);

            for (let j = 0; j < intervals.length; j++) {
                const leadMin = intervals[j];
                const diff = nowMinutes - (eventMinutes - leadMin);

                if (diff >= 0 && diff <= 2) {
                    const dedupKey = item.date + "|" + item.time + "|" + item.title + "|" + leadMin;
                    if (firedNotifications[dedupKey]) continue;
                    if (startupGracePeriod && leadMin === 0 && diff > 0) continue;

                    firedNotifications[dedupKey] = true;
                    fireNotification(item, leadMin);
                }
            }
        }

        if (startupGracePeriod) startupGracePeriod = false;
    }

    function fireNotification(item, leadMinutes) {
        const timeDisplay = formatDisplayTime(item.time);
        var summary, body, urgency;

        summary = leadMinutes === 0
            ? "Now: " + item.title
            : "In " + leadMinutes + " min: " + item.title;

        body = timeDisplay;
        if (item.category) body += " · " + item.category;
        if (item.type === "deadline") body += " · DEADLINE";

        urgency = (leadMinutes === 0 || item.isOverdue) ? "critical"
                : leadMinutes <= 5 ? "normal"
                : "low";

        Quickshell.execDetached([
            "sh", "-c",
            'notify-send --app-name="Org Agenda" --urgency="$1" --icon=calendar-event -- "$2" "$3"',
            "sh", urgency, summary, body
        ]);
    }

    // ── Navigation helpers ───────────────────────────────────────────────────
    function navigateDays(days) {
        const d = new Date(viewDate);
        d.setDate(d.getDate() + days);
        viewDate = d;
    }

    function goToToday() { viewDate = new Date(); }
    function setViewSpan(span) { viewSpan = span; }

    // ── Format helpers ───────────────────────────────────────────────────────
    function formatDateStr(date) {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(date.getDate()).padStart(2, '0');
        return y + "-" + m + "-" + d;
    }

    function formatTimeStr(date) {
        return String(date.getHours()).padStart(2, '0') + ":" +
               String(date.getMinutes()).padStart(2, '0');
    }

    function formatDisplayDate(dateStr) {
        const parts = dateStr.split("-");
        const d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
        const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return days[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate();
    }

    function formatDisplayTime(timeStr) {
        if (!timeStr) return "";
        if (root.timeFormat !== "12h") return timeStr;
        const parts = timeStr.split(":");
        let h = parseInt(parts[0]);
        const ampm = h >= 12 ? "PM" : "AM";
        h = h % 12 || 12;
        return h + ":" + parts[1] + " " + ampm;
    }

    function getViewDateRangeText() {
        if (viewSpan === 1) return formatDisplayDate(formatDateStr(viewDate));
        const end = new Date(viewDate);
        end.setDate(end.getDate() + viewSpan - 1);
        return formatDisplayDate(formatDateStr(viewDate)) + " – " +
               formatDisplayDate(formatDateStr(end));
    }

    // ── Cleanup ──────────────────────────────────────────────────────────────
    Component.onDestruction: {
        if (emacsProc.running) emacsProc.signal(15);
        if (todoProc.running) todoProc.signal(15);
        timeoutTimer.stop();
        todoTimeoutTimer.stop();
    }

    // ── IPC handler ──────────────────────────────────────────────────────────
    IpcHandler {
        target: "dmsOrgAgenda"

        function refreshAgenda() {
            root.refresh();
        }

        function refreshTodo() {
            root.refreshTodo();
        }

        function testNotification() {
            root.fireNotification({
                title: "Test Event",
                time: root.formatTimeStr(new Date()),
                date: root.formatDateStr(new Date()),
                category: "Test",
                type: "scheduled",
                isOverdue: false
            }, 15);
        }
    }

    // ── Bar pills ────────────────────────────────────────────────────────────

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            // Status dot
            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: root.statusDotColor
                anchors.verticalCenter: parent.verticalCenter
            }

            DankIcon {
                name: "event"
                size: Theme.iconSize - 6
                color: root.overdueCount > 0 ? Theme.error
                     : root.todayCount > 0   ? "#FFC107"
                     : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.overdueCount > 0 || root.todayCount > 0
                text: root.overdueCount > 0
                    ? root.overdueCount + "!"
                    : String(root.todayCount)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: root.overdueCount > 0 ? Theme.error : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: "event"
                size: Theme.iconSize - 6
                color: root.overdueCount > 0 ? Theme.error
                     : root.todayCount > 0   ? "#FFC107"
                     : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.overdueCount > 0 || root.todayCount > 0
                text: root.overdueCount > 0
                    ? root.overdueCount + "!"
                    : String(root.todayCount)
                font.pixelSize: Theme.fontSizeXSmall
                color: root.overdueCount > 0 ? Theme.error : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ── Popout panel ─────────────────────────────────────────────────────────

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Org Agenda"
            detailsText: {
                if (root.loading) return "Loading...";
                if (root.hasError) return "Error";
                if (root.overdueCount > 0) return root.overdueCount + " overdue";
                return root.todayCount + " today";
            }
            showCloseButton: true

            Column {
                id: panelRoot
                width: parent.width
                spacing: Theme.spacingS

                property int activeTab: 0

                // ── Tab bar ───────────────────────────────────────────────
                Row {
                    id: tabBar
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: ["Agenda", "Todo"]

                        Rectangle {
                            required property string modelData
                            required property int index
                            width: (tabBar.width - 2) / 2
                            height: 32
                            radius: Theme.cornerRadius
                            color: panelRoot.activeTab === index
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: panelRoot.activeTab === index ? Font.DemiBold : Font.Normal
                                color: panelRoot.activeTab === index ? Theme.primary : Theme.surfaceVariantText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panelRoot.activeTab = index
                            }
                        }
                    }
                }

                // ── Navigation row (Agenda tab only) ──────────────────────
                StyledRect {
                    visible: panelRoot.activeTab === 0
                    width: parent.width
                    height: navRow.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Row {
                        id: navRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        // Date range display
                        StyledText {
                            text: root.getViewDateRangeText()
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { width: Theme.spacingM; height: 1 }

                        // Search indicator
                        StyledText {
                            visible: agendaContent.searchText !== ""
                            text: "🔍 " + agendaContent.searchText
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Prev
                        Rectangle {
                            width: 28; height: 28; radius: Theme.cornerRadius
                            color: prevArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                            DankIcon { name: "chevron_left"; size: Theme.iconSize - 4; color: Theme.surfaceText; anchors.centerIn: parent }
                            MouseArea { id: prevArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.navigateDays(-(root.viewSpan)); agendaContent.resetSelection() } }
                        }

                        // Today
                        Rectangle {
                            width: 28; height: 28; radius: Theme.cornerRadius
                            color: todayArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                            DankIcon { name: "today"; size: Theme.iconSize - 4; color: Theme.surfaceText; anchors.centerIn: parent }
                            MouseArea { id: todayArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.goToToday(); agendaContent.resetSelection() } }
                        }

                        // Next
                        Rectangle {
                            width: 28; height: 28; radius: Theme.cornerRadius
                            color: nextArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                            DankIcon { name: "chevron_right"; size: Theme.iconSize - 4; color: Theme.surfaceText; anchors.centerIn: parent }
                            MouseArea { id: nextArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.navigateDays(root.viewSpan); agendaContent.resetSelection() } }
                        }

                        // Day/week toggle
                        Rectangle {
                            width: 28; height: 28; radius: Theme.cornerRadius
                            color: spanArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                            DankIcon { name: root.viewSpan === 1 ? "calendar_view_week" : "calendar_view_day"; size: Theme.iconSize - 4; color: Theme.surfaceText; anchors.centerIn: parent }
                            MouseArea { id: spanArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.setViewSpan(root.viewSpan === 1 ? 7 : 1) }
                        }

                        // Refresh
                        Rectangle {
                            width: 28; height: 28; radius: Theme.cornerRadius
                            color: refreshArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                            opacity: root.loading ? 0.4 : 1.0
                            DankIcon { name: "refresh"; size: Theme.iconSize - 4; color: Theme.surfaceText; anchors.centerIn: parent }
                            MouseArea { id: refreshArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: !root.loading; onClicked: root.refresh() }
                        }
                    }
                }

                // ── Agenda list (keyboard-navigable, searchable) ───────────
                Item {
                    id: agendaContent
                    width: parent.width
                    height: 500
                    visible: panelRoot.activeTab === 0
                    focus: panelRoot.activeTab === 0

                    property string searchText: ""
                    property int selectedGroupIndex: 0
                    property int selectedItemIndex: 0

                    function resetSelection() {
                        selectedGroupIndex = 0;
                        selectedItemIndex = 0;
                    }

                    readonly property var filteredGroups: {
                        const rev = root.agendaRevision;
                        const groups = root.dayGroups;
                        if (!searchText) return groups;
                        const lower = searchText.toLowerCase();
                        return groups.map(group => ({
                            date: group.date,
                            isToday: group.isToday,
                            items: group.items.filter(item =>
                                (item.title || "").toLowerCase().includes(lower) ||
                                (item.category || "").toLowerCase().includes(lower) ||
                                (item.todoState || "").toLowerCase().includes(lower)
                            )
                        })).filter(group => group.items.length > 0);
                    }

                    Keys.onUpPressed: {
                        if (selectedItemIndex > 0) {
                            selectedItemIndex--;
                        } else if (selectedGroupIndex > 0) {
                            selectedGroupIndex--;
                            const prev = filteredGroups[selectedGroupIndex];
                            selectedItemIndex = prev ? prev.items.length - 1 : 0;
                        }
                    }
                    Keys.onDownPressed: {
                        const cur = filteredGroups[selectedGroupIndex];
                        if (cur && selectedItemIndex < cur.items.length - 1) {
                            selectedItemIndex++;
                        } else if (selectedGroupIndex < filteredGroups.length - 1) {
                            selectedGroupIndex++;
                            selectedItemIndex = 0;
                        }
                    }
                    Keys.onLeftPressed: {
                        // Already on leftmost (Agenda) tab — no-op
                    }
                    Keys.onRightPressed: {
                        panelRoot.activeTab = 1;
                        todoContent.resetSelection();
                    }
                    Keys.onEscapePressed: {
                        if (searchText !== "") {
                            searchText = "";
                            resetSelection();
                        }
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Backspace) {
                            if (searchText.length > 0) {
                                searchText = searchText.slice(0, -1);
                                resetSelection();
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Home && (event.modifiers & Qt.ControlModifier)) {
                            root.goToToday();
                            resetSelection();
                            event.accepted = true;
                        } else if (event.text && event.text.length === 1 &&
                                   !(event.modifiers & Qt.ControlModifier) &&
                                   !(event.modifiers & Qt.AltModifier)) {
                            searchText += event.text;
                            resetSelection();
                            event.accepted = true;
                        }
                    }

                    Flickable {
                        id: agendaFlickable
                        anchors.fill: parent
                        contentHeight: agendaColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: agendaColumn
                            width: agendaFlickable.width
                            spacing: Theme.spacingS

                            Repeater {
                                model: agendaContent.filteredGroups

                                Column {
                                    id: dayGroupDelegate
                                    required property var modelData
                                    required property int index
                                    width: agendaColumn.width
                                    spacing: Theme.spacingXS

                                    // Day header
                                    StyledRect {
                                        width: parent.width
                                        height: 32
                                        radius: Theme.cornerRadius
                                        color: dayGroupDelegate.modelData.isToday
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                            : Theme.surfaceContainerHigh

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: Theme.spacingM
                                            anchors.rightMargin: Theme.spacingM
                                            anchors.verticalCenter: parent.verticalCenter

                                            StyledText {
                                                text: root.formatDisplayDate(dayGroupDelegate.modelData.date)
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: Font.DemiBold
                                                color: dayGroupDelegate.modelData.isToday ? Theme.primary : Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            StyledText {
                                                visible: dayGroupDelegate.modelData.isToday
                                                text: "  · Today"
                                                font.pixelSize: Theme.fontSizeMedium
                                                color: Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }

                                    // Agenda items
                                    Repeater {
                                        model: dayGroupDelegate.modelData.items

                                        OrgAgendaItem {
                                            required property var modelData
                                            required property int index
                                            width: agendaColumn.width
                                            item: modelData
                                            timeFormat: root.timeFormat
                                            selected: agendaContent.selectedGroupIndex === dayGroupDelegate.index &&
                                                      agendaContent.selectedItemIndex === index
                                        }
                                    }
                                }
                            }

                            // Empty state
                            Item {
                                visible: agendaContent.filteredGroups.length === 0
                                width: agendaFlickable.width
                                height: 200

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingM

                                    DankIcon {
                                        name: "event_busy"
                                        size: 36
                                        color: Theme.surfaceVariantText
                                        opacity: 0.5
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.loading ? "Loading…"
                                            : root.hasError ? "Error: " + root.errorMessage
                                            : agendaContent.searchText ? "No matching items"
                                            : "No agenda items"
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.Wrap
                                        width: 300
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Todo list (keyboard-navigable, searchable) ────────────
                Item {
                    id: todoContent
                    width: parent.width
                    height: 540
                    visible: panelRoot.activeTab === 1
                    focus: panelRoot.activeTab === 1

                    property int selectedIndex: 0
                    property string searchText: ""

                    function resetSelection() {
                        selectedIndex = 0;
                        searchText = "";
                    }

                    readonly property var filteredTodos: {
                        const rev = root.todoRevision;
                        const items = root.todoItems;
                        if (!searchText) return items;
                        const lower = searchText.toLowerCase();
                        return items.filter(item =>
                            (item.title || "").toLowerCase().includes(lower) ||
                            (item.category || "").toLowerCase().includes(lower) ||
                            (item.todoState || "").toLowerCase().includes(lower)
                        );
                    }

                    Keys.onUpPressed: {
                        if (selectedIndex > 0) selectedIndex--;
                    }
                    Keys.onDownPressed: {
                        if (selectedIndex < filteredTodos.length - 1) selectedIndex++;
                    }
                    Keys.onLeftPressed: {
                        panelRoot.activeTab = 0;
                        agendaContent.resetSelection();
                    }
                    Keys.onRightPressed: {
                        // Already on rightmost (Todo) tab — no-op
                    }
                    Keys.onEscapePressed: {
                        if (searchText !== "") {
                            searchText = "";
                            selectedIndex = 0;
                        }
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Backspace) {
                            if (searchText.length > 0) {
                                searchText = searchText.slice(0, -1);
                                selectedIndex = 0;
                            }
                            event.accepted = true;
                        } else if (event.text && event.text.length === 1 &&
                                   !(event.modifiers & Qt.ControlModifier) &&
                                   !(event.modifiers & Qt.AltModifier)) {
                            searchText += event.text;
                            selectedIndex = 0;
                            event.accepted = true;
                        }
                    }

                    Flickable {
                        id: todoFlickable
                        anchors.fill: parent
                        contentHeight: todoColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: todoColumn
                            width: todoFlickable.width
                            spacing: Theme.spacingXS

                            // Search indicator
                            StyledRect {
                                visible: todoContent.searchText !== ""
                                width: todoColumn.width
                                height: 28
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                StyledText {
                                    anchors.centerIn: parent
                                    text: "🔍 " + todoContent.searchText
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
                                }
                            }

                            Repeater {
                                model: todoContent.filteredTodos

                                OrgTodoItem {
                                    required property var modelData
                                    required property int index
                                    width: todoColumn.width
                                    item: modelData
                                    selected: todoContent.selectedIndex === index

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: todoContent.selectedIndex = index
                                    }
                                }
                            }

                            // Empty state
                            Item {
                                visible: todoContent.filteredTodos.length === 0
                                width: todoFlickable.width
                                height: 200

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingM

                                    DankIcon {
                                        name: "check_circle"
                                        size: 36
                                        color: Theme.surfaceVariantText
                                        opacity: 0.5
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.todoLoading ? "Loading…"
                                            : todoContent.searchText ? "No matching items"
                                            : "No TODO items"
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.Wrap
                                        width: 300
                                        horizontalAlignment: Text.AlignHCenter
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
