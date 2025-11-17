import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    property var prayerTimes: ({})
    property bool prayerTimesLoaded: false
    property string nextPrayerName: "---"
    property string nextPrayerTime: "--:--"
    property string nextPrayerRemaining: "..."
    property bool loading: false
    property string errorMessage: ""
    property int updateTrigger: 0  // Dummy counter to force UI updates
    // Base colors
    property color bordoColor: "#4E0727"
    property color bordoSoft: "#741048"
    property color navyColor: "#82C8FC"
    property color navySoft: "#A7DBFF"

    // Theme-aware colors
    property color pastPrayerBackground: Kirigami.Theme.backgroundColor
    property color futurePrayerBackground: Qt.rgba(
        Kirigami.Theme.highlightColor.r,
        Kirigami.Theme.highlightColor.g,
        Kirigami.Theme.highlightColor.b,
        0.2
    )
    property color nextPrayerBackground: Qt.rgba(
        Kirigami.Theme.highlightColor.r,
        Kirigami.Theme.highlightColor.g,
        Kirigami.Theme.highlightColor.b,
        0.4
    )
    property color prayerBorderColor: Qt.rgba(
        Kirigami.Theme.textColor.r,
        Kirigami.Theme.textColor.g,
        Kirigami.Theme.textColor.b,
        0.15
    )
    property color textPrimaryColor: Kirigami.Theme.textColor
    property color textSecondaryColor: Kirigami.Theme.disabledTextColor
    property int currentSeconds: 0
    property bool notificationSent: false

    width: Kirigami.Units.gridUnit * 20
    height: Kirigami.Units.gridUnit * 16.5

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: disconnectSource(sourceName)
    }

    function showNotification(message) {
        var cmd = "notify-send -a 'Ezan Vakitleri' -i clock '" + message + "'"
        executable.connectSource(cmd)
    }

    Timer {
        id: updateTimer
        interval: 86400000 // 24 hours = 86400000ms
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updatePrayerTimes()
    }

    // Countdown timer - updates every second
    Timer {
        id: countdownTimer
        interval: 1000 // 1 second
        running: prayerTimesLoaded
        repeat: true
        onTriggered: calculateNextPrayer()
    }

    property var cachedPrayerData: null

    // Watch for config changes
    Connections {
        target: plasmoid.configuration
        function onDistrictCodeChanged() {
            // Clear memory cache and force network update
            cachedPrayerData = null
            // Force immediate update from network
            updateFromNetwork()
            // Download new cache in background
            downloadCacheData()
        }
        function onCacheDaysChanged() {
            downloadCacheData()
        }
    }

    Component.onCompleted: {
        // Check if we need to download cache
        var cacheTimestamp = plasmoid.configuration.cacheTimestamp
        if (!cacheTimestamp || cacheTimestamp === "") {
            downloadCacheData()
        } else {
            // Check if cache is older than 7 days
            var cacheDate = new Date(cacheTimestamp)
            var now = new Date()
            var daysDiff = Math.floor((now - cacheDate) / (1000 * 60 * 60 * 24))
            if (daysDiff >= 7) {
                downloadCacheData()
            }
        }
    }

    function downloadCacheData() {
        var districtCode = plasmoid.configuration.districtCode || 9541
        var cacheDays = plasmoid.configuration.cacheDays || 61

        var xhr = new XMLHttpRequest()
        var url = "https://ezanvakti.emushaf.net/vakitler/" + districtCode

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        if (response && response.length > 0) {
                            // Filter data to only keep cacheDays worth of data
                            var today = new Date()
                            var filteredData = []

                            for (var i = 0; i < response.length && filteredData.length < cacheDays; i++) {
                                var dateParts = response[i].MiladiTarihKisa.split('.')
                                var itemDate = new Date(dateParts[2], dateParts[1] - 1, dateParts[0])

                                if (itemDate >= today ||
                                    (today - itemDate) < (1000 * 60 * 60 * 24)) { // Include today
                                    filteredData.push(response[i])
                                }
                            }

                            // Save to configuration and memory
                            plasmoid.configuration.cachedData = JSON.stringify(filteredData)
                            plasmoid.configuration.cacheTimestamp = new Date().toISOString()
                            cachedPrayerData = filteredData
                        }
                    } catch (e) {
                        // Silent fail
                    }
                }
            }
        }

        xhr.open("GET", url)
        xhr.send()
    }

    function updatePrayerTimes() {
        loading = true
        errorMessage = ""

        // Try memory cache first (fastest)
        if (cachedPrayerData && cachedPrayerData.length > 0) {
            var todayData = findTodayInData(cachedPrayerData)
            if (todayData) {
                setPrayerTimesFromData(todayData)
                loading = false
                return
            }
        }

        // Try disk cache
        var cachedDataStr = plasmoid.configuration.cachedData
        if (cachedDataStr && cachedDataStr !== "") {
            try {
                cachedPrayerData = JSON.parse(cachedDataStr)
                var todayData = findTodayInData(cachedPrayerData)

                if (todayData) {
                    setPrayerTimesFromData(todayData)
                    loading = false
                    return
                }
            } catch (e) {
                cachedPrayerData = null
            }
        }

        // If cache fails, get from network (only when needed)
        updateFromNetwork()
    }

    function updateFromNetwork() {
        var districtCode = plasmoid.configuration.districtCode || 9541
        var xhr = new XMLHttpRequest()
        var url = "https://ezanvakti.emushaf.net/vakitler/" + districtCode

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loading = false
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        if (response && response.length > 0) {
                            // Cache the response
                            cachedPrayerData = response

                            var todayData = findTodayInData(response)

                            if (todayData) {
                                setPrayerTimesFromData(todayData)
                            } else {
                                errorMessage = "Bugünün vakti bulunamadı"
                            }
                        } else {
                            errorMessage = "Veri alınamadı"
                        }
                    } catch (e) {
                        errorMessage = "Veri işlenirken hata: " + e
                    }
                } else {
                    errorMessage = "Bağlantı hatası: " + xhr.status
                }
            }
        }

        xhr.open("GET", url)
        xhr.send()
    }

    function findTodayInData(data) {
        var today = new Date()
        var todayStr = today.getDate().toString().padStart(2, '0') + "." +
                     (today.getMonth() + 1).toString().padStart(2, '0') + "." +
                     today.getFullYear()

        for (var i = 0; i < data.length; i++) {
            if (data[i].MiladiTarihKisa === todayStr) {
                return data[i]
            }
        }
        return null
    }

    function setPrayerTimesFromData(todayData) {
        prayerTimes = {
            imsak: todayData.Imsak,
            fajr: todayData.Imsak,
            sunrise: todayData.Gunes,
            dhuhr: todayData.Ogle,
            asr: todayData.Ikindi,
            maghrib: todayData.Aksam,
            isha: todayData.Yatsi
        }
        prayerTimesLoaded = true
        calculateNextPrayer()
    }

    function calculateNextPrayer() {
        if (!prayerTimes || Object.keys(prayerTimes).length === 0) {
            return
        }

        var now = new Date()
        var currentSeconds = now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()
        root.currentSeconds = currentSeconds

        var prayerOrder = [
            {key: 'imsak', name: 'İmsak'},
            {key: 'sunrise', name: 'Güneş'},
            {key: 'dhuhr', name: 'Öğle'},
            {key: 'asr', name: 'İkindi'},
            {key: 'maghrib', name: 'Akşam'},
            {key: 'isha', name: 'Yatsı'}
        ]

        for (var i = 0; i < prayerOrder.length; i++) {
            var prayer = prayerOrder[i]
            if (prayerTimes[prayer.key]) {
                var parts = prayerTimes[prayer.key].split(':')
                var prayerSeconds = parseInt(parts[0]) * 3600 + parseInt(parts[1]) * 60

                if (currentSeconds < prayerSeconds) {
                    var diff = prayerSeconds - currentSeconds
                    var hours = Math.floor(diff / 3600)
                    var mins = Math.floor((diff % 3600) / 60)
                    var secs = diff % 60

                    var hoursStr = String(hours).padStart(2, '0')
                    var minsStr = String(mins).padStart(2, '0')
                    var secsStr = String(secs).padStart(2, '0')

                    var remainingText = hoursStr + ":" + minsStr + ":" + secsStr

                    // Check if prayer changed (reset notification flag)
                    if (nextPrayerName !== prayer.name) {
                        notificationSent = false
                    }

                    nextPrayerName = prayer.name
                    nextPrayerTime = prayerTimes[prayer.key]
                    nextPrayerRemaining = remainingText
                    updateTrigger++

                    // Get notification settings for this prayer
                    var notifyEnabled = false
                    var notificationMinutes = 15

                    if (prayer.key === 'imsak') {
                        notifyEnabled = plasmoid.configuration.notifyImsak
                        notificationMinutes = plasmoid.configuration.notifyImsakMinutes || 15
                    } else if (prayer.key === 'sunrise') {
                        notifyEnabled = plasmoid.configuration.notifySunrise
                        notificationMinutes = plasmoid.configuration.notifySunriseMinutes || 15
                    } else if (prayer.key === 'dhuhr') {
                        notifyEnabled = plasmoid.configuration.notifyDhuhr
                        notificationMinutes = plasmoid.configuration.notifyDhuhrMinutes || 15
                    } else if (prayer.key === 'asr') {
                        notifyEnabled = plasmoid.configuration.notifyAsr
                        notificationMinutes = plasmoid.configuration.notifyAsrMinutes || 15
                    } else if (prayer.key === 'maghrib') {
                        notifyEnabled = plasmoid.configuration.notifyMaghrib
                        notificationMinutes = plasmoid.configuration.notifyMaghribMinutes || 15
                    } else if (prayer.key === 'isha') {
                        notifyEnabled = plasmoid.configuration.notifyIsha
                        notificationMinutes = plasmoid.configuration.notifyIshaMinutes || 15
                    }

                    // Reset flag if we're above the threshold (allows notification to trigger when we cross threshold)
                    if (hours > 0 || mins >= notificationMinutes) {
                        notificationSent = false
                    }

                    if (!notificationSent && notifyEnabled && hours === 0 && mins < notificationMinutes) {
                        var message = "KARDEŞİM ÖNCE NAMAZ! " + prayer.name + " vakti için " + mins + " dk kaldı!"
                        showNotification(message)
                        notificationSent = true
                    }

                    return
                }
            }
        }

        // Next prayer is tomorrow's Imsak
        nextPrayerName = 'İmsak'
        nextPrayerTime = prayerTimes.imsak || "--:--"

        // Calculate time until tomorrow's Imsak
        if (prayerTimes.imsak) {
            var parts = prayerTimes.imsak.split(':')
            var imsakSeconds = parseInt(parts[0]) * 3600 + parseInt(parts[1]) * 60
            var secondsUntilMidnight = 86400 - currentSeconds // 24*3600 = 86400
            var diff = secondsUntilMidnight + imsakSeconds

            var hours = Math.floor(diff / 3600)
            var mins = Math.floor((diff % 3600) / 60)
            var secs = diff % 60

            var hoursStr = String(hours).padStart(2, '0')
            var minsStr = String(mins).padStart(2, '0')
            var secsStr = String(secs).padStart(2, '0')

            nextPrayerRemaining = hoursStr + ":" + minsStr + ":" + secsStr
        } else {
            nextPrayerRemaining = '00:00:00'
        }
        updateTrigger++
    }

    function timeStringToSeconds(timeStr) {
        if (!timeStr || timeStr.indexOf(":") === -1)
            return -1
        var parts = timeStr.split(":")
        var hours = parseInt(parts[0])
        var mins = parseInt(parts[1])
        if (isNaN(hours) || isNaN(mins))
            return -1
        return hours * 3600 + mins * 60
    }

    compactRepresentation: Item {
        Layout.minimumWidth: compactText.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: compactText.implicitHeight + Kirigami.Units.smallSpacing

        Text {
            id: compactText
            anchors.centerIn: parent
            text: {
                updateTrigger; // Force dependency
                return nextPrayerName + ": " + nextPrayerRemaining;
            }
            font.pointSize: Kirigami.Theme.defaultFont.pointSize
            color: Kirigami.Theme.textColor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 15

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // Header
            RowLayout {
                Layout.fillWidth: true

                Kirigami.Icon {
                    source: "clock"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "Namaz Vakitleri"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                        font.bold: true
                        color: textPrimaryColor
                    }

                    Text {
                        text: plasmoid.configuration.countryName + " - " + plasmoid.configuration.cityName + " / " + plasmoid.configuration.districtName
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: textSecondaryColor
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: prayerBorderColor
            }

            // Next Prayer - Enhanced gradient design
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 3.5
                radius: Kirigami.Units.largeSpacing
                color: Qt.rgba(
                    Kirigami.Theme.highlightColor.r,
                    Kirigami.Theme.highlightColor.g,
                    Kirigami.Theme.highlightColor.b,
                    0.15
                )
                border.width: 1
                border.color: Qt.rgba(
                    Kirigami.Theme.highlightColor.r,
                    Kirigami.Theme.highlightColor.g,
                    Kirigami.Theme.highlightColor.b,
                    0.5
                )

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Text {
                            text: "⏰ Bir Sonraki Vakit"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: textSecondaryColor
                        }

                        Text {
                            text: nextPrayerName
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                            font.bold: true
                            color: textPrimaryColor
                        }
                    }

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Layout.alignment: Qt.AlignRight

                        Text {
                            text: {
                                updateTrigger; // Force dependency
                                return nextPrayerRemaining;
                            }
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.8
                            font.bold: true
                            color: Kirigami.Theme.highlightColor
                            Layout.alignment: Qt.AlignRight
                        }

                        Text {
                            text: nextPrayerTime
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: textSecondaryColor
                            Layout.alignment: Qt.AlignRight
                        }
                    }
                }
            }

            // Prayer Times List
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: Kirigami.Units.largeSpacing
                columnSpacing: Kirigami.Units.largeSpacing

                PrayerTimeItem {
                    name: "İmsak"
                    time: prayerTimes.imsak || "---"
                    prayerSeconds: root.timeStringToSeconds(prayerTimes.imsak)
                    currentSeconds: root.currentSeconds
                    isNext: nextPrayerName === "İmsak"
                }

                PrayerTimeItem {
                    name: "Güneş"
                    time: prayerTimes.sunrise || "---"
                    prayerSeconds: root.timeStringToSeconds(prayerTimes.sunrise)
                    currentSeconds: root.currentSeconds
                    isNext: nextPrayerName === "Güneş"
                }

                PrayerTimeItem {
                    name: "Öğle"
                    time: prayerTimes.dhuhr || "---"
                    prayerSeconds: root.timeStringToSeconds(prayerTimes.dhuhr)
                    currentSeconds: root.currentSeconds
                    isNext: nextPrayerName === "Öğle"
                }

                PrayerTimeItem {
                    name: "İkindi"
                    time: prayerTimes.asr || "---"
                    prayerSeconds: root.timeStringToSeconds(prayerTimes.asr)
                    currentSeconds: root.currentSeconds
                    isNext: nextPrayerName === "İkindi"
                }

                PrayerTimeItem {
                    name: "Akşam"
                    time: prayerTimes.maghrib || "---"
                    prayerSeconds: root.timeStringToSeconds(prayerTimes.maghrib)
                    currentSeconds: root.currentSeconds
                    isNext: nextPrayerName === "Akşam"
                }

                PrayerTimeItem {
                    name: "Yatsı"
                    time: prayerTimes.isha || "---"
                    prayerSeconds: root.timeStringToSeconds(prayerTimes.isha)
                    currentSeconds: root.currentSeconds
                    isNext: nextPrayerName === "Yatsı"
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
