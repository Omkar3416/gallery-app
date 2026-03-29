import 'package:flutter/material.dart';
import 'package:gallery_app/features/editor/presentation/image_editor_page.dart';
import 'package:gallery_app/features/editor/presentation/video_editor_page.dart';
import 'package:gallery_app/features/gallery/presentation/pages/viewer_session.dart';
import 'package:go_router/go_router.dart';

import '../../features/gallery/presentation/pages/gallery_page.dart';
import '../../features/gallery/presentation/pages/albums_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/backup/presentation/backup_page.dart';
import '../../features/gallery/presentation/pages/viewer_page.dart';
import '../../features/gallery/presentation/pages/viewer_args.dart';
import '../../features/gallery/domain/entities/media_item.dart';

class AppRouter {
  static ViewerArgs? _lastViewerArgs;

  static Widget _buildErrorPage(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please report this issue with the steps to reproduce.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  static final GoRouter router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: 'gallery',
        // pageBuilder: (c, s) => const MaterialPage(child: GalleryPage()),
        pageBuilder: (c, s) =>
            MaterialPage(key: s.pageKey, child: const GalleryPage()),
      ),
      GoRoute(
        path: '/albums',
        name: 'albums',
        // pageBuilder: (c, s) => const MaterialPage(child: AlbumsPage()),
        pageBuilder: (c, s) =>
            MaterialPage(key: s.pageKey, child: const AlbumsPage()),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        // pageBuilder: (c, s) => const MaterialPage(child: SettingsPage()),
        pageBuilder: (c, s) =>
            MaterialPage(key: s.pageKey, child: const SettingsPage()),
      ),
      GoRoute(
        path: '/backup',
        name: 'backup',
        // pageBuilder: (c, s) => const MaterialPage(child: BackupPage()),
        pageBuilder: (c, s) =>
            MaterialPage(key: s.pageKey, child: const BackupPage()),
      ),

      // GoRoute(
      //   path: '/viewer',
      //   name: 'viewer',
      //   pageBuilder: (c, s) {
      //     final extra = s.extra;

      //     debugPrint('🔄 Navigating to viewer');
      //     debugPrint('   - Route: ${s.matchedLocation}');
      //     debugPrint('   - Extra: $extra');
      //     debugPrint('   - Extra type: ${extra?.runtimeType}');

      //     if (extra is ViewerArgs) {
      //       _lastViewerArgs = extra;

      //       if (extra.items.isEmpty) {
      //         debugPrint('❌ ViewerArgs has empty items list');
      //         return MaterialPage(
      //           child: _buildErrorPage('No items to display'),
      //         );
      //       }

      //       if (extra.index < 0 || extra.index >= extra.items.length) {
      //         debugPrint(
      //           '❌ Invalid index ${extra.index} for items list of length ${extra.items.length}',
      //         );
      //         return MaterialPage(child: _buildErrorPage('Invalid item index'));
      //       }

      //       return MaterialPage(child: ViewerPage(args: extra));
      //     }

      //     if (extra is MediaItem) {
      //       debugPrint('ℹ️ Using legacy MediaItem navigation');

      //       final args = ViewerArgs(items: [extra], index: 0);
      //       _lastViewerArgs = args;

      //       return MaterialPage(child: ViewerPage(args: args));
      //     }

      //     if (extra == null && _lastViewerArgs != null) {
      //       debugPrint('⚠️ Extra is null, using cached ViewerArgs');

      //       return MaterialPage(child: ViewerPage(args: _lastViewerArgs!));
      //     }

      //     debugPrint('❌ Viewer opened without valid data');
      //     return MaterialPage(
      //       child: _buildErrorPage('Viewer opened without data'),
      //     );
      //   },
      // ),
      GoRoute(
        path: '/viewer/:index',
        name: 'viewer',
        pageBuilder: (c, s) {
          final indexText = s.pathParameters['index'];
          final index = int.tryParse(indexText ?? '');

          if (index == null) {
            // return MaterialPage(child: _buildErrorPage('Invalid viewer index'));
            return MaterialPage(
              key: s.pageKey,
              child: _buildErrorPage('Invalid viewer index'),
            );
          }

          final items = ViewerSession.items;

          if (items.isEmpty) {
            return MaterialPage(
              child: _buildErrorPage('No items loaded for viewer'),
            );
          }

          if (index < 0 || index >= items.length) {
            return MaterialPage(child: _buildErrorPage('Invalid item index'));
          }

          // return MaterialPage(
          //   child: ViewerPage(
          //     args: ViewerArgs(items: items, index: index),
          //   ),
          // );
          return MaterialPage(
            key: s.pageKey,
            child: ViewerPage(
              args: ViewerArgs(items: items, index: index),
            ),
          );
        },
      ),

      // GoRoute(
      //   path: '/edit-image',
      //   name: 'edit-image',
      //   // pageBuilder: (c, s) =>
      //   //     MaterialPage(child: ImageEditorPage(item: s.extra as MediaItem)),
      //   pageBuilder: (c, s) =>
      //       MaterialPage(child: ImageEditorPage(item: s.extra as MediaItem)),
      // ),
      GoRoute(
        path: '/edit-image',
        name: 'edit-image',
        pageBuilder: (c, s) {
          final extra = s.extra;
          if (extra is! MediaItem) {
            return MaterialPage(
              child: _buildErrorPage('Image editor opened without media item'),
            );
          }
          // return MaterialPage(child: ImageEditorPage(item: extra));
          return MaterialPage(
            key: s.pageKey,
            child: ImageEditorPage(item: extra),
          );
        },
      ),
      GoRoute(
        path: '/edit-video',
        name: 'edit-video',
        pageBuilder: (c, s) {
          final extra = s.extra;
          if (extra is! MediaItem) {
            return MaterialPage(
              child: _buildErrorPage('Video editor opened without media item'),
            );
          }
          // return MaterialPage(child: VideoEditorPage(item: extra));
          return MaterialPage(
            key: s.pageKey,
            child: VideoEditorPage(item: extra),
          );
        },
      ),
    ],
  );
}
