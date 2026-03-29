// lib/core/widgets/app_nav.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_settings.dart';

enum AppTab { gallery, albums, backup, settings }

class AppNavBar extends StatelessWidget {
  final AppTab current;
  const AppNavBar({super.key, required this.current});

  int _toIndex(bool showBackup) {
    switch (current) {
      case AppTab.gallery:
        return 0;
      case AppTab.albums:
        return 1;
      case AppTab.backup:
        return showBackup ? 2 : 999; // if hidden, won't be chosen
      case AppTab.settings:
        return showBackup ? 3 : 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppSettings().changes, // <- listens to Settings changes
      builder: (_, __, ___) {
        final s = AppSettings();
        final showBackup = s.cloudAvailable;

        final items = <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.photo),
            label: 'Gallery',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.collections),
            label: 'Albums',
          ),
          if (showBackup)
            const BottomNavigationBarItem(
              icon: Icon(Icons.cloud_upload),
              label: 'Backup',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ];

        final idx = _toIndex(showBackup);

        return BottomNavigationBar(
          currentIndex: (idx >= items.length) ? 0 : idx,
          type: BottomNavigationBarType.fixed,
          items: items,
          onTap: (i) {
            // map the tapped index to a route, accounting for Backup possibly hidden
            if (!showBackup) {
              // indices: 0=gallery, 1=albums, 2=settings
              switch (i) {
                case 0:
                  context.go('/');
                  break;
                case 1:
                  context.go('/albums');
                  break;
                case 2:
                  context.go('/settings');
                  break;
              }
            } else {
              // indices: 0=gallery, 1=albums, 2=backup, 3=settings
              switch (i) {
                case 0:
                  context.go('/');
                  break;
                case 1:
                  context.go('/albums');
                  break;
                case 2:
                  context.go('/backup');
                  break;
                case 3:
                  context.go('/settings');
                  break;
              }
            }
          },
        );
      },
    );
  }
}
