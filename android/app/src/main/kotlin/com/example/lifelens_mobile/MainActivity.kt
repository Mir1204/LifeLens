package com.example.lifelens_mobile

import android.content.Intent
import android.app.AppOpsManager
import android.content.Context
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Health Connect uses Android's Activity Result API for its permission dialog.
// FlutterFragmentActivity provides the required ComponentActivity support.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "lifelens/device_settings"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUsageAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "hasUsageAccess" -> {
                    val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                    val mode = appOps.checkOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        android.os.Process.myUid(),
                        packageName
                    )
                    result.success(mode == AppOpsManager.MODE_ALLOWED)
                }
                "resolveAppLabels" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    val labels = packages.associateWith { packageName ->
                        try {
                            packageManager.getApplicationLabel(
                                packageManager.getApplicationInfo(packageName, 0)
                            ).toString()
                        } catch (_: Exception) {
                            packageName.substringAfterLast('.').replaceFirstChar { it.uppercase() }
                        }
                    }
                    result.success(labels)
                }
                else -> result.notImplemented()
            }
        }
    }
}
