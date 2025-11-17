import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    property string name: ""
    property string time: ""
    property int prayerSeconds: -1
    property int currentSeconds: -1
    property bool isNext: false
    property color pastColor: Kirigami.Theme.backgroundColor
    property color futureColor: Qt.rgba(
        Kirigami.Theme.highlightColor.r,
        Kirigami.Theme.highlightColor.g,
        Kirigami.Theme.highlightColor.b,
        0.2
    )
    property color nextColor: Qt.rgba(
        Kirigami.Theme.highlightColor.r,
        Kirigami.Theme.highlightColor.g,
        Kirigami.Theme.highlightColor.b,
        0.4
    )
    property color borderColor: Qt.rgba(
        Kirigami.Theme.textColor.r,
        Kirigami.Theme.textColor.g,
        Kirigami.Theme.textColor.b,
        0.15
    )
    property color textColor: Kirigami.Theme.textColor
    property string iconText: ""
    readonly property bool isPast: prayerSeconds > -1 && currentSeconds > 0 && prayerSeconds < currentSeconds
    readonly property string computedIcon: iconText !== "" ? iconText :
        (name === "İmsak" ? "🌙" :
        name === "Güneş" ? "🌅" :
        name === "Öğle" ? "☀️" :
        name === "İkindi" ? "🌤️" :
        name === "Akşam" ? "🌇" :
        name === "Yatsı" ? "🌌" : "🕌")

    Layout.fillWidth: true
    Layout.preferredHeight: Kirigami.Units.gridUnit * 2
    radius: Kirigami.Units.smallSpacing
    color: isNext ? nextColor : (isPast ? pastColor : futureColor)
    border.width: 1
    border.color: borderColor

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.largeSpacing

        Text {
            text: computedIcon
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            text: name
            font.pointSize: Kirigami.Theme.defaultFont.pointSize
            color: textColor
            opacity: isPast ? 0.7 : 1.0
            Layout.fillWidth: true
        }

        Text {
            text: time
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
            font.bold: true
            color: textColor
            opacity: isPast ? 0.6 : (isNext ? 1.0 : 0.85)
            Layout.alignment: Qt.AlignRight
        }
    }
}
