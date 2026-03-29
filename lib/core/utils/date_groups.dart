import 'package:intl/intl.dart';
import '../../features/gallery/domain/entities/media_item.dart';

class DateSection {
  final String title;
  final List<MediaItem> items;
  DateSection(this.title, this.items);
}

List<DateSection> groupByFriendlyDate(List<MediaItem> items) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekAgo = today.subtract(const Duration(days: 7));
  final monthAgo = today.subtract(const Duration(days: 30));

  final sections = <String, List<MediaItem>>{
    'Today': [],
    'Yesterday': [],
    'Last 7 Days': [],
    'Last 30 Days': [],
    'Older': [],
  };

  for (final m in items) {
    final d = DateTime.fromMillisecondsSinceEpoch(m.createdAt);
    final day = DateTime(d.year, d.month, d.day);
    if (day.isAtSameMomentAs(today)) {
      sections['Today']!.add(m);
    } else if (day.isAtSameMomentAs(yesterday)) {
      sections['Yesterday']!.add(m);
    } else if (day.isAfter(weekAgo)) {
      sections['Last 7 Days']!.add(m);
    } else if (day.isAfter(monthAgo)) {
      sections['Last 30 Days']!.add(m);
    } else {
      sections['Older']!.add(m);
    }
  }

  // remove empty sections, keep order
  final out = <DateSection>[];
  for (final k in ['Today', 'Yesterday', 'Last 7 Days', 'Last 30 Days', 'Older']) {
    final list = sections[k]!;
    if (list.isNotEmpty) {
      // newest first
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      out.add(DateSection(k, list));
    }
  }
  return out;
}
