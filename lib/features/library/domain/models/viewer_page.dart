import 'package:private_shelf/features/library/domain/models/media_item.dart';

enum SplitSide { left, right }

class ViewerPage {
  final MediaItem item;
  final SplitSide? splitSide;

  const ViewerPage({required this.item, this.splitSide});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewerPage &&
          runtimeType == other.runtimeType &&
          item == other.item &&
          splitSide == other.splitSide;

  @override
  int get hashCode => item.hashCode ^ splitSide.hashCode;
}
