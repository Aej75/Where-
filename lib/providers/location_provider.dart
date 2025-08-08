import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/local_storage_service.dart';

class LocationProvider with ChangeNotifier {
  final LocalStorageService _localStorageService = LocalStorageService();

  List<LatLng> _waypoints = [];
  LatLng? _currentLocation;
  bool _isMocking = false;
  bool _useFakeLocation = true;
  bool _loop = false;
  bool _reverseLoop = false;
  int _interval = 0; // Default interval is 0 seconds

  LocationProvider() {
    _loadState();
  }

  Future<void> _loadState() async {
    _waypoints = await _localStorageService.loadWaypoints();
    _isMocking = await _localStorageService.loadIsMocking();
    _useFakeLocation = await _localStorageService.loadUseFakeLocation();
    _loop = await _localStorageService.loadLoop();
    _reverseLoop = await _localStorageService.loadReverseLoop();
    _interval = await _localStorageService.loadInterval();
    notifyListeners();
  }

  List<LatLng> get waypoints => _waypoints;
  LatLng? get currentLocation => _currentLocation;
  bool get isMocking => _isMocking;
  bool get useFakeLocation => _useFakeLocation;
  bool get loop => _loop;
  bool get reverseLoop => _reverseLoop;
  int get interval => _interval;

  void addWaypoint(LatLng location) {
    _waypoints.add(location);
    _localStorageService.saveWaypoints(_waypoints);
    notifyListeners();
  }

  void removeWaypoint(int index) {
    _waypoints.removeAt(index);
    _localStorageService.saveWaypoints(_waypoints);
    notifyListeners();
  }

  void clearWaypoints() {
    _waypoints.clear();
    _localStorageService.saveWaypoints(_waypoints);
    notifyListeners();
  }

  void setCurrentLocation(Position position) {
    _currentLocation = LatLng(position.latitude, position.longitude);
    notifyListeners();
  }

  void setMocking(bool isMocking) {
    _isMocking = isMocking;
    _localStorageService.saveIsMocking(_isMocking);
    notifyListeners();
  }

  void setUseFakeLocation(bool value) {
    _useFakeLocation = value;
    if (!value) {
      setMocking(false);
    }
    _localStorageService.saveUseFakeLocation(_useFakeLocation);
    notifyListeners();
  }

  void setLoop(bool loop) {
    _loop = loop;
    if (loop) {
      _reverseLoop = false;
    }
    _localStorageService.saveLoop(_loop);
    notifyListeners();
  }

  void setReverseLoop(bool reverseLoop) {
    _reverseLoop = reverseLoop;
    if (reverseLoop) {
      _loop = false;
    }
    _localStorageService.saveReverseLoop(_reverseLoop);
    notifyListeners();
  }

  void setInterval(int seconds) {
    _interval = seconds;
    _localStorageService.saveInterval(_interval);
    notifyListeners();
  }
}
