import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../util.dart';
import 'pages.dart';
import 'widgets.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  double? _drag;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => Navigator.pop(context)),
          title: const Text('Сейчас играет', style: TextStyle(fontSize: 14, color: Colors.white54)),
          centerTitle: true,
        ),
        body: StreamBuilder<MediaItem?>(
          stream: handler.mediaItem,
          builder: (c, snap) {
            final m = snap.data;
            if (m == null) return const Center(child: Text('Ничего не играет'));
            final dur = m.duration ?? Duration.zero;
            final mx = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(children: [
                Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: Thumb(m.artUri, radius: 20)))),
                const SizedBox(height: 24),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(m.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(m.artist ?? '', style: const TextStyle(color: Colors.white54))),
                StreamBuilder<Duration>(
                  stream: handler.player.positionStream,
                  builder: (c, s) {
                    final pos = s.data ?? Duration.zero;
                    final v = _drag ?? pos.inMilliseconds.toDouble().clamp(0.0, mx).toDouble();
                    return Column(children: [
                      Slider(
                        value: v,
                        max: mx,
                        onChanged: (x) => setState(() => _drag = x),
                        onChangeEnd: (x) {
                          handler.seek(Duration(milliseconds: x.round()));
                          setState(() => _drag = null);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(fmt(Duration(milliseconds: v.round())), style: const TextStyle(fontSize: 12, color: Colors.white54)),
                          Text(fmt(dur), style: const TextStyle(fontSize: 12, color: Colors.white54)),
                        ]),
                      ),
                    ]);
                  },
                ),
                StreamBuilder<PlaybackState>(
                  stream: handler.playbackState,
                  builder: (c, s) {
                    final st = s.data;
                    final playing = st?.playing ?? false;
                    final busy = st?.processingState == AudioProcessingState.loading ||
                        st?.processingState == AudioProcessingState.buffering;
                    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(iconSize: 36, icon: const Icon(Icons.skip_previous), onPressed: handler.skipToPrevious),
                      const SizedBox(width: 12),
                      busy
                          ? const SizedBox(width: 72, height: 72, child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                          : IconButton.filled(
                              iconSize: 40,
                              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                              onPressed: playing ? handler.pause : handler.play),
                      const SizedBox(width: 12),
                      IconButton(iconSize: 36, icon: const Icon(Icons.skip_next), onPressed: handler.skipToNext),
                    ]);
                  },
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  ValueListenableBuilder<Duration?>(
                    valueListenable: handler.sleepLeft,
                    builder: (c, left, _) => TextButton.icon(
                      icon: Icon(Icons.bedtime_outlined, color: left != null ? const Color(0xFFB4C5FF) : null),
                      label: Text(left == null ? 'Таймер сна' : fmt(left)),
                      onPressed: () => _sleepSheet(context),
                    ),
                  ),
                  DownloadButton(Library.i.tracks[m.id] ?? Track.fromItem(m)),
                  IconButton(
                    icon: const Icon(Icons.equalizer),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => Scaffold(appBar: AppBar(), body: const EqPage()))),
                  ),
                ]),
              ]),
            );
          },
        ),
      );

  void _sleepSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Таймер сна', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('За последние 2,5 минуты громкость плавно снижается до нуля.',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final min in [15, 30, 45, 60])
                ActionChip(
                  label: Text('$min мин'),
                  onPressed: () {
                    handler.startSleep(Duration(minutes: min));
                    Navigator.pop(sheet);
                    toast('Таймер сна: $min мин');
                  },
                ),
              ActionChip(
                avatar: const Icon(Icons.edit, size: 16),
                label: const Text('Своё время'),
                onPressed: () async {
                  final t = await askText(sheet, 'Минут до отключения', hint: 'Например, 90', number: true);
                  final n = int.tryParse(t ?? '');
                  if (n != null && n > 0) {
                    handler.startSleep(Duration(minutes: n));
                    if (sheet.mounted) Navigator.pop(sheet);
                    toast('Таймер сна: $n мин');
                  }
                },
              ),
              if (handler.sleepLeft.value != null)
                ActionChip(
                  avatar: const Icon(Icons.close, size: 16),
                  label: const Text('Отключить'),
                  onPressed: () {
                    handler.cancelSleep();
                    Navigator.pop(sheet);
                  },
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}
