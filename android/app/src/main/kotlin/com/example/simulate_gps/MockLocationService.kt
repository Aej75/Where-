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

class MockLocationService : Service() {

    private lateinit var locationManager: LocationManager
    private var timer: Timer? = null
    private var lat: Double = 0.0
    private var lon: Double = 0.0

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
        lat = intent?.getDoubleExtra("lat", 0.0) ?: 0.0
        lon = intent?.getDoubleExtra("lon", 0.0) ?: 0.0

        startForeground(1, createNotification())

        timer?.cancel()
        timer = Timer()
        timer?.schedule(object : TimerTask() {
            override fun run() {
                val mockLocation = Location(LocationManager.GPS_PROVIDER)
                mockLocation.latitude = lat
                mockLocation.longitude = lon
                mockLocation.altitude = 0.0
                mockLocation.accuracy = 5.0f
                mockLocation.time = System.currentTimeMillis()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                    mockLocation.elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
                }

                try {
                    locationManager.setTestProviderLocation(LocationManager.GPS_PROVIDER, mockLocation)
                } catch (e: SecurityException) {
                    // Stop the timer if we lose permission
                    timer?.cancel()
                    stopSelf()
                }
            }
        }, 0, 1000)

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
            .setContentTitle("Simulating Location")
            .setContentText("Your location is being simulated.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()
    }
}
