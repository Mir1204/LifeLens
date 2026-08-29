import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'app/lifelens_app.dart';
import 'services/background_sync_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  await Workmanager().initialize(lifeLensBackgroundDispatcher);
  await BackgroundSyncService().schedule();
  runApp(const LifeLensApp());
}
