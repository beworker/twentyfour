using Toybox.Lang;
using Toybox.System;
using Toybox.Time;

module Ring {

	class Event {
		enum {
			TYPE_NOW,
			TYPE_SUNRISE,
			TYPE_SOLAR_NOON,
			TYPE_SUNSET,
			TYPE_MIDNIGHT
		}
	
		enum {
			ARC_PASSED,
			ARC_DAY,
			ARC_NIGHT
		} 
	
		private var moment;
		private var type;
		private var arcType;
		private var momentInfo;
		
		function initialize(moment, type, arcType) {
			self.moment = moment;
			self.type = type;
			self.arcType = arcType;
		}
		
		function getMoment() {
			return self.moment;
		}
		
		function getType() {
			return self.type;
		}
		
		function getArcType() {
			return self.arcType;
		}

		function getMomentInfo() {
			if (self.momentInfo == null) {
				self.momentInfo = Time.Gregorian.info(moment, Time.FORMAT_SHORT);
			}
			return self.momentInfo;
		}
		
		function toString() {
			return formatType(self.type) 
				+ ", moment: " + formatMoment(self.moment) + " (" + self.moment.value() + ")"
				+ ", arc: " + formatArcType(self.arcType);
		}
		
		static function formatType(type) {
			switch(type) {
				case TYPE_NOW: return "now";
				case TYPE_SUNRISE: return "sunrise";
				case TYPE_SOLAR_NOON: return "solar noon";
				case TYPE_SUNSET: return "sunset";
				case TYPE_MIDNIGHT: return "midnight";
				default: return "Unknown(" + type + ")";
			}
		}
		
		static function formatArcType(type) {
			switch(type) {
				case ARC_PASSED: return "passed";
				case ARC_DAY: return "day";
				case ARC_NIGHT: return "night";
				default: return "Unknown(" + type + ")";
			}
		}
	}
	
	class Events {
		private var events;
		private var sec, lat, lng;
	
		function initialize(events, sec, lat, lng) {
			self.events = events;
			self.sec = sec;
			self.lat = lat;
			self.lng = lng;
		}
		
		function get(index) {
			return events[index];
		}
		
		function getNowIndex() {
			for (var i = 0; i < events.size(); i++) {
				if (events[i].getType() == Ring.Event.TYPE_NOW) {
					return i;
				} 
			}
			return -1;
		}
		
		function getNextEventIndexAfter(index) {
			var index1 = (index + 1) % events.size();
			var event1 = events[index1];
			if (event1.getType() == Ring.Event.TYPE_NOW
				|| event1.getType() == Ring.Event.TYPE_MIDNIGHT) {
				return -1;
			}

			var event = events[index];
			if (event.getMoment().greaterThan(event1.getMoment())) {
				return -1; 
			}
			
			return index1;
		}
		
		function size() {
			if (events == null) {
				return 0;
			} else {
				return events.size();
			}
		}
		
		function isOutdated(now, lat, lng) {
			return (now.value() - self.sec).abs() > 60 || self.lat != lat || self.lng != lng;
		}
		
		private static function isPolarDay(moment, lat) {
			var north = lat > 0;
			var info = Time.Gregorian.info(moment, Time.FORMAT_SHORT);
			var summer = info.month > 4 && info.month < 10;
			return (north && summer) || (!north && !summer);
		}
		
		static function create(now, today, lat, lng) {
			
			var times = sunCalc.getTimes(today, lat, lng, 0);
			var noon = times[:solarNoon];
			var sunrise = times[:sunrise];
			var sunset = times[:sunset];
			
			var events = new List(5);
			if (sunrise == null || sunset == null) {
				if (isPolarDay(now, lat)) {
					if (DEBUG) {
						System.println("polar day");
					}
					events.add(new Event(today, Event.TYPE_MIDNIGHT, Event.ARC_DAY));
					events.add(new Event(now, Event.TYPE_NOW, Event.ARC_DAY));
					
				} else {
					if (DEBUG) {
						System.println("polar night");
					}
					events.add(new Event(today, Event.TYPE_MIDNIGHT, Event.ARC_NIGHT));
					events.add(new Event(now, Event.TYPE_NOW, Event.ARC_NIGHT));
				}
				
			} else if (now.lessThan(noon)) { // before noon 
				if (now.lessThan(sunrise)) {
					if (DEBUG) {
						System.println("before sunrise");
					}
					events.add(new Event(today, Event.TYPE_MIDNIGHT, Event.ARC_PASSED));
					events.add(new Event(now, Event.TYPE_NOW, Event.ARC_NIGHT));
					events.add(new Event(sunrise, Event.TYPE_SUNRISE, Event.ARC_DAY));
					events.add(new Event(noon, Event.TYPE_SOLAR_NOON, Event.ARC_DAY));
					events.add(new Event(sunset, Event.TYPE_SUNSET, Event.ARC_PASSED));
					
				} else {
					if (DEBUG) {
						System.println("after sunrise");
					}
					events.add(new Event(today, Event.TYPE_MIDNIGHT, Event.ARC_PASSED));
					events.add(new Event(sunrise, Event.TYPE_SUNRISE, Event.ARC_PASSED));
					events.add(new Event(now, Event.TYPE_NOW, Event.ARC_DAY));
					events.add(new Event(noon, Event.TYPE_SOLAR_NOON, Event.ARC_DAY));
					events.add(new Event(sunset, Event.TYPE_SUNSET, Event.ARC_NIGHT));
				}
				
			} else { // after noon
				var tomorrow = today.add(ONE_DAY);
				if (now.lessThan(sunset)) {
					if (DEBUG) {
						System.println("before sunset");
					}
					events.add(new Event(tomorrow, Event.TYPE_MIDNIGHT, Event.ARC_PASSED));
					events.add(new Event(sunrise, Event.TYPE_SUNRISE, Event.ARC_PASSED));
					events.add(new Event(noon, Event.TYPE_SOLAR_NOON, Event.ARC_PASSED));
					events.add(new Event(now, Event.TYPE_NOW, Event.ARC_DAY));
					events.add(new Event(sunset, Event.TYPE_SUNSET, Event.ARC_NIGHT));
				
				} else { 
					if (DEBUG) {
						System.println("after sunset");
					}
				
					var tomorrowTimes = sunCalc.getTimes(tomorrow, lat, lng, 0);
					var tomorrowSunrise = tomorrowTimes[:sunrise];
			
					if (tomorrowSunrise == null) {
						if (isPolarDay(tomorrow, lat)) {
							if (DEBUG) {
								System.println("going into polar day");
							}
							events.add(new Event(tomorrow, Event.TYPE_MIDNIGHT, Event.ARC_DAY));
							
						} else {
							if (DEBUG) {
								System.println("going into polar night");
							}
							events.add(new Event(tomorrow, Event.TYPE_MIDNIGHT, Event.ARC_NIGHT));
						}
						events.add(new Event(noon, Event.TYPE_SOLAR_NOON, Event.ARC_PASSED));
						events.add(new Event(sunset, Event.TYPE_SUNSET, Event.ARC_PASSED));
						events.add(new Event(now, Event.TYPE_NOW, Event.ARC_NIGHT));
						
					} else {
						events.add(new Event(tomorrow, Event.TYPE_MIDNIGHT, Event.ARC_NIGHT));
						events.add(new Event(tomorrowSunrise, Event.TYPE_SUNRISE, Event.ARC_PASSED));
						events.add(new Event(noon, Event.TYPE_SOLAR_NOON, Event.ARC_PASSED));
						events.add(new Event(sunset, Event.TYPE_SUNSET, Event.ARC_PASSED));
						events.add(new Event(now, Event.TYPE_NOW, Event.ARC_NIGHT));
					}
				}
			}
			
			return new Ring.Events(events.toArray(), now.value(), lat, lng);
		}
		
		private static const ONE_DAY = new Time.Duration(Time.Gregorian.SECONDS_PER_DAY);
		private static const THREE_HOURS = new Time.Duration(3 * Time.Gregorian.SECONDS_PER_HOUR);
		
		private static const comparator = new Comparator();
		private static const sunCalc = new SunCalc();
		private static const DEBUG = false;
	}
	
	class EmptyEvents {
		function size() {
			return 0;
		}
		
		function isOutdated(now, lat, lng) {
			return true;
		}
	}

	class Comparator {
		function compareEvents(event1, event2) {
			return event1[:moment].value() - event2[:moment].value();
		}
	}
	
	function formatMoment(moment) {
    	if (moment == null) {
    		return "null";
    	}
        var info = Time.Gregorian.info(moment, Time.FORMAT_SHORT);
        return info.day.format("%02d") + "." + info.month.format("%02d") + "." + info.year.toString() + " " + 
        	info.hour.format("%02d") + ":" + info.min.format("%02d") + ":" + info.sec.format("%02d");
	}
	
	(:debug, :test)
	static function create_0to3(log) {

		var today = new Time.Moment(1598911200);
		var now = today.add(new Time.Duration(Time.Gregorian.SECONDS_PER_HOUR * 2));
		var lat = 49.458914, lng = 8.563376;
		
		log.debug("today: " + Ring.formatMoment(today));
		log.debug("now: " + Ring.formatMoment(now));
		log.debug("---");

		var expected = [
			"sunset, moment: 31.08.2020 20:13:04 (1598897584), arc: passed",
			"midnight, moment: 01.09.2020 00:00:00 (1598911200), arc: passed",
			"now, moment: 01.09.2020 02:00:00 (1598918400), arc: night",
			"sunrise, moment: 01.09.2020 06:43:24 (1598935404), arc: day",
			"solar noon, moment: 01.09.2020 13:27:11 (1598959631), arc: day"
		];

		var events = Ring.Events.create(now, today, lat, lng);
		for (var i = 0; i < events.size(); i++) {
			var event = events.get(i);
			log.debug(event.toString());
			if (!event.toString().equals(expected[i])) {
				log.error("Expected: " + expected[i] + ", actual: " + event.toString());
				return false;
			}
		}
	
		return true;
	}
	
	(:debug, :test)
	static function create_21to24(log) {

		var today = new Time.Moment(1598911200);
		var now = today.add(new Time.Duration(Time.Gregorian.SECONDS_PER_HOUR * 22));
		var lat = 49.458914, lng = 8.563376;
		
		log.debug("today: " + Ring.formatMoment(today));
		log.debug("now: " + Ring.formatMoment(now));
		log.debug("---");

		var expected = [
			"solar noon, moment: 01.09.2020 13:27:11 (1598959631), arc: passed",
			"sunset, moment: 01.09.2020 20:10:59 (1598983859), arc: passed",
			"now, moment: 01.09.2020 22:00:00 (1598990400), arc: night",
			"midnight, moment: 02.09.2020 00:00:00 (1598997600), arc: night",
			"sunrise, moment: 02.09.2020 06:44:51 (1599021891), arc: day"
		];

		var events = Ring.Events.create(now, today, lat, lng);
		for (var i = 0; i < events.size(); i++) {
			var event = events.get(i);
			log.debug(event.toString());
			if (!event.toString().equals(expected[i])) {
				log.error("Expected: " + expected[i] + ", actual: " + event.toString());
				return false;
			}
		}
	
		return true;
	}
	
	(:debug, :test)
	static function create_3to21_before_sunrise(log) {

		var today = new Time.Moment(1598911200);
		var now = today.add(new Time.Duration(Time.Gregorian.SECONDS_PER_HOUR * 6));
		var lat = 49.458914, lng = 8.563376;
		
		log.debug("today: " + Ring.formatMoment(today));
		log.debug("now: " + Ring.formatMoment(now));
		log.debug("---");

		var expected = [
			"midnight, moment: 01.09.2020 00:00:00 (1598911200), arc: passed",
			"now, moment: 01.09.2020 06:00:00 (1598932800), arc: night",
			"sunrise, moment: 01.09.2020 06:43:24 (1598935404), arc: day",
			"solar noon, moment: 01.09.2020 13:27:11 (1598959631), arc: day",
			"sunset, moment: 01.09.2020 20:10:59 (1598983859), arc: night"
		];

		var events = Ring.Events.create(now, today, lat, lng);
		for (var i = 0; i < events.size(); i++) {
			var event = events.get(i);
			log.debug(event.toString());
			if (!event.toString().equals(expected[i])) {
				log.error("Expected: " + expected[i] + ", actual: " + event.toString());
				return false;
			}
		}
	
		return true;
	}
	
	(:debug, :test)
	static function create_3to21_before_solar_noon(log) {

		var today = new Time.Moment(1598911200);
		var now = today.add(new Time.Duration(Time.Gregorian.SECONDS_PER_HOUR * 10));
		var lat = 49.458914, lng = 8.563376;
		
		log.debug("today: " + Ring.formatMoment(today));
		log.debug("now: " + Ring.formatMoment(now));
		log.debug("---");

		var expected = [
			"midnight, moment: 01.09.2020 00:00:00 (1598911200), arc: passed",
			"sunrise, moment: 01.09.2020 06:43:24 (1598935404), arc: passed",
			"now, moment: 01.09.2020 10:00:00 (1598947200), arc: day",
			"solar noon, moment: 01.09.2020 13:27:11 (1598959631), arc: day",
			"sunset, moment: 01.09.2020 20:10:59 (1598983859), arc: night"
		];

		var events = Ring.Events.create(now, today, lat, lng);
		for (var i = 0; i < events.size(); i++) {
			var event = events.get(i);
			log.debug(event.toString());
			if (!event.toString().equals(expected[i])) {
				log.error("Expected: " + expected[i] + ", actual: " + event.toString());
				return false;
			}
		}
	
		return true;
	}
	
	(:debug, :test)
	static function create_3to21_before_sunset(log) {

		var today = new Time.Moment(1598911200);
		var now = today.add(new Time.Duration(Time.Gregorian.SECONDS_PER_HOUR * 19));
		var lat = 49.458914, lng = 8.563376;
		
		log.debug("today: " + Ring.formatMoment(today));
		log.debug("now: " + Ring.formatMoment(now));
		log.debug("---");

		var expected = [
			"midnight, moment: 01.09.2020 00:00:00 (1598911200), arc: passed",
			"sunrise, moment: 01.09.2020 06:43:24 (1598935404), arc: passed",
			"solar noon, moment: 01.09.2020 13:27:11 (1598959631), arc: passed",
			"now, moment: 01.09.2020 19:00:00 (1598979600), arc: day",
			"sunset, moment: 01.09.2020 20:10:59 (1598983859), arc: night"
		];

		var events = Ring.Events.create(now, today, lat, lng);
		for (var i = 0; i < events.size(); i++) {
			var event = events.get(i);
			log.debug(event.toString());
			if (!event.toString().equals(expected[i])) {
				log.error("Expected: " + expected[i] + ", actual: " + event.toString());
				return false;
			}
		}
	
		return true;
	}	
}
