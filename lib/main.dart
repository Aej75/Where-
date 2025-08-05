import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LocationProvider(),
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: MapScreen(),
      ),
    );
  }
}

class LocationProvider with ChangeNotifier {
  List<LatLng> _waypoints = [];
  LatLng? _currentLocation;
  bool _isMocking = false;
  bool _useFakeLocation = true;
  bool _loop = false;
  bool _reverseLoop = false;
  int _interval = 0; // Default interval is 0 seconds

  List<LatLng> get waypoints => _waypoints;
  LatLng? get currentLocation => _currentLocation;
  bool get isMocking => _isMocking;
  bool get useFakeLocation => _useFakeLocation;
  bool get loop => _loop;
  bool get reverseLoop => _reverseLoop;
  int get interval => _interval;

  void addWaypoint(LatLng location) {
    _waypoints.add(location);
    notifyListeners();
  }

  void removeWaypoint(int index) {
    _waypoints.removeAt(index);
    notifyListeners();
  }

  void clearWaypoints() {
    _waypoints.clear();
    notifyListeners();
  }

  void setCurrentLocation(Position position) {
    _currentLocation = LatLng(position.latitude, position.longitude);
    notifyListeners();
  }

  void setMocking(bool isMocking) {
    _isMocking = isMocking;
    notifyListeners();
  }

  void setUseFakeLocation(bool value) {
    _useFakeLocation = value;
    if (!value) {
      setMocking(false);
    }
    notifyListeners();
  }

  void setLoop(bool loop) {
    _loop = loop;
    if (loop) {
      _reverseLoop = false;
    }
    notifyListeners();
  }

  void setReverseLoop(bool reverseLoop) {
    _reverseLoop = reverseLoop;
    if (reverseLoop) {
      _loop = false;
    }
    notifyListeners();
  }

  void setInterval(int seconds) {
    _interval = seconds;
    notifyListeners();
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const platform = MethodChannel(
    'com.example.simulate_gps/mock_location',
  );

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _determinePosition();
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    final position = await Geolocator.getCurrentPosition();
    Provider.of<LocationProvider>(
      context,
      listen: false,
    ).setCurrentLocation(position);
  }

  void _onTap(TapPosition _, LatLng location) {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    if (!locationProvider.useFakeLocation) return;

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
    await _determinePosition();
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    if (locationProvider.currentLocation != null) {
      _mapController.move(locationProvider.currentLocation!, 15.0);
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
        title: const Text('SauniTracker'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever),

            onPressed: () {
              locationProvider.clearWaypoints();
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

class SettingsDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final duration = Duration(seconds: locationProvider.interval);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Text(
              'Settings',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          SwitchListTile(
            title: const Text('Use Fake Location'),
            value: locationProvider.useFakeLocation,
            onChanged: (bool value) {
              locationProvider.setUseFakeLocation(value);
              if (!value) {
                // Assuming _stopMockLocation is available in this scope
                // _stopMockLocation();
                locationProvider.clearWaypoints();
              }
            },
          ),
          SwitchListTile(
            title: const Text('Loop'),
            value: locationProvider.loop,
            onChanged: (bool value) {
              locationProvider.setLoop(value);
            },
          ),
          SwitchListTile(
            title: const Text('Reverse Loop'),
            value: locationProvider.reverseLoop,
            onChanged: (bool value) {
              locationProvider.setReverseLoop(value);
            },
          ),
          ListTile(
            title: const Text('Interval'),
            subtitle: Text(
              '${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s',
            ),
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return Container(
                    height: 250,
                    child: CupertinoTimerPicker(
                      mode: CupertinoTimerPickerMode.hms,
                      initialTimerDuration: duration,
                      onTimerDurationChanged: (Duration newDuration) {
                        locationProvider.setInterval(newDuration.inSeconds);
                      },
                    ),
                  );
                },
              );
            },
          ),
          
        ],
      ),
    );
  }
}
