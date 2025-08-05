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
import com.example.simulate_gps.LatLng
import java.util.Timer
import java.util.TimerTask
import kotlin.math.*

class MockLocationService : Service() {

    private lateinit var locationManager: LocationManager
    private var timer: Timer? = null

    private var waypoints: MutableList<LatLng> = mutableListOf()
    private var loop: Boolean = false
    private var reverseLoop: Boolean = false
    private var intervalSeconds: Int = 0
    private var speed: Double = 0.0

    private var currentWaypointIndex: Int = 0
    private var simulationState: SimulationState = SimulationState.STOPPED
    private var waitingEndTime: Long = 0
    private var currentLat: Double = 0.0
    private var currentLon: Double = 0.0
    private var step: Long = 0
    private var durationSeconds: Long = 0

    private enum class SimulationState { MOVING, WAITING, PAUSED, STOPPED }

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        try {
            locationManager.addTestProvider(
                LocationManager.GPS_PROVIDER, false, false, false, false, true, true, true, 1, 1
            )
            locationManager.setTestProviderEnabled(LocationManager.GPS_PROVIDER, true)
        } catch (e: SecurityException) {
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "PAUSE" -> {
                simulationState = SimulationState.PAUSED
                return START_STICKY
            }
            "STOP" -> {
                stopSimulation()
                return START_NOT_STICKY
            }
        }

        val receivedWaypoints = intent?.getSerializableExtra("waypoints") as? List<LatLng>
        waypoints = receivedWaypoints?.toMutableList() ?: mutableListOf()
        loop = intent?.getBooleanExtra("loop", false) ?: false
        reverseLoop = intent?.getBooleanExtra("reverseLoop", false) ?: false
        intervalSeconds = intent?.getIntExtra("interval", 0) ?: 0
        speed = intent?.getDoubleExtra("speed", 5.0) ?: 5.0

        startForeground(1, createNotification())

        if (waypoints.isNotEmpty()) {
            startSimulation()
        } else {
            stopSelf()
        }

        return START_STICKY
    }

    private fun startSimulation() {
        timer?.cancel()
        timer = Timer()
        currentWaypointIndex = 0
        simulationState = SimulationState.MOVING
        prepareForMovement()

        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                if (simulationState == SimulationState.PAUSED || simulationState == SimulationState.STOPPED) {
                    return
                }
                updateLocation()
            }
        }, 0, 1000)
    }

    private fun stopSimulation() {
        simulationState = SimulationState.STOPPED
        timer?.cancel()
        stopSelf()
    }

    private fun prepareForMovement() {
        if (currentWaypointIndex >= waypoints.size) {
            handleEndOfPath()
            return
        }
        if (waypoints.size == 1) {
            val waypoint = waypoints[0]
            currentLat = waypoint.latitude
            currentLon = waypoint.longitude
            simulationState = SimulationState.WAITING
            waitingEndTime = Long.MAX_VALUE // Wait indefinitely
            return
        }

        if (currentWaypointIndex >= waypoints.size - 1) {
            // Should not happen if logic is correct, but as a safeguard
            handleEndOfPath()
            return
        }
        val start = waypoints[currentWaypointIndex]
        val end = waypoints[currentWaypointIndex + 1]
        val distance = calculateDistance(start.latitude, start.longitude, end.latitude, end.longitude)
        durationSeconds = (distance / speed).toLong().coerceAtLeast(1)
        step = 0
        simulationState = SimulationState.MOVING
    }

    private fun updateLocation() {
        when (simulationState) {
            SimulationState.MOVING -> {
                if (step <= durationSeconds) {
                    val start = waypoints[currentWaypointIndex]
                    val end = waypoints[currentWaypointIndex + 1]
                    val fraction = if (durationSeconds > 0) step.toDouble() / durationSeconds.toDouble() else 1.0
                    currentLat = start.latitude + (end.latitude - start.latitude) * fraction
                    currentLon = start.longitude + (end.longitude - start.longitude) * fraction
                    step++
                } else {
                    currentWaypointIndex++
                    val waypoint = waypoints[currentWaypointIndex]
                    currentLat = waypoint.latitude
                    currentLon = waypoint.longitude
                    simulationState = SimulationState.WAITING
                    waitingEndTime = System.currentTimeMillis() + (intervalSeconds * 1000).toLong()
                }
            }
            SimulationState.WAITING -> {
                val waypoint = waypoints[currentWaypointIndex]
                currentLat = waypoint.latitude
                currentLon = waypoint.longitude
                if (System.currentTimeMillis() >= waitingEndTime) {
                    if (currentWaypointIndex >= waypoints.size - 1) {
                        handleEndOfPath()
                    } else {
                        prepareForMovement()
                    }
                }
            }
            else -> {}
        }
        setMockLocation(currentLat, currentLon)
    }

    private fun handleEndOfPath() {
        if (loop) {
            currentWaypointIndex = 0
            prepareForMovement()
        } else if (reverseLoop) {
            waypoints.reverse()
            currentWaypointIndex = 0
            prepareForMovement()
        } else {
            stopSimulation()
        }
    }

    private fun setMockLocation(lat: Double, lon: Double) {
        val mockLocation = Location(LocationManager.GPS_PROVIDER).apply {
            latitude = lat
            longitude = lon
            altitude = 0.0
            accuracy = 5.0f
            time = System.currentTimeMillis()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
            }
        }
        try {
            locationManager.setTestProviderLocation(LocationManager.GPS_PROVIDER, mockLocation)
        } catch (e: SecurityException) {
            stopSimulation()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopSimulation()
        try {
            locationManager.removeTestProvider(LocationManager.GPS_PROVIDER)
        } catch (e: SecurityException) {
            // Ignore
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("mock_location_service", "Mock Location Service", NotificationManager.IMPORTANCE_DEFAULT)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, "mock_location_service")
            .setContentTitle("Simulating Movement")
            .setContentText("Your location is being simulated along a path.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()
    }

    private fun calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6371e3 // metres
        val phi1 = Math.toRadians(lat1)
        val phi2 = Math.toRadians(lat2)
        val deltaPhi = Math.toRadians(lat2 - lat1)
        val deltaLambda = Math.toRadians(lon2 - lon1)
        val a = sin(deltaPhi / 2) * sin(deltaPhi / 2) + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }
}