import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'app/lifelens_app.dart';
import 'services/background_sync_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // main() is also used by WorkManager's headless engine. Never request a
  // runtime permission here because that engine has no Android Activity.
  await NotificationService.initialize(requestPermission: false);
  await Workmanager().initialize(lifeLensBackgroundDispatcher);
  await BackgroundSyncService().schedule();
  runApp(const LifeLensApp());
}
