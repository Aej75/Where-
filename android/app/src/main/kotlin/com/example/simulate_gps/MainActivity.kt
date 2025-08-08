package com.example.simulate_gps

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.simulate_gps.LatLng

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.simulate_gps/mock_location"

    override fun shouldDestroyEngineWithHost(): Boolean {
        return false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "startMockLocation") {
                val waypoints = call.argument<List<Map<String, Double>>>("waypoints")
                val loop = call.argument<Boolean>("loop")
                val reverseLoop = call.argument<Boolean>("reverseLoop")
                val interval = call.argument<Int>("interval")
                val speed = call.argument<Double>("speed")

                if (waypoints != null && loop != null && reverseLoop != null && interval != null && speed != null) {
                    val intent = Intent(this, MockLocationService::class.java)
                    intent.putExtra("waypoints", ArrayList(waypoints.map { LatLng(it["lat"]!!, it["lon"]!!) }))
                    intent.putExtra("loop", loop)
                    intent.putExtra("reverseLoop", reverseLoop)
                    intent.putExtra("interval", interval)
                    intent.putExtra("speed", speed)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing arguments", null)
                }
            } else if (call.method == "pauseMockLocation") {
                val intent = Intent(this, MockLocationService::class.java)
                intent.action = "PAUSE"
                startService(intent)
                result.success(null)
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