import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../services/library_service.dart';
import '../services/settings.dart';
import '../services/yt_service.dart';
import '../util.dart';

class MusicHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final eq = AndroidEqualizer();
  late final AudioPlayer player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [eq]),
  );
  int _index = 0;

  Timer? _sleep;
  final sleepLeft = ValueNotifier<Duration?>(null);

  MusicHandler() {
    player.playbackEventStream.listen((e) => playbackState.add(_state(e)), onError: (_) {});
    player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) skipToNext();
    });
    player.durationStream.listen((d) {
      final it = mediaItem.value;
      if (d != null && it != null && it.duration != d) mediaItem.add(it.copyWith(duration: d));
    });
  }

  PlaybackState _state(PlaybackEvent e) => PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[player.processingState]!,
        playing: player.playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: _index,
      );

  // ---------- Очередь и воспроизведение ----------
  Future<void> playQueue(List<Track> tracks, int start) async {
    queue.add(tracks.map((t) => t.toItem()).toList());
    await _playIndex(start);
  }

  Future<void> _playIndex(int i) async {
    final q = queue.value;
    if (i < 0 || i >= q.length) return;
    _index = i;
    final item = q[i];
    mediaItem.add(item);
    try {
      final path = Library.i.pathFor(item.id);
      if (path != null) {
        await player.setFilePath(path); // оффлайн
      } else {
        final info = await YtService.i.bestAudio(item.id); // стриминг
        await player.setUrl(info.url.toString());
      }
      await applyEq();
      player.play();
    } catch (_) {
      toast('Не удалось воспроизвести трек. Проверьте интернет.');
      await player.stop();
    }
  }

  @override
  Future<void> play() async {
    player.play();
  }

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_index + 1 < queue.value.length) {
      await _playIndex(_index + 1);
    } else {
      await player.pause();
      await player.seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (player.position > const Duration(seconds: 3) || _index == 0) {
      await player.seek(Duration.zero);
    } else {
      await _playIndex(_index - 1);
    }
  }

  @override
  Future<void> stop() async {
    cancelSleep();
    await player.stop();
    await super.stop();
  }

  // ---------- Таймер сна с Fade-Out ----------
  static const _fade = Duration(seconds: 150); // последние 2,5 минуты

  void startSleep(Duration total) {
    cancelSleep();
    final end = DateTime.now().add(total);
    final fade = Duration(seconds: min(_fade.inSeconds, total.inSeconds));
    sleepLeft.value = total;
    _sleep = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final left = end.difference(DateTime.now());
      if (left <= Duration.zero) {
        await player.pause();
        cancelSleep(); // возвращает громкость 1.0 для следующего запуска
        return;
      }
      sleepLeft.value = left;
      if (left < fade) {
        final x = left.inMilliseconds / fade.inMilliseconds;
        player.setVolume((x * x).clamp(0.0, 1.0)); // плавная кривая до нуля
      }
    });
  }

  void cancelSleep() {
    _sleep?.cancel();
    _sleep = null;
    sleepLeft.value = null;
    player.setVolume(1.0);
  }

  // ---------- Эквалайзер и Bass Boost ----------
  Future<void> applyEq() async {
    final s = Settings.i;
    try {
      await eq.setEnabled(s.eqOn || s.bass);
      final p = await eq.parameters;
      final n = p.bands.length;
      for (var i = 0; i < n; i++) {
        final src = n == 1 ? 0 : (i * (s.gains.length - 1) / (n - 1)).round();
        var g = s.eqOn ? s.gains[src] : 0.0;
        if (s.bass) {
          final k = n == 1 ? 0.0 : i / (n - 1);
          if (k < 0.4) g += 7 * (1 - k / 0.4); // усиление низких частот
        }
        await p.bands[i].setGain(g.clamp(p.minDecibels, p.maxDecibels).toDouble());
      }
    } catch (_) {}
  }
}
