package com.example.simulate_gps

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import java.util.Timer
import java.util.TimerTask
import kotlin.math.*

class MockLocationService : Service() {

    private lateinit var locationManager: LocationManager
    private var timer: Timer? = null
    private var startLat: Double = 0.0
    private var startLon: Double = 0.0
    private var endLat: Double = 0.0
    private var endLon: Double = 0.0
    private var speed: Double = 0.0 // meters per second
    private var currentStep: Long = 0
    private var totalSteps: Long = 0

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        try {
            locationManager.addTestProvider(
                LocationManager.GPS_PROVIDER,
                false,
                false,
                false,
                false,
                true,
                true,
                true,
                1,
                1
            )
            locationManager.setTestProviderEnabled(LocationManager.GPS_PROVIDER, true)
        } catch (e: SecurityException) {
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startLat = intent?.getDoubleExtra("startLat", 0.0) ?: 0.0
        startLon = intent?.getDoubleExtra("startLon", 0.0) ?: 0.0
        endLat = intent?.getDoubleExtra("endLat", 0.0) ?: 0.0
        endLon = intent?.getDoubleExtra("endLon", 0.0) ?: 0.0
        speed = intent?.getDoubleExtra("speed", 1.0) ?: 1.0 // Default speed 1 m/s

        startForeground(1, createNotification())

        timer?.cancel()
        timer = Timer()
        currentStep = 0

        val distance = calculateDistance(startLat, startLon, endLat, endLon)
        totalSteps = (distance / speed * 1000 / 1000).toLong() // Convert to seconds, then to steps (1 step per second)
        if (totalSteps == 0L) totalSteps = 1L // Avoid division by zero if start and end are same

        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                if (currentStep <= totalSteps) {
                    val fraction = currentStep.toDouble() / totalSteps.toDouble()
                    val interpolatedLat = startLat + (endLat - startLat) * fraction
                    val interpolatedLon = startLon + (endLon - startLon) * fraction

                    val mockLocation = Location(LocationManager.GPS_PROVIDER)
                    mockLocation.latitude = interpolatedLat
                    mockLocation.longitude = interpolatedLon
                    mockLocation.altitude = 0.0
                    mockLocation.accuracy = 5.0f
                    mockLocation.time = System.currentTimeMillis()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                        mockLocation.elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
                    }

                    try {
                        locationManager.setTestProviderLocation(LocationManager.GPS_PROVIDER, mockLocation)
                    } catch (e: SecurityException) {
                        timer?.cancel()
                        stopSelf()
                    }
                    currentStep++
                } else {
                    // Reached end, stop simulation or loop
                    timer?.cancel()
                    stopSelf()
                }
            }
        }, 0, 1000) // Update every 1 second

        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        timer?.cancel()
        try {
            locationManager.removeTestProvider(LocationManager.GPS_PROVIDER)
        } catch (e: SecurityException) {
            // Ignore
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "mock_location_service",
                "Mock Location Service",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, "mock_location_service")
            .setContentTitle("Simulating Movement")
            .setContentText("Your location is being simulated along a path.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()
    }

    // Haversine formula to calculate distance between two lat/lon points in meters
    private fun calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val R = 6371e3 // metres
        val phi1 = Math.toRadians(lat1)
        val phi2 = Math.toRadians(lat2)
        val deltaPhi = Math.toRadians(lat2 - lat1)
        val deltaLambda = Math.toRadians(lon2 - lon1)

        val a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
                cos(phi1) * cos(phi2) *
                sin(deltaLambda / 2) * sin(deltaLambda / 2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return R * c
    }
}