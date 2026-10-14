import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'library_service.dart';

class YtService {
  static final i = YtService._();
  YtService._();
  final yt = YoutubeExplode();

  Future<List<Track>> search(String q) async {
    final r = await yt.search.search(q);
    return r
        .take(30)
        .map((v) => Track(
              id: v.id.value,
              title: v.title,
              artist: v.author,
              thumb: v.thumbnails.mediumResUrl,
              durationMs: v.duration?.inMilliseconds ?? 0,
            ))
        .toList();
  }

  /// Лучший аудиопоток (предпочитаем m4a/AAC).
  Future<AudioStreamInfo> bestAudio(String id) async {
    final m = await yt.videos.streamsClient.getManifest(id);
    final Iterable<AudioStreamInfo> mp4 =
        m.audioOnly.where((s) => s.container == StreamContainer.mp4);
    final Iterable<AudioStreamInfo> list = mp4.isNotEmpty ? mp4 : m.audioOnly;
    return list.withHighestBitrate();
  }
}
