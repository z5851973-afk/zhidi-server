package com.zhidi.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/flavor")
            .setMethodCallHandler { call, result ->
                if (call.method == "getFlavor") {
                    val appId = applicationContext.packageName
                    result.success(if (appId.contains(".owner")) "owner" else "worker")
                } else {
                    result.notImplemented()
                }
            }
    }
}
