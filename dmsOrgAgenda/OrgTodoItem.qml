import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

// Individual todo item card for the Todo tab
Item {
    id: root

    property var item: null
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

        // Priority left-edge bar
        Rectangle {
            Layout.preferredWidth: 4
            Layout.fillHeight: true
            Layout.minimumHeight: 36
            radius: 2
            color: {
                const p = item?.priority ?? "";
                if (p === "A") return "#EF5350";
                if (p === "B") return "#FF9800";
                if (p === "C") return "#4CAF50";
                return Theme.outline;
            }
        }

        // Main content
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // Title row: state badge + title
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS

                // TODO state badge
                Rectangle {
                    visible: (item?.todoState ?? "") !== ""
                    width: stateText.implicitWidth + Theme.spacingS
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
                        id: stateText
                        anchors.centerIn: parent
                        text: item?.todoState ?? ""
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
                    color: Theme.surfaceText
                }
            }

            // Metadata row: category · deadline · scheduled · tags
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS
                visible: (item?.category ?? "") !== "" ||
                         (item?.deadline ?? "") !== "" ||
                         (item?.scheduled ?? "") !== "" ||
                         (item?.tags?.length ?? 0) > 0

                StyledText {
                    visible: (item?.category ?? "") !== ""
                    text: item?.category ?? ""
                    font.pixelSize: Theme.fontSizeXSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    visible: (item?.category ?? "") !== "" &&
                             ((item?.deadline ?? "") !== "" || (item?.scheduled ?? "") !== "")
                    text: "·"
                    font.pixelSize: Theme.fontSizeXSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    visible: (item?.deadline ?? "") !== ""
                    text: "Due: " + (item?.deadline ?? "").replace(/<|>|\[|\]/g, "").replace(/\s+[.+][0-9].*/, "").trim()
                    font.pixelSize: Theme.fontSizeXSmall
                    color: "#FF9800"
                }

                StyledText {
                    visible: (item?.scheduled ?? "") !== "" && (item?.deadline ?? "") === ""
                    text: "Sched: " + (item?.scheduled ?? "").replace(/<|>|\[|\]/g, "").replace(/\s+[.+][0-9].*/, "").trim()
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
