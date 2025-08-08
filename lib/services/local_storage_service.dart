import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

class LocalStorageService {
  static const _waypointsKey = 'waypoints';
  static const _isMockingKey = 'isMocking';
  static const _useFakeLocationKey = 'useFakeLocation';
  static const _loopKey = 'loop';
  static const _reverseLoopKey = 'reverseLoop';
  static const _intervalKey = 'interval';

  Future<void> saveWaypoints(List<LatLng> waypoints) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList =
        waypoints
            .map(
              (p) => jsonEncode({
                'latitude': p.latitude,
                'longitude': p.longitude,
              }),
            )
            .toList();
    await prefs.setStringList(_waypointsKey, jsonList);
  }

  Future<List<LatLng>> loadWaypoints() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList(_waypointsKey);
    if (jsonList == null) {
      return [];
    }
    return jsonList.map((jsonString) {
      final Map<String, dynamic> map = jsonDecode(jsonString);
      return LatLng(map['latitude'], map['longitude']);
    }).toList();
  }

  Future<void> saveIsMocking(bool isMocking) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isMockingKey, isMocking);
  }

  Future<bool> loadIsMocking() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isMockingKey) ?? false;
  }

  Future<void> saveUseFakeLocation(bool useFakeLocation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useFakeLocationKey, useFakeLocation);
  }

  Future<bool> loadUseFakeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useFakeLocationKey) ?? true; // Default to true
  }

  Future<void> saveLoop(bool loop) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loopKey, loop);
  }

  Future<bool> loadLoop() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loopKey) ?? false;
  }

  Future<void> saveReverseLoop(bool reverseLoop) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reverseLoopKey, reverseLoop);
  }

  Future<bool> loadReverseLoop() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_reverseLoopKey) ?? false;
  }

  Future<void> saveInterval(int interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_intervalKey, interval);
  }

  Future<int> loadInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_intervalKey) ?? 0;
  }
}
