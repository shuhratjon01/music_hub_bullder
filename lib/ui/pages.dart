import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/settings.dart';
import '../services/yt_service.dart';
import '../util.dart';
import 'widgets.dart';

const _pad = EdgeInsets.only(bottom: 170);

// ------------------------------------------------------------ Поиск
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Track> results = [];
  bool loading = false;
  String? error;

  Future<void> _go(String q) async {
    if (q.trim().isEmpty) return;
    setState(() { loading = true; error = null; });
    try {
      results = await YtService.i.search(q);
    } catch (_) {
      error = 'Не удалось выполнить поиск. Проверьте подключение.';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              textInputAction: TextInputAction.search,
              onSubmitted: _go,
              decoration: InputDecoration(
                hintText: 'Поиск музыки',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF16161A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Text(error!, style: const TextStyle(color: Colors.white54)))
                    : results.isEmpty
                        ? Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.asset('assets/cover/cover.png', width: 120)),
                              const SizedBox(height: 16),
                              const Text('MusicHub', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              const Text('Найдите трек и скачайте его',
                                  style: TextStyle(color: Colors.white54)),
                            ]),
                          )
                        : ListView.builder(
                            padding: _pad,
                            itemCount: results.length,
                            itemBuilder: (_, i) => TrackTile(results, i)),
          ),
        ]),
      );
}

// ------------------------------------------------------------ Библиотека
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(children: [
            const TabBar(tabs: [Tab(text: 'Скачанное'), Tab(text: 'Плейлисты')]),
            Expanded(
              child: ListenableBuilder(
                listenable: Library.i,
                builder: (c, _) {
                  final dl = Library.i.downloaded;
                  final pls = Library.i.playlists.keys.toList();
                  return TabBarView(children: [
                    dl.isEmpty
                        ? const Center(child: Text('Нет скачанных треков', style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            padding: _pad,
                            itemCount: dl.length,
                            itemBuilder: (_, i) => TrackTile(dl, i)),
                    ListView(padding: _pad, children: [
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Новый плейлист'),
                        onTap: () async {
                          final n = await askText(c, 'Название плейлиста');
                          if (n != null && n.isNotEmpty) Library.i.createPlaylist(n);
                        },
                      ),
                      for (final n in pls)
                        ListTile(
                          leading: const Icon(Icons.queue_music),
                          title: Text(n),
                          subtitle: Text('${Library.i.playlists[n]!.length} треков',
                              style: const TextStyle(color: Colors.white54)),
                          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => PlaylistPage(n))),
                        ),
                    ]),
                  ]);
                },
              ),
            ),
          ]),
        ),
      );
}

class PlaylistPage extends StatelessWidget {
  const PlaylistPage(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(name), actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Library.i.deletePlaylist(name);
              Navigator.pop(context);
            },
          ),
        ]),
        body: ListenableBuilder(
          listenable: Library.i,
          builder: (_, __) {
            final l = Library.i.playlistTracks(name);
            if (l.isEmpty) {
              return const Center(child: Text('Плейлист пуст', style: TextStyle(color: Colors.white54)));
            }
            return ListView.builder(
              itemCount: l.length,
              itemBuilder: (_, i) => Dismissible(
                key: ValueKey(l[i].id),
                direction: DismissDirection.endToStart,
                background: Container(
                    color: Colors.red.shade900,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete)),
                onDismissed: (_) => Library.i.removeFromPlaylist(name, l[i].id),
                child: TrackTile(l, i),
              ),
            );
          },
        ),
      );
}

// ------------------------------------------------------------ Эквалайзер
class EqPage extends StatelessWidget {
  const EqPage({super.key});
  static const labels = ['60 Гц', '230 Гц', '910 Гц', '3,6 кГц', '14 кГц'];

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListenableBuilder(
          listenable: Settings.i,
          builder: (c, _) {
            final s = Settings.i;
            return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 170), children: [
              const Text('Эквалайзер', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Включить эквалайзер'),
                value: s.eqOn,
                onChanged: (v) { s.update(() => s.eqOn = v); handler.applyEq(); },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bass Boost'),
                subtitle: const Text('Усиление низких частот', style: TextStyle(color: Colors.white54)),
                value: s.bass,
                onChanged: (v) { s.update(() => s.bass = v); handler.applyEq(); },
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final k in eqPresets.keys)
                  ChoiceChip(
                    label: Text(k),
                    selected: s.preset == k,
                    onSelected: (_) {
                      s.update(() { s.preset = k; s.gains = List.of(eqPresets[k]!); s.eqOn = true; });
                      handler.applyEq();
                    },
                  ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                height: 280,
                child: Row(children: [
                  for (var i = 0; i < 5; i++)
                    Expanded(
                      child: Column(children: [
                        Text('${s.gains[i].round()} дБ', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              min: -12,
                              max: 12,
                              value: s.gains[i],
                              onChanged: s.eqOn
                                  ? (v) { s.update(() { s.gains[i] = v; s.preset = 'Свой'; }); handler.applyEq(); }
                                  : null,
                            ),
                          ),
                        ),
                        Text(labels[i], style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                ]),
              ),
            ]);
          },
        ),
      );
}

// ------------------------------------------------------------ Настройки
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListenableBuilder(
          listenable: Settings.i,
          builder: (c, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 170), children: [
            const Text('Настройки', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Эффект «жидкого стекла»'),
              subtitle: const Text('Выключите, чтобы снизить нагрузку на слабых устройствах',
                  style: TextStyle(color: Colors.white54)),
              value: Settings.i.glass,
              onChanged: (v) => Settings.i.update(() => Settings.i.glass = v),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Удалить все загрузки'),
              onTap: () async {
                for (final t in Library.i.downloaded) {
                  await Library.i.removeDownload(t.id);
                }
                toast('Загрузки удалены');
              },
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline),
              title: Text('MusicHub 1.0.0'),
            ),
          ]),
        ),
      );
}
