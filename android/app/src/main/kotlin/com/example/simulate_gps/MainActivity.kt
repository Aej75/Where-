package com.example.simulate_gps

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.simulate_gps/mock_location"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "startMockLocation") {
                val lat = call.argument<Double>("lat")
                val lon = call.argument<Double>("lon")
                if (lat != null && lon != null) {
                    val intent = Intent(this, MockLocationService::class.java)
                    intent.putExtra("lat", lat)
                    intent.putExtra("lon", lon)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENTS", "Invalid latitude or longitude", null)
                }
            } else if (call.method == "stopMockLocation") {
                val intent = Intent(this, MockLocationService::class.java)
                stopService(intent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
