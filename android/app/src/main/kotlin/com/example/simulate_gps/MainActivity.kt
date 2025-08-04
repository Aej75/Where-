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
                val startLat = call.argument<Double>("startLat")
                val startLon = call.argument<Double>("startLon")
                val endLat = call.argument<Double>("endLat")
                val endLon = call.argument<Double>("endLon")
                val speed = call.argument<Double>("speed")

                if (startLat != null && startLon != null && endLat != null && endLon != null && speed != null) {
                    val intent = Intent(this, MockLocationService::class.java)
                    intent.putExtra("startLat", startLat)
                    intent.putExtra("startLon", startLon)
                    intent.putExtra("endLat", endLat)
                    intent.putExtra("endLon", endLon)
                    intent.putExtra("speed", speed)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing latitude, longitude or speed arguments", null)
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
