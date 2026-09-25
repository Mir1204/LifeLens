import 'package:flutter/foundation.dart';

import 'local_database_service.dart';

/// Stores only a short error category locally; never stacks, tokens, notes, or
/// health values. It gives the UI a friendly recovery hint without exporting PII.
class ErrorReportingService {
  Future<void> capture(Object error) async {
    final type = error.runtimeType.toString();
    debugPrint('LifeLens recoverable error: $type');
    await LocalDatabaseService().saveSetting('last_safe_error', type);
  }
}
