import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  bool _isMocking = false;
  bool _useFakeLocation = true;

  LatLng? get selectedLocation => _selectedLocation;
  LatLng? get currentLocation => _currentLocation;
  bool get isMocking => _isMocking;
  bool get useFakeLocation => _useFakeLocation;

  void setSelectedLocation(LatLng location) {
    _selectedLocation = location;
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
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const platform = MethodChannel('com.example.simulate_gps/mock_location');

  final MapController _mapController = MapController();
  List<Marker> _markers = [];

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
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    final position = await Geolocator.getCurrentPosition();
    Provider.of<LocationProvider>(context, listen: false).setCurrentLocation(position);
  }

  void _onTap(TapPosition _, LatLng location) {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (!locationProvider.useFakeLocation) return;

    locationProvider.setSelectedLocation(location);
    setState(() {
      _markers = [
        Marker(
          width: 80.0,
          height: 80.0,
          point: location,
          child: Icon(Icons.location_on, color: Colors.red, size: 50.0),
        ),
      ];
    });
  }

  Future<void> _toggleMockLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.isMocking) {
      await _stopMockLocation();
    } else {
      if (locationProvider.useFakeLocation && locationProvider.selectedLocation != null) {
        await _startMockLocation(locationProvider.selectedLocation!);
      }
    }
  }

  Future<void> _startMockLocation(LatLng location) async {
    try {
      await platform.invokeMethod('startMockLocation', {
        'lat': location.latitude,
        'lon': location.longitude,
      });
      Provider.of<LocationProvider>(context, listen: false).setMocking(true);
    } on PlatformException catch (e) {
      print("Failed to start mock location: '${e.message}'.");
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

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<LocationProvider>(
          builder: (context, locationProvider, child) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Settings', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Use Fake Location'),
                    value: locationProvider.useFakeLocation,
                    onChanged: (bool value) {
                      locationProvider.setUseFakeLocation(value);
                      if (!value) {
                        _stopMockLocation();
                        setState(() {
                          _markers.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _goToMyLocation() async {
    await _determinePosition();
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentLocation != null) {
      _mapController.move(locationProvider.currentLocation!, 15.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final bool canSimulate = locationProvider.useFakeLocation && locationProvider.selectedLocation != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SauniTracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsPanel,
          ),
        ],
      ),
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
              if (locationProvider.useFakeLocation)
                MarkerLayer(
                  markers: _markers,
                ),
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
                      ? 'Simulating Location'
                      : locationProvider.useFakeLocation
                          ? 'Using Fake Location (Paused)'
                          : 'Using Real Location',
                ),
                backgroundColor: locationProvider.isMocking ? Colors.green : Colors.orange,
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
            onPressed: canSimulate || locationProvider.isMocking ? _toggleMockLocation : null,
            backgroundColor: canSimulate || locationProvider.isMocking
                ? (locationProvider.isMocking ? Colors.red : Colors.green)
                : Colors.grey,
            child: Icon(locationProvider.isMocking ? Icons.stop : Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}