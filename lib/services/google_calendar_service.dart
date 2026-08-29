import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';

import '../models/lifestyle_entry.dart';

/// Creates a calendar event only after the user explicitly opts in per task.
class GoogleCalendarService {
  static const _calendarEventsScope =
      'https://www.googleapis.com/auth/calendar.events';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const [_calendarEventsScope],
  );

  Future<GoogleSignInAccount> _calendarAccount({
    bool interactive = false,
  }) async {
    final account = interactive
        ? await _googleSignIn.signIn()
        : await _googleSignIn.signInSilently();
    if (account == null) {
      throw const GoogleCalendarException(
        'Reconnect Google Calendar and grant calendar permission.',
      );
    }
    final granted = await _googleSignIn.requestScopes(const [
      _calendarEventsScope,
    ]);
    if (!granted) {
      throw const GoogleCalendarException(
        'Calendar permission was not granted. Allow it in the Google prompt and try again.',
      );
    }
    return account;
  }

  Future<String> addTask(PlannerEntry task) async {
    final account = await _calendarAccount(interactive: true);

    final headers = await account.authHeaders;
    final start = DateTime(
      task.date.year,
      task.date.month,
      task.date.day,
    ).add(Duration(minutes: task.timeMinutes));
    final end = start.add(const Duration(hours: 1));
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.postUrl(
        Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/primary/events',
        ),
      );
      headers.forEach(request.headers.set);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'summary': task.title,
          'description':
              'Added by LifeLens • ${task.priority.name} priority • workload ${task.workload}/5',
          'start': {'dateTime': _rfc3339(start)},
          'end': {'dateTime': _rfc3339(end)},
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GoogleCalendarException(
          'Google Calendar rejected this task (${response.statusCode}): ${_googleMessage(body)}',
        );
      }
      final eventId =
          (jsonDecode(body) as Map<String, dynamic>)['id'] as String?;
      if (eventId == null || eventId.isEmpty) {
        throw const GoogleCalendarException(
          'Google Calendar did not return an event ID.',
        );
      }
      return eventId;
    } on SocketException {
      throw const GoogleCalendarException(
        'An internet connection is required to add a calendar event.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final account = await _calendarAccount();
    final headers = await account.authHeaders;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.deleteUrl(
        Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId',
        ),
      );
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      if (response.statusCode != HttpStatus.noContent &&
          response.statusCode != HttpStatus.notFound) {
        throw const GoogleCalendarException(
          'Google Calendar could not remove the linked event.',
        );
      }
    } on SocketException {
      throw const GoogleCalendarException(
        'An internet connection is required to remove a calendar event.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> updateTaskCompletion(PlannerEntry task) async {
    final eventId = task.googleCalendarEventId;
    if (eventId == null) return;
    final account = await _calendarAccount();
    final headers = await account.authHeaders;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.patchUrl(
        Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId',
        ),
      );
      headers.forEach(request.headers.set);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'summary': task.isCompleted ? '✓ ${task.title}' : task.title,
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const GoogleCalendarException(
          'Google Calendar could not update the linked event.',
        );
      }
    } on SocketException {
      throw const GoogleCalendarException(
        'An internet connection is required to update a calendar event.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> updateTask(PlannerEntry task) async {
    final eventId = task.googleCalendarEventId;
    if (eventId == null) return;
    final account = await _calendarAccount();
    final start = DateTime(
      task.date.year,
      task.date.month,
      task.date.day,
    ).add(Duration(minutes: task.timeMinutes));
    final headers = await account.authHeaders;
    final client = HttpClient();
    try {
      final request = await client.patchUrl(
        Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId',
        ),
      );
      headers.forEach(request.headers.set);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'summary': task.title,
          'description':
              'Added by LifeLens • ${task.priority.name} priority • workload ${task.workload}/5',
          'start': {'dateTime': _rfc3339(start)},
          'end': {'dateTime': _rfc3339(start.add(const Duration(hours: 1)))},
        }),
      );
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw const GoogleCalendarException(
          'Google Calendar could not update the linked event.',
        );
    } finally {
      client.close(force: true);
    }
  }

  String _googleMessage(String body) {
    try {
      final error = (jsonDecode(body) as Map<String, dynamic>)['error'];
      final message = error is Map<String, dynamic> ? error['message'] : null;
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}
    return 'check the Calendar API and OAuth scope in Google Cloud.';
  }

  /// Google Calendar requires RFC3339 with a timezone offset. Dart's local
  /// DateTime.toIso8601String() has no offset, which Calendar rejects (400).
  String _rfc3339(DateTime value) {
    final offset = value.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final local = value.toIso8601String();
    return '$local$sign$hours:$minutes';
  }
}

class GoogleCalendarException implements Exception {
  const GoogleCalendarException(this.message);
  final String message;
  @override
  String toString() => message;
}
