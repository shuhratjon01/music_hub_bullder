import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/settings.dart';
import '../util.dart';

/// Стеклянная панель. Если эффект выключен в настройках — BackdropFilter
/// не создаётся вообще, рисуется обычный непрозрачный контейнер.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 0, this.padding});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Settings.i,
        builder: (_, __) {
          final br = BorderRadius.circular(radius);
          if (!Settings.i.glass) {
            return Container(
              padding: padding,
              decoration: BoxDecoration(
                color: const Color(0xFF16161A),
                borderRadius: br,
                border: Border.all(color: const Color(0x14FFFFFF)),
              ),
              child: child,
            );
          }
          return ClipRRect(
            borderRadius: br,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: const Color(0x66121216),
                  borderRadius: br,
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: child,
              ),
            ),
          );
        },
      );
}

class Thumb extends StatelessWidget {
  const Thumb(this.uri, {super.key, this.size, this.radius = 8});
  final Uri? uri;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFF1E1E24),
      child: const Center(child: Icon(Icons.music_note, color: Colors.white24)),
    );
    Widget img = fallback;
    final u = uri;
    if (u != null) {
      img = u.isScheme('file')
          ? Image.file(File(u.toFilePath()), fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
          : Image.network(u.toString(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: img),
    );
  }
}

class DownloadButton extends StatelessWidget {
  const DownloadButton(this.track, {super.key});
  final Track track;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Library.i, Library.i.progress]),
        builder: (c, _) {
          final p = Library.i.progress.value[track.id];
          if (p != null) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ).withProgress(p);
          }
          if (Library.i.isDownloaded(track.id)) {
            return const IconButton(onPressed: null, icon: Icon(Icons.download_done, color: Color(0xFFB4C5FF)));
          }
          return IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () async {
              toast('Загрузка: ${track.title}');
              final ok = await Library.i.download(track);
              toast(ok ? 'Скачано' : 'Ошибка загрузки');
            },
          );
        },
      );
}

extension on Padding {
  Widget withProgress(double p) => Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, value: p == 0 ? null : p),
        ),
      );
}

class TrackTile extends StatelessWidget {
  const TrackTile(this.tracks, this.index, {super.key});
  final List<Track> tracks;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = tracks[index];
    return ListTile(
      onTap: () => handler.playQueue(tracks, index),
      leading: Thumb(t.art, size: 48),
      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        DownloadButton(t),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'pl') addToPlaylist(context, t);
            if (v == 'rm') Library.i.removeDownload(t.id);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'pl', child: Text('Добавить в плейлист')),
            if (Library.i.isDownloaded(t.id)) const PopupMenuItem(value: 'rm', child: Text('Удалить загрузку')),
          ],
        ),
      ]),
    );
  }
}

Future<String?> askText(BuildContext c, String title, {String hint = '', bool number = false}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Отмена')),
        TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('OK')),
      ],
    ),
  );
}

void addToPlaylist(BuildContext context, Track t) {
  showModalBottomSheet(
    context: context,
    builder: (sheet) => SafeArea(
      child: ListenableBuilder(
        listenable: Library.i,
        builder: (_, __) => ListView(shrinkWrap: true, children: [
          for (final name in Library.i.playlists.keys)
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(name),
              onTap: () {
                Library.i.addToPlaylist(name, t);
                Navigator.pop(sheet);
                toast('Добавлено в «$name»');
              },
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Новый плейлист'),
            onTap: () async {
              final n = await askText(sheet, 'Название плейлиста');
              if (n != null && n.isNotEmpty) {
                Library.i.addToPlaylist(n, t);
                if (sheet.mounted) Navigator.pop(sheet);
              }
            },
          ),
        ]),
      ),
    ),
  );
}
