import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_countryCode: countryCombo.currentValue
    property alias cfg_cityCode: cityCombo.currentValue
    property alias cfg_districtCode: districtCombo.currentValue
    property alias cfg_cacheDays: cacheDaysSpinBox.value
    property alias cfg_notifyImsak: notifyImsakCheck.checked
    property alias cfg_notifyImsakMinutes: notifyImsakMinutesSpinBox.value
    property alias cfg_notifySunrise: notifySunriseCheck.checked
    property alias cfg_notifySunriseMinutes: notifySunriseMinutesSpinBox.value
    property alias cfg_notifyDhuhr: notifyDhuhrCheck.checked
    property alias cfg_notifyDhuhrMinutes: notifyDhuhrMinutesSpinBox.value
    property alias cfg_notifyAsr: notifyAsrCheck.checked
    property alias cfg_notifyAsrMinutes: notifyAsrMinutesSpinBox.value
    property alias cfg_notifyMaghrib: notifyMaghribCheck.checked
    property alias cfg_notifyMaghribMinutes: notifyMaghribMinutesSpinBox.value
    property alias cfg_notifyIsha: notifyIshaCheck.checked
    property alias cfg_notifyIshaMinutes: notifyIshaMinutesSpinBox.value
    property string cfg_countryName
    property string cfg_cityName
    property string cfg_districtName

    property var countries: []
    property var cities: []
    property var districts: []
    property bool loadingCountries: false
    property bool loadingCities: false
    property bool loadingDistricts: false

    Component.onCompleted: {
        loadCountries()
    }

    function loadCountries() {
        loadingCountries = true
        countries = []

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loadingCountries = false
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        countries = response.map(function(c) {
                            return {
                                name: c.UlkeAdi,
                                nameEn: c.UlkeAdiEn,
                                code: parseInt(c.UlkeID)
                            }
                        })

                        // Set current country
                        for (var i = 0; i < countries.length; i++) {
                            if (countries[i].code === cfg_countryCode) {
                                countryCombo.currentIndex = i
                                loadCities(countries[i].code)
                                break
                            }
                        }
                    } catch (e) {
                        console.error("Country loading error:", e)
                    }
                }
            }
        }
        xhr.open("GET", "https://ezanvakti.emushaf.net/ulkeler")
        xhr.send()
    }

    function loadCities(countryCode) {
        loadingCities = true
        cities = []
        districts = []

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loadingCities = false
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        cities = response.map(function(c) {
                            return {
                                name: c.SehirAdi,
                                nameEn: c.SehirAdiEn,
                                code: parseInt(c.SehirID)
                            }
                        })

                        // Set current city
                        var found = false
                        for (var i = 0; i < cities.length; i++) {
                            if (cities[i].code === cfg_cityCode) {
                                cityCombo.currentIndex = i
                                loadDistricts(cities[i].code)
                                found = true
                                break
                            }
                        }

                        // If not found, select first city
                        if (!found && cities.length > 0) {
                            cityCombo.currentIndex = 0
                            cfg_cityCode = cities[0].code
                            cfg_cityName = cities[0].name
                            loadDistricts(cities[0].code)
                        }
                    } catch (e) {
                        console.error("City loading error:", e)
                    }
                }
            }
        }
        xhr.open("GET", "https://ezanvakti.emushaf.net/sehirler/" + countryCode)
        xhr.send()
    }

    function loadDistricts(cityCode) {
        loadingDistricts = true
        districts = []

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loadingDistricts = false
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        districts = response.map(function(d) {
                            return {
                                name: d.IlceAdi,
                                code: parseInt(d.IlceID)
                            }
                        })

                        // Set current district or first district
                        var found = false
                        for (var i = 0; i < districts.length; i++) {
                            if (districts[i].code === cfg_districtCode) {
                                districtCombo.currentIndex = i
                                found = true
                                break
                            }
                        }

                        // If not found, select first district
                        if (!found && districts.length > 0) {
                            districtCombo.currentIndex = 0
                            cfg_districtCode = districts[0].code
                            cfg_districtName = districts[0].name
                        }
                    } catch (e) {
                        console.error("District loading error:", e)
                    }
                }
            }
        }
        xhr.open("GET", "https://ezanvakti.emushaf.net/ilceler/" + cityCode)
        xhr.send()
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: countryCombo
            Kirigami.FormData.label: i18n("Ülke:")
            textRole: "name"
            valueRole: "code"
            model: countries
            enabled: !loadingCountries && countries.length > 0
            onActivated: {
                if (currentIndex >= 0) {
                    var country = countries[currentIndex]
                    cfg_countryName = country.name
                    cfg_countryCode = country.code
                    loadCities(country.code)
                }
            }
        }

        QQC2.Label {
            text: loadingCountries ? i18n("Ülkeler yükleniyor...") : ""
            visible: loadingCountries
            font.italic: true
        }

        QQC2.ComboBox {
            id: cityCombo
            Kirigami.FormData.label: i18n("Şehir:")
            textRole: "name"
            valueRole: "code"
            model: cities
            enabled: !loadingCities && cities.length > 0
            onActivated: {
                if (currentIndex >= 0) {
                    var city = cities[currentIndex]
                    cfg_cityName = city.name
                    cfg_cityCode = city.code
                    loadDistricts(city.code)
                }
            }
        }

        QQC2.Label {
            text: loadingCities ? i18n("Şehirler yükleniyor...") : ""
            visible: loadingCities
            font.italic: true
        }

        QQC2.ComboBox {
            id: districtCombo
            Kirigami.FormData.label: i18n("İlçe:")
            textRole: "name"
            valueRole: "code"
            model: districts
            enabled: !loadingDistricts && districts.length > 0
            onActivated: {
                if (currentIndex >= 0 && currentIndex < districts.length) {
                    var district = districts[currentIndex]
                    cfg_districtCode = district.code
                    cfg_districtName = district.name
                }
            }
        }

        QQC2.Label {
            text: loadingDistricts ? i18n("İlçeler yükleniyor...") : ""
            visible: loadingDistricts
            font.italic: true
        }

        Item {
            Layout.preferredHeight: Kirigami.Units.largeSpacing * 2
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        QQC2.SpinBox {
            id: cacheDaysSpinBox
            Kirigami.FormData.label: i18n("Önbellek günü:")
            from: 7
            to: 365
            stepSize: 1
            editable: true
        }

        QQC2.Label {
            text: i18n("Çevrimdışı kullanım için kaç günlük veri indirileceğini belirler. İnternet olmadan da vakitleri görebilirsiniz.")
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: Kirigami.Theme.disabledTextColor
        }

        Item {
            Layout.preferredHeight: Kirigami.Units.largeSpacing * 2
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Kirigami.FormData.label: i18n("Bildirim ayarları:")

        RowLayout {
            QQC2.CheckBox {
                id: notifyImsakCheck
                text: i18n("İmsak")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
            }
            QQC2.SpinBox {
                id: notifyImsakMinutesSpinBox
                from: 1
                to: 60
                enabled: notifyImsakCheck.checked
            }
            QQC2.Label {
                text: i18n("dk önce")
                enabled: notifyImsakCheck.checked
            }
        }

        RowLayout {
            QQC2.CheckBox {
                id: notifySunriseCheck
                text: i18n("Güneş")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
            }
            QQC2.SpinBox {
                id: notifySunriseMinutesSpinBox
                from: 1
                to: 60
                enabled: notifySunriseCheck.checked
            }
            QQC2.Label {
                text: i18n("dk önce")
                enabled: notifySunriseCheck.checked
            }
        }

        RowLayout {
            QQC2.CheckBox {
                id: notifyDhuhrCheck
                text: i18n("Öğle")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
            }
            QQC2.SpinBox {
                id: notifyDhuhrMinutesSpinBox
                from: 1
                to: 60
                enabled: notifyDhuhrCheck.checked
            }
            QQC2.Label {
                text: i18n("dk önce")
                enabled: notifyDhuhrCheck.checked
            }
        }

        RowLayout {
            QQC2.CheckBox {
                id: notifyAsrCheck
                text: i18n("İkindi")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
            }
            QQC2.SpinBox {
                id: notifyAsrMinutesSpinBox
                from: 1
                to: 60
                enabled: notifyAsrCheck.checked
            }
            QQC2.Label {
                text: i18n("dk önce")
                enabled: notifyAsrCheck.checked
            }
        }

        RowLayout {
            QQC2.CheckBox {
                id: notifyMaghribCheck
                text: i18n("Akşam")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
            }
            QQC2.SpinBox {
                id: notifyMaghribMinutesSpinBox
                from: 1
                to: 60
                enabled: notifyMaghribCheck.checked
            }
            QQC2.Label {
                text: i18n("dk önce")
                enabled: notifyMaghribCheck.checked
            }
        }

        RowLayout {
            QQC2.CheckBox {
                id: notifyIshaCheck
                text: i18n("Yatsı")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
            }
            QQC2.SpinBox {
                id: notifyIshaMinutesSpinBox
                from: 1
                to: 60
                enabled: notifyIshaCheck.checked
            }
            QQC2.Label {
                text: i18n("dk önce")
                enabled: notifyIshaCheck.checked
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Namaz vakitleri T.C. Diyanet İşleri Başkanlığı verilerinden alınmaktadır. 209 ülke desteklenmektedir.")
            visible: true
        }
    }
}
