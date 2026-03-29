import '../../../gallery/domain/entities/media_item.dart';

class ViewerArgs {
  final List<MediaItem> items;
  final int index; // which item to open on

  const ViewerArgs({required this.items, required this.index});
}
