// lib/features/settings/presentation/settings_page.dart
import 'package:flutter/material.dart';
import 'package:gallery_app/core/config/cloud_config.dart'; // for CloudMode picker
import 'package:gallery_app/core/widgets/app_nav.dart';
import 'package:gallery_app/features/ai/tagging/tagging_service.dart';
import 'package:gallery_app/services/media_indexer/media_indexer.dart';

import '../../../core/config/app_settings.dart';
import '../../../services/aws/guardrails/budget_guard.dart';

/// Professional accent color choices (Material 3 seed)
const List<Color> _seedChoices = [
  Color(0xFF6750A4), // Purple
  Color(0xFF0062FF), // Blue
  Color(0xFF00A2A2), // Teal
  Color(0xFF00875A), // Green
  Color(0xFFFF8A00), // Orange
  Color(0xFFFFB300), // Amber
  Color(0xFFE91E63), // Pink
  Color(0xFF7C4DFF), // Deep Purple
  Color(0xFF3F51B5), // Indigo
  Color(0xFFEF5350), // Red
];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _ai;
  late int _cap;

  @override
  void initState() {
    super.initState();
    _ai = AppSettings().aiEnabled;
    _cap = BudgetGuard().maxCallsPerMonth;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings();
    final guard = BudgetGuard();
    final inDev = s.devMode;        // Developer mode?
    final cloudOn = s.awsEnabled;   // Cloud switch (works only in Dev)

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          // Long-press the title to toggle Dev / Prod (kept from your code)
          onLongPress: () async {
            final pick = await showModalBottomSheet<String>(
              context: context,
              builder: (c) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                    leading: const Icon(Icons.developer_mode),
                    title: const Text('Developer'),
                    onTap: () => Navigator.pop(c, 'dev'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: const Text('Production'),
                    onTap: () => Navigator.pop(c, 'prod'),
                  ),
                ]),
              ),
            );
            if (pick == null) return;

            if (pick == 'dev') {
              s.devMode = true;
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Developer mode ON')),
              );
            } else {
              s.devMode = false; // hides/disables cloud UI
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Production mode ON')),
              );
            }
          },
          child: const Text('Settings'),
        ),
      ),

      body: ListView(
        children: [
          // ---------- Appearance (NEW – always visible) ----------
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          ),

          // Theme Mode picker (System / Light / Dark)
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            subtitle: Text(() {
              switch (s.themeMode) {
                case ThemeMode.light: return 'Light';
                case ThemeMode.dark: return 'Dark';
                case ThemeMode.system: default: return 'System';
              }
            }()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final pick = await showModalBottomSheet<ThemeMode>(
                context: context,
                builder: (c) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    RadioListTile<ThemeMode>(
                      title: const Text('System'),
                      value: ThemeMode.system,
                      groupValue: s.themeMode,
                      onChanged: (v) => Navigator.pop(c, v),
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Light'),
                      value: ThemeMode.light,
                      groupValue: s.themeMode,
                      onChanged: (v) => Navigator.pop(c, v),
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Dark'),
                      value: ThemeMode.dark,
                      groupValue: s.themeMode,
                      onChanged: (v) => Navigator.pop(c, v),
                    ),
                    const SizedBox(height: 8),
                  ]),
                ),
              );
              if (pick != null) setState(() => s.themeMode = pick);
            },
          ),

          // Seed color palette (multi-colors for Material 3)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Accent color', style: Theme.of(context).textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _seedChoices.map((c) {
                final selected = s.seedColor.value == c.value;
                return GestureDetector(
                  onTap: () => setState(() => s.seedColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.15),
                          blurRadius: selected ? 10 : 6,
                          spreadRadius: selected ? 1 : 0,
                        )
                      ],
                      border: Border.all(
                        color: selected ? Colors.white : Colors.black12,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),

          // ---------- maintenance ----------
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Maintenance', style: Theme.of(context).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Reindex device media'),
            subtitle: const Text('If you see “No items”, tap to rescan Photos/Videos.'),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reindexing…')));
              await MediaIndexer().reindex();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reindex complete')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.tag),
            title: const Text('Retag all (on-device)'),
            subtitle: const Text('Recompute tags for all non-trashed items. No cloud used.'),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retagging…')));
              await TaggingService().retagAll();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retag complete')));
            },
          ),

          // ---------- on-device AI ----------
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('On-device AI', style: Theme.of(context).textTheme.titleMedium),
          ),
          SwitchListTile(
            title: const Text('Enable on-device AI'),
            value: _ai,
            onChanged: (v) {
              setState(() {
                _ai = v;
                s.aiEnabled = v;
              });
            },
          ),

          // ---------- developer section ----------
          if (inDev) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Developer', style: Theme.of(context).textTheme.titleMedium),
            ),

            // cloud backup master toggle
            SwitchListTile(
              title: const Text('Cloud backup (AWS)'),
              subtitle: const Text('Visible only in Developer mode'),
              value: cloudOn,
              onChanged: (v) => setState(() => s.awsEnabled = v),
            ),

            // Cloud mode picker (Disabled / LocalStack / AWS)
            ListTile(
              title: const Text('Cloud mode'),
              subtitle: Text(s.cloudMode.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final pick = await showModalBottomSheet<CloudMode>(
                  context: context,
                  builder: (c) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ListTile(
                        title: const Text('Disabled'),
                        onTap: () => Navigator.pop(c, CloudMode.disabled),
                      ),
                      ListTile(
                        title: const Text('LocalStack'),
                        onTap: () => Navigator.pop(c, CloudMode.localstack),
                      ),
                      ListTile(
                        title: const Text('AWS'),
                        onTap: () => Navigator.pop(c, CloudMode.aws),
                      ),
                      const SizedBox(height: 8),
                    ]),
                  ),
                );
                if (pick != null) setState(() => s.cloudMode = pick);
              },
            ),

            // Lambda Function URL (required for presign)
            ListTile(
              title: const Text('Lambda Function URL'),
              subtitle: Text(s.lambdaUrl.isEmpty ? '(not set)' : s.lambdaUrl),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final ctl = TextEditingController(text: s.lambdaUrl);
                final val = await showDialog<String>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Lambda Function URL'),
                    content: TextField(
                      controller: ctl,
                      decoration: const InputDecoration(
                        hintText: 'https://xxxx.lambda-url.ap-south-1.on.aws/',
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('Save')),
                    ],
                  ),
                );
                if (val != null) setState(() => s.lambdaUrl = val);
              },
            ),

            // optional x-app-key header (if your Lambda checks it)
            ListTile(
              title: const Text('x-app-key (optional)'),
              subtitle: Text(s.appKey.isEmpty ? '(none)' : s.appKey),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final ctl = TextEditingController(text: s.appKey);
                final val = await showDialog<String>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('x-app-key header'),
                    content: TextField(
                      controller: ctl,
                      decoration: const InputDecoration(hintText: 'omkar'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('Save')),
                    ],
                  ),
                );
                if (val != null) setState(() => s.appKey = val);
              },
            ),

            // monthly call cap (BudgetGuard)
            ListTile(
              title: const Text('Monthly AWS call cap'),
              subtitle: Text('Blocks calls beyond this. Current: $_cap, Used: ${guard.callsThisMonth}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final controller = TextEditingController(text: '$_cap');
                  final v = await showDialog<int>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Set monthly cap'),
                      content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '0 = block all'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            final parsed = int.tryParse(controller.text.trim()) ?? 0;
                            Navigator.pop(c, parsed);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (v != null) {
                    setState(() {
                      _cap = v;
                      guard.maxCallsPerMonth = v;
                    });
                  }
                },
              ),
            ),
          ],

          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Tip: long-press “Settings” to switch Developer / Production.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),

      bottomNavigationBar: const AppNavBar(current: AppTab.settings),
    );
  }
}
