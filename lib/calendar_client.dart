import 'package:googleapis/calendar/v3.dart';

class CalendarClient {
  static CalendarApi? calendar;

  static Future<void> insert({
    required String title,
    required String description,
    required String location,
    required List<EventAttendee> attendeeEmailList,
    required bool shouldNotifyAttendees,
    required DateTime startTime,
    required DateTime endTime,
    required String categoryId
  }) async {
    String calendarId = categoryId;
    Event event = Event();

    event.summary = title;
    event.description = description;
    event.attendees = attendeeEmailList;
    event.location = location;

    EventDateTime start = EventDateTime();
    start.dateTime = startTime;
    start.timeZone = "GMT+09:00";
    event.start = start;

    EventDateTime end = EventDateTime();
    end.timeZone = "GMT+09:00";
    end.dateTime = endTime;
    event.end = end;

    await calendar?.events.insert(event, calendarId, sendUpdates: shouldNotifyAttendees ? "all" : "none");
  }
}