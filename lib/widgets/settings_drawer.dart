import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/location_provider.dart';

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
