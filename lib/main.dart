import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'app/lifelens_app.dart';
import 'services/background_sync_service.dart';
import 'services/notification_service.dart';
import 'services/error_reporting_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReportingService().capture(details.exception);
  };
  PlatformDispatcher.instance.onError = (error, _) {
    ErrorReportingService().capture(error);
    return false;
  };
  ErrorWidget.builder = (_) => const Material(
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Something went wrong. Please return to the previous screen and try again.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
  // main() is also used by WorkManager's headless engine. Never request a
  // runtime permission here because that engine has no Android Activity.
  await NotificationService.initialize(requestPermission: false);
  await Workmanager().initialize(lifeLensBackgroundDispatcher);
  await BackgroundSyncService().schedule();
  runApp(const LifeLensApp());
}
