import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/location_provider.dart';
import '../widgets/settings_drawer.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel(
    'com.example.simulate_gps/mock_location',
  );

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final locationProvider = Provider.of<LocationProvider>(
        context,
        listen: false,
      );
      // If the app resumes and the Flutter state says it's not mocking,
      // ensure the native service is stopped to dismiss the notification.
      if (!locationProvider.isMocking) {
        _stopMockLocation();
      }
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled, show a message to the user.
      print('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, do not request automatically here.
      print('Location permissions are denied.');
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied, show a message to the user.
      print('Location permissions are permanently denied.');
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        Provider.of<LocationProvider>(
          context,
          listen: false,
        ).setCurrentLocation(position);
      }
    } catch (e) {
      print('Error getting current position: $e');
    }
  }

  void _onTap(TapPosition _, LatLng location) {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    if (!locationProvider.useFakeLocation || locationProvider.isMocking) return;

    locationProvider.addWaypoint(location);
  }

  Future<void> _toggleMockLocation() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    if (locationProvider.isMocking) {
      await _pauseMockLocation();
    } else {
      if (locationProvider.useFakeLocation &&
          locationProvider.waypoints.isNotEmpty) {
        await _startMockLocation();
      }
    }
  }

  Future<void> _startMockLocation() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    try {
      await platform.invokeMethod('startMockLocation', {
        'waypoints':
            locationProvider.waypoints
                .map((p) => {'lat': p.latitude, 'lon': p.longitude})
                .toList(),
        'loop': locationProvider.loop,
        'reverseLoop': locationProvider.reverseLoop,
        'interval': locationProvider.interval,
        'speed': 5.0, // Example speed: 5 meters per second
      });
      Provider.of<LocationProvider>(context, listen: false).setMocking(true);
    } on PlatformException catch (e) {
      print("Failed to start mock location: '${e.message}'.");
    }
  }

  Future<void> _pauseMockLocation() async {
    try {
      await platform.invokeMethod('pauseMockLocation');
      Provider.of<LocationProvider>(context, listen: false).setMocking(false);
    } on PlatformException catch (e) {
      print("Failed to pause mock location: '${e.message}'.");
    }
  }

  Future<void> _stopMockLocation() async {
    try {
      await platform.invokeMethod('stopMockLocation');
      Provider.of<LocationProvider>(context, listen: false).setMocking(false);
    } on PlatformException catch (e) {
      print("Failed to stop mock location: '${e.message}'.");
    }
  }

  void _goToMyLocation() async {
    try {
      // Request permissions when the user explicitly asks for their location
      final status = await Permission.location.request();

      if (status.isGranted) {
        await _determinePosition();
        final locationProvider = Provider.of<LocationProvider>(
          context,
          listen: false,
        );
        if (locationProvider.currentLocation != null) {
          _mapController.move(locationProvider.currentLocation!, 15.0);
        }
      } else if (status.isDenied || status.isPermanentlyDenied) {
        // Optionally, show a dialog or snackbar to inform the user
        // that permissions are needed.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are required to show your current location.'),
          ),
        );
      }
    } on PlatformException catch (e) {
      // Handle the PlatformException, likely due to activity not being ready
      print("PlatformException during permission request: ${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not request location permissions. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final bool canSimulate =
        locationProvider.useFakeLocation &&
        locationProvider.waypoints.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Sauni Tracker'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever),

            onPressed: () async {
              final bool confirm =
                  await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Clear Waypoints'),
                        content: const Text(
                          'Are you sure you want to clear all waypoints? This will stop any ongoing simulation.',
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Clear'),
                          ),
                        ],
                      );
                    },
                  ) ??
                  false;

              if (confirm) {
                if (locationProvider.isMocking) {
                  await _stopMockLocation();
                }
                locationProvider.clearWaypoints();
              }
            },
          ),
        ],
      ),

      drawer: SettingsDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(0, 0),
              initialZoom: 2.0,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              ),
              if (locationProvider.useFakeLocation) ...[
                MarkerLayer(
                  markers:
                      locationProvider.waypoints.asMap().entries.map((entry) {
                        final index = entry.key;
                        final point = entry.value;
                        final color =
                            Colors.primaries[index % Colors.accents.length];
                        final letter = String.fromCharCode(65 + index);

                        return Marker(
                          width: 80.0,
                          height: 80.0,
                          point: point,
                          child: Column(
                            children: [
                              Text(
                                letter,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              Icon(
                                Icons.face_3_sharp,
                                color: color,
                                size: 30.0,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ],
              if (locationProvider.currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: locationProvider.currentLocation!,
                      child: Icon(Icons.my_location, color: Colors.blueAccent),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Chip(
                label: Text(
                  style: TextStyle(fontWeight: FontWeight.w700),
                  locationProvider.isMocking
                      ? 'Simulating Movement'
                      : locationProvider.useFakeLocation
                      ? 'Select Waypoints'
                      : 'Using Real Location',
                ),
                backgroundColor:
                    locationProvider.isMocking ? Colors.green : Colors.orange,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Chip(
                label: Text('Waypoints: ${locationProvider.waypoints.length}'),
                backgroundColor: Colors.blueGrey,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'myLocation',
            onPressed: _goToMyLocation,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'simulate',
            onPressed:
                canSimulate || locationProvider.isMocking
                    ? _toggleMockLocation
                    : null,
            backgroundColor:
                canSimulate || locationProvider.isMocking
                    ? (locationProvider.isMocking ? Colors.red : Colors.green)
                    : Colors.grey,
            child: Icon(
              locationProvider.isMocking ? Icons.stop : Icons.play_arrow,
            ),
          ),
        ],
      ),
    );
  }
}
