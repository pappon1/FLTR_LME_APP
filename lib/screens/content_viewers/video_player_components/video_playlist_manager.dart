import 'package:flutter/foundation.dart';

class VideoPlaylistManager extends ChangeNotifier {
  final List<Map<String, dynamic>> playlist;
  final ValueNotifier<int> currentIndexNotifier = ValueNotifier(0);

  VideoPlaylistManager({required this.playlist, required int initialIndex}) {
    currentIndexNotifier.value = initialIndex;
  }

  Map<String, dynamic>? get currentItem {
    if (playlist.isEmpty || currentIndexNotifier.value >= playlist.length)
      return null;
    return playlist[currentIndexNotifier.value];
  }

  String get currentTitle => currentItem?['name'] ?? "Video";
  String? get currentPath => currentItem?['path'] as String?;

  bool get hasNext => currentIndexNotifier.value < playlist.length - 1;
  bool get hasPrev => currentIndexNotifier.value > 0;

  void goToIndex(int index) {
    if (index >= 0 && index < playlist.length) {
      currentIndexNotifier.value = index;
      notifyListeners();
    }
  }

  bool next() {
    if (hasNext) {
      currentIndexNotifier.value++;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool previous() {
    if (hasPrev) {
      currentIndexNotifier.value--;
      notifyListeners();
      return true;
    }
    return false;
  }

  void updateDuration(int index, String duration) {
    if (index >= 0 && index < playlist.length) {
      playlist[index]['duration'] = duration;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    currentIndexNotifier.dispose();
    super.dispose();
  }
}
