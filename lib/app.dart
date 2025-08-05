import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/location_provider.dart';
import 'screens/map_screen.dart';

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
