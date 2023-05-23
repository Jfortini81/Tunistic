import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

//DO NOT TOUCH
/// The [Favorites] class holds a list of favorite items saved by the user.
class HeartedSongsProvider extends InheritedWidget with ChangeNotifier {
  final Set<String> _heartedSongIds = Set<String>();
  final List<Map<String, dynamic>> _heartedTracks = [];

  //constructor -> takes child and optional key
  HeartedSongsProvider({required Widget child, Key? key})
      : super(key: key, child: child);

  bool isHearted(Map<String, dynamic> track) {
    return _heartedSongIds.contains(track['id']);
  }

  static HeartedSongsProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HeartedSongsProvider>()!;
  }

  bool contains(String id) {
    bool result = _heartedSongIds.contains(id);
    return result;
  }

  void toggle(String id, Map<String, dynamic> track) {
    if (_heartedSongIds.contains(id)) {
      _heartedSongIds.remove(id);
      _heartedTracks.removeWhere((t) => t['id'] == id);
    } else {
      _heartedSongIds.add(id);
      _heartedTracks.add(track);
    }
    notifyListeners();
  }

  set _heartedSongs(List<Map<String, dynamic>> value) {
    _heartedTracks.clear();
    _heartedTracks.addAll(value);
    notifyListeners();
  }

  List<Map<String, dynamic>> get heartedTracks => _heartedTracks;

  @override
  bool updateShouldNotify(HeartedSongsProvider oldWidget) =>
      !setEquals(_heartedSongIds, oldWidget._heartedSongIds);
}
