// Prayer Times Calculator
// Based on PrayTimes.js algorithm

.pragma library

var DMath = {
    dtr: function(d) { return (d * Math.PI) / 180.0; },
    rtd: function(r) { return (r * 180.0) / Math.PI; },
    sin: function(d) { return Math.sin(this.dtr(d)); },
    cos: function(d) { return Math.cos(this.dtr(d)); },
    tan: function(d) { return Math.tan(this.dtr(d)); },
    arcsin: function(d) { return this.rtd(Math.asin(d)); },
    arccos: function(d) { return this.rtd(Math.acos(d)); },
    arctan: function(d) { return this.rtd(Math.atan(d)); },
    arccot: function(x) { return this.rtd(Math.atan(1/x)); },
    arctan2: function(y, x) { return this.rtd(Math.atan2(y, x)); },
    fixAngle: function(a) { return this.fix(a, 360); },
    fixHour:  function(a) { return this.fix(a, 24 ); },
    fix: function(a, b) {
        a = a - b * (Math.floor(a / b));
        return (a < 0) ? a + b : a;
    }
};

function PrayerTimes(method) {
    // Calculation Methods
    this.methods = {
        MWL: {
            name: 'Muslim World League',
            fajr: 18,
            isha: 17
        },
        ISNA: {
            name: 'Islamic Society of North America (ISNA)',
            fajr: 15,
            isha: 15
        },
        Egypt: {
            name: 'Egyptian General Authority of Survey',
            fajr: 19.5,
            isha: 17.5
        },
        Turkey: {
            name: 'Diyanet İşleri Başkanlığı, Turkey',
            fajr: 18,
            isha: 17
        },
        Makkah: {
            name: 'Umm Al-Qura University, Makkah',
            fajr: 18.5,
            isha: '90 min'
        }
    };

    this.methodNames = ['MWL', 'ISNA', 'Egypt', 'Turkey', 'Makkah'];
    this.defaultMethod = method !== undefined ? this.methodNames[method] : 'Turkey';
    this.calcMethod = this.methods[this.defaultMethod];

    // Time Names
    this.timeNames = {
        imsak    : 'İmsak',
        fajr     : 'Sabah',
        sunrise  : 'Güneş',
        dhuhr    : 'Öğle',
        asr      : 'İkindi',
        sunset   : 'Akşam',
        maghrib  : 'Akşam',
        isha     : 'Yatsı',
        midnight : 'Gece Yarısı'
    };

    this.settings = {
        imsak    : '10 min',
        dhuhr    : '0 min',
        asr      : 'Standard',
        highLats : 'NightMiddle'
    };

    this.offset = {};
    this.offset.imsak = 0;
    this.offset.fajr = 0;
    this.offset.sunrise = 0;
    this.offset.dhuhr = 0;
    this.offset.asr = 0;
    this.offset.sunset = 0;
    this.offset.maghrib = 0;
    this.offset.isha = 0;
    this.offset.midnight = 0;
}

PrayerTimes.prototype = {

    getTimes: function(date, coords, timezone, dst) {
        this.lat = coords[0];
        this.lng = coords[1];
        this.elv = coords[2] ? coords[2] : 0;
        this.timeZone = timezone !== undefined ? timezone : this.getTimeZone(date);
        this.jDate = this.julian(date.getFullYear(), date.getMonth() + 1, date.getDate()) - this.lng / (15 * 24);

        return this.computeTimes();
    },

    julian: function(year, month, day) {
        if (month <= 2) {
            year -= 1;
            month += 12;
        }
        var A = Math.floor(year / 100);
        var B = 2 - A + Math.floor(A / 4);
        var JD = Math.floor(365.25 * (year + 4716)) + Math.floor(30.6001 * (month + 1)) + day + B - 1524.5;
        return JD;
    },

    computeTimes: function() {
        var times = {
            imsak: 5, fajr: 5, sunrise: 6, dhuhr: 12,
            asr: 13, sunset: 18, maghrib: 18, isha: 18
        };

        for (var i = 1; i <= 2; i++)
            times = this.computePrayerTimes(times);

        times = this.adjustTimes(times);
        return this.tuneTimes(times);
    },

    computePrayerTimes: function(times) {
        times = this.dayPortion(times);
        var params = this.calcMethod;

        var imsak   = this.sunAngleTime(this.eval(this.settings.imsak), times.imsak, 'ccw');
        var fajr    = this.sunAngleTime(params.fajr, times.fajr, 'ccw');
        var sunrise = this.sunAngleTime(this.riseSetAngle(), times.sunrise, 'ccw');
        var dhuhr   = this.midDay(times.dhuhr);
        var asr     = this.asrTime(this.asrFactor(this.settings.asr), times.asr);
        var sunset  = this.sunAngleTime(this.riseSetAngle(), times.sunset);;
        var maghrib = this.sunAngleTime(params.maghrib, times.maghrib);
        var isha    = this.sunAngleTime(params.isha, times.isha);

        return {
            imsak: imsak, fajr: fajr, sunrise: sunrise, dhuhr: dhuhr,
            asr: asr, sunset: sunset, maghrib: maghrib, isha: isha
        };
    },

    adjustTimes: function(times) {
        var params = this.calcMethod;

        for (var t in times)
            times[t] += this.timeZone - this.lng / 15;

        if (params.midnight !== undefined && params.midnight == 'Jafari')
            times.midnight = times.sunset + this.timeDiff(times.sunset, times.fajr) / 2;
        else
            times.midnight = times.sunset + this.timeDiff(times.sunset, times.sunrise) / 2;

        times.imsak = times.fajr - this.eval(this.settings.imsak) / 60;
        times.maghrib = times.sunset + this.eval(params.maghrib) / 60;
        if (typeof params.isha === 'string')
            times.isha = times.sunset + this.eval(params.isha) / 60;
        times.dhuhr += this.eval(this.settings.dhuhr) / 60;

        return times;
    },

    asrFactor: function(asrParam) {
        var factor = {Standard: 1, Hanafi: 2}[asrParam];
        return factor || this.eval(asrParam);
    },

    riseSetAngle: function() {
        var earthRad = 6371009;
        var angle = DMath.arccos(earthRad / (earthRad + this.elv));
        return 0.833 + angle;
    },

    tuneTimes: function(times) {
        for (var i in times)
            times[i] = times[i] + this.offset[i] / 60;
        return times;
    },

    midDay: function(time) {
        var eqt = this.sunPosition(this.jDate + time).equation;
        var noon = DMath.fixHour(12 - eqt);
        return noon;
    },

    sunAngleTime: function(angle, time, direction) {
        var decl = this.sunPosition(this.jDate + time).declination;
        var noon = this.midDay(time);
        var t = 1/15 * DMath.arccos((-DMath.sin(angle) - DMath.sin(decl) * DMath.sin(this.lat)) /
                (DMath.cos(decl) * DMath.cos(this.lat)));
        return noon + (direction == 'ccw' ? -t : t);
    },

    asrTime: function(factor, time) {
        var decl = this.sunPosition(this.jDate + time).declination;
        var angle = -DMath.arccot(factor + DMath.tan(Math.abs(this.lat - decl)));
        return this.sunAngleTime(angle, time);
    },

    sunPosition: function(jd) {
        var D = jd - 2451545.0;
        var g = DMath.fixAngle(357.529 + 0.98560028 * D);
        var q = DMath.fixAngle(280.459 + 0.98564736 * D);
        var L = DMath.fixAngle(q + 1.915 * DMath.sin(g) + 0.020 * DMath.sin(2*g));

        var R = 1.00014 - 0.01671 * DMath.cos(g) - 0.00014 * DMath.cos(2*g);
        var e = 23.439 - 0.00000036 * D;

        var RA = DMath.arctan2(DMath.cos(e) * DMath.sin(L), DMath.cos(L)) / 15;
        var eqt = q/15 - DMath.fixHour(RA);
        var decl = DMath.arcsin(DMath.sin(e) * DMath.sin(L));

        return {declination: decl, equation: eqt};
    },

    dayPortion: function(times) {
        for (var i in times)
            times[i] /= 24;
        return times;
    },

    timeDiff: function(time1, time2) {
        return DMath.fixHour(time2 - time1);
    },

    getTimeZone: function(date) {
        var year = date.getFullYear();
        var t1 = new Date(year, 0, 1).getTimezoneOffset();
        var t2 = new Date(year, 6, 1).getTimezoneOffset();
        return Math.max(t1, t2) / -60;
    },

    eval: function(str) {
        return 1 * (str + '').split(/[^0-9.+-]/)[0];
    }
};

function calculate(latitude, longitude, timezone, method) {
    var pt = new PrayerTimes(method);
    var date = new Date();
    var times = pt.getTimes(date, [latitude, longitude], timezone);

    var result = {};
    for (var t in times) {
        if (t !== 'sunset' && t !== 'sunrise' && t !== 'midnight') {
            result[t] = formatTime(times[t]);
        }
    }
    result.sunrise = formatTime(times.sunrise);

    return result;
}

function formatTime(time) {
    if (isNaN(time))
        return '---';

    time = DMath.fixHour(time + 0.5 / 60);
    var hours = Math.floor(time);
    var minutes = Math.floor((time - hours) * 60);

    return ('0' + hours).slice(-2) + ':' + ('0' + minutes).slice(-2);
}

function getNextPrayer(times) {
    var now = new Date();
    var currentMinutes = now.getHours() * 60 + now.getMinutes();

    var prayerOrder = ['imsak', 'fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
    var prayerNames = {
        imsak: 'İmsak',
        fajr: 'Sabah',
        sunrise: 'Güneş',
        dhuhr: 'Öğle',
        asr: 'İkindi',
        maghrib: 'Akşam',
        isha: 'Yatsı'
    };

    for (var i = 0; i < prayerOrder.length; i++) {
        var prayer = prayerOrder[i];
        if (times[prayer]) {
            var parts = times[prayer].split(':');
            var prayerMinutes = parseInt(parts[0]) * 60 + parseInt(parts[1]);

            if (currentMinutes < prayerMinutes) {
                var diff = prayerMinutes - currentMinutes;
                var hours = Math.floor(diff / 60);
                var mins = diff % 60;
                return {
                    name: prayerNames[prayer],
                    time: times[prayer],
                    remaining: hours + ' saat ' + mins + ' dakika'
                };
            }
        }
    }

    // If no prayer found today, return tomorrow's Imsak
    return {
        name: 'İmsak',
        time: times.imsak,
        remaining: 'Yarın'
    };
}
