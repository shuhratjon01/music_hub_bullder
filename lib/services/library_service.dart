import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' show StreamContainer;
import 'yt_service.dart';

class Track {
  final String id, title, artist, thumb;
  final int durationMs;
  Track({required this.id, required this.title, required this.artist, required this.thumb, this.durationMs = 0});

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'artist': artist, 'thumb': thumb, 'd': durationMs};
  factory Track.fromJson(Map j) => Track(
      id: j['id'], title: j['title'], artist: j['artist'], thumb: j['thumb'], durationMs: j['d'] ?? 0);
  factory Track.fromItem(MediaItem m) => Track(
      id: m.id,
      title: m.title,
      artist: m.artist ?? '',
      thumb: (m.extras?['thumb'] as String?) ?? '',
      durationMs: m.duration?.inMilliseconds ?? 0);

  Uri? get art => Library.i.localThumb(id) ?? (thumb.isEmpty ? null : Uri.parse(thumb));

  MediaItem toItem() => MediaItem(
      id: id,
      title: title,
      artist: artist,
      artUri: art,
      duration: durationMs > 0 ? Duration(milliseconds: durationMs) : null,
      extras: {'thumb': thumb});
}

/// Локальная библиотека: скачанные треки и плейлисты.
class Library extends ChangeNotifier {
  static final i = Library._();
  Library._();

  late Directory dir;
  final tracks = <String, Track>{};
  final _files = <String, String>{}; // id -> имя файла
  final playlists = <String, List<String>>{};
  final progress = ValueNotifier<Map<String, double>>({});

  File get _db => File('${dir.parent.path}/library.json');

  Future<void> init() async {
    dir = Directory('${(await getApplicationDocumentsDirectory()).path}/music');
    await dir.create(recursive: true);
    try {
      if (await _db.exists()) {
        final j = jsonDecode(await _db.readAsString());
        (j['tracks'] as Map).forEach((k, v) => tracks[k] = Track.fromJson(v));
        (j['files'] as Map).forEach((k, v) => _files[k] = v);
        (j['playlists'] as Map).forEach((k, v) => playlists[k] = List<String>.from(v));
      }
    } catch (_) {}
    _files.removeWhere((id, f) => !File('${dir.path}/$f').existsSync());
  }

  Future<void> _save() => _db.writeAsString(jsonEncode({
        'tracks': tracks.map((k, v) => MapEntry(k, v.toJson())),
        'files': _files,
        'playlists': playlists,
      }));

  String? pathFor(String id) => _files[id] == null ? null : '${dir.path}/${_files[id]}';
  bool isDownloaded(String id) => _files.containsKey(id);
  List<Track> get downloaded => _files.keys.map((k) => tracks[k]).whereType<Track>().toList();

  Uri? localThumb(String id) {
    final f = File('${dir.path}/$id.jpg');
    return f.existsSync() ? Uri.file(f.path) : null;
  }

  void _setP(String id, double v) => progress.value = {...progress.value, id: v};
  void _clearP(String id) => progress.value = Map.of(progress.value)..remove(id);

  Future<bool> download(Track t) async {
    if (isDownloaded(t.id) || progress.value.containsKey(t.id)) return true;
    _setP(t.id, 0);
    File? f;
    try {
      final info = await YtService.i.bestAudio(t.id);
      final ext = info.container == StreamContainer.mp4 ? 'm4a' : info.container.name;
      f = File('${dir.path}/${t.id}.$ext');
      final sink = f.openWrite();
      final total = info.size.totalBytes;
      var got = 0, last = -1;
      await for (final c in YtService.i.yt.videos.streamsClient.get(info)) {
        sink.add(c);
        got += c.length;
        final pc = got * 100 ~/ total;
        if (pc != last) {
          last = pc;
          _setP(t.id, got / total);
        }
      }
      await sink.flush();
      await sink.close();
      if (t.thumb.startsWith('http')) await _saveThumb(t);
      tracks[t.id] = t;
      _files[t.id] = f.uri.pathSegments.last;
      await _save();
      _clearP(t.id);
      notifyListeners();
      return true;
    } catch (_) {
      try {
        await f?.delete();
      } catch (_) {}
      _clearP(t.id);
      return false;
    }
  }

  Future<void> _saveThumb(Track t) async {
    try {
      final c = HttpClient();
      final r = await (await c.getUrl(Uri.parse(t.thumb))).close();
      await r.pipe(File('${dir.path}/${t.id}.jpg').openWrite());
      c.close();
    } catch (_) {}
  }

  Future<void> removeDownload(String id) async {
    final p = pathFor(id);
    _files.remove(id);
    try {
      if (p != null) await File(p).delete();
    } catch (_) {}
    await _save();
    notifyListeners();
  }

  // ---- Плейлисты ----
  void createPlaylist(String name) {
    playlists.putIfAbsent(name, () => []);
    _save();
    notifyListeners();
  }

  void deletePlaylist(String name) {
    playlists.remove(name);
    _save();
    notifyListeners();
  }

  void addToPlaylist(String name, Track t) {
    tracks[t.id] = t;
    final l = playlists.putIfAbsent(name, () => []);
    if (!l.contains(t.id)) l.add(t.id);
    _save();
    notifyListeners();
  }

  void removeFromPlaylist(String name, String id) {
    playlists[name]?.remove(id);
    _save();
    notifyListeners();
  }

  List<Track> playlistTracks(String name) =>
      (playlists[name] ?? []).map((id) => tracks[id]).whereType<Track>().toList();
}
