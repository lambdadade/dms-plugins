import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

// Individual agenda item card — DMS port of noctalia-plugins/org-agenda/AgendaItem.qml
Item {
    id: root

    property var item: null
    property string timeFormat: "24h"
    property bool selected: false

    implicitHeight: itemLayout.implicitHeight + Theme.spacingS * 2
    implicitWidth: 200  // overridden by parent width binding

    // Selection / hover background
    StyledRect {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: selected
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
            : Theme.surface
        border.width: selected ? 2 : 0
        border.color: Theme.primary
    }

    RowLayout {
        id: itemLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingS

        // Coloured left-edge indicator
        Rectangle {
            Layout.preferredWidth: 4
            Layout.fillHeight: true
            Layout.minimumHeight: 36
            radius: 2
            color: {
                if (!item) return Theme.outline;
                if (item.isOverdue) return "#EF5350";
                if (item.type === "deadline") return "#FF9800";
                if (item.type === "scheduled") return "#2196F3";
                return "#9E9E9E";
            }
        }

        // Time column
        StyledText {
            Layout.preferredWidth: 50
            text: {
                if (!item || !item.time || item.time === "") return "--:--";
                if (timeFormat !== "12h") return item.time;
                const parts = item.time.split(":");
                let h = parseInt(parts[0]);
                const ampm = h >= 12 ? "PM" : "AM";
                h = h % 12 || 12;
                return h + ":" + parts[1] + " " + ampm;
            }
            font.pixelSize: Theme.fontSizeSmall
            font.weight: (item && item.time && item.time !== "") ? Font.Medium : Font.Normal
            color: item?.isOverdue ? "#EF5350"
                 : (!item || !item.time || item.time === "") ? Theme.surfaceVariantText
                 : Theme.surfaceText
            opacity: (!item || !item.time || item.time === "") ? 0.4 : 1.0
        }

        // Main content column
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // Title row (todo badge + priority badge + title + overdue icon)
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS

                // TODO state badge
                Rectangle {
                    visible: (item?.todoState ?? "") !== ""
                    width: todoText.implicitWidth + Theme.spacingS
                    height: 18
                    radius: 3
                    color: {
                        const s = item?.todoState ?? "";
                        if (s === "DONE") return "#4CAF50";
                        if (s === "TODO") return "#2196F3";
                        if (s === "WAITING") return "#FF9800";
                        if (s === "NEXT") return "#7C4DFF";
                        return Theme.surfaceVariant;
                    }

                    StyledText {
                        id: todoText
                        anchors.centerIn: parent
                        text: item?.todoState ?? ""
                        font.pixelSize: Theme.fontSizeXSmall
                        font.weight: Font.Bold
                        color: "#FFFFFF"
                    }
                }

                // Priority badge
                Rectangle {
                    visible: (item?.priority ?? "") !== ""
                    width: 18; height: 18; radius: 3
                    color: {
                        const p = item?.priority ?? "";
                        if (p === "A") return "#EF5350";
                        if (p === "B") return "#FF9800";
                        return "#4CAF50";
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: item?.priority ?? ""
                        font.pixelSize: Theme.fontSizeXSmall
                        font.weight: Font.Bold
                        color: "#FFFFFF"
                    }
                }

                // Title
                StyledText {
                    Layout.fillWidth: true
                    text: item?.title ?? ""
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    color: item?.isOverdue ? "#EF5350" : Theme.surfaceText
                    font.strikeout: item?.todoState === "DONE"
                }

                // Overdue warning icon
                DankIcon {
                    visible: item?.isOverdue ?? false
                    name: "warning"
                    size: Theme.iconSize - 6
                    color: "#EF5350"
                }
            }

            // Category / type / tags row
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS
                visible: (item?.category ?? "") !== "" ||
                         (item?.type ?? "") !== "" ||
                         (item?.tags?.length ?? 0) > 0

                StyledText {
                    visible: (item?.type ?? "") !== ""
                    text: {
                        const t = item?.type ?? "";
                        if (t === "deadline") return "DEADLINE";
                        if (t === "scheduled") return "Scheduled";
                        return "Event";
                    }
                    font.pixelSize: Theme.fontSizeXSmall
                    font.weight: Font.DemiBold
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    visible: (item?.type ?? "") !== "" && (item?.category ?? "") !== ""
                    text: "·"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeXSmall
                }

                StyledText {
                    visible: (item?.category ?? "") !== ""
                    text: item?.category ?? ""
                    font.pixelSize: Theme.fontSizeXSmall
                    color: Theme.surfaceVariantText
                }

                Repeater {
                    model: item?.tags ?? []

                    Rectangle {
                        required property string modelData
                        width: tagLabel.implicitWidth + Theme.spacingS
                        height: 16
                        radius: 8
                        color: Theme.surfaceVariant

                        StyledText {
                            id: tagLabel
                            anchors.centerIn: parent
                            text: ":" + modelData
                            font.pixelSize: Theme.fontSizeXSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }
        }
    }
}
