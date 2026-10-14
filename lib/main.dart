import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'audio/music_handler.dart';
import 'services/library_service.dart';
import 'services/settings.dart';
import 'ui/pages.dart';
import 'ui/player_page.dart';
import 'ui/widgets.dart';
import 'util.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.i.init();
  await Library.i.init();
  handler = await AudioService.init(
    builder: () => MusicHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.musichub.audio',
      androidNotificationChannelName: 'MusicHub',
      androidNotificationOngoing: true,
    ),
  );
  runApp(const MusicHubApp());
}

class MusicHubApp extends StatelessWidget {
  const MusicHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFB4C5FF);
    return MaterialApp(
      title: 'MusicHub',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0D),
        colorScheme: const ColorScheme.dark(primary: accent, surface: Color(0xFF0B0B0D)),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0B0B0D), elevation: 0),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: Color(0x22B4C5FF),
          elevation: 0,
        ),
        bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF16161A)),
        dialogBackgroundColor: const Color(0xFF16161A),
        popupMenuTheme: const PopupMenuThemeData(color: Color(0xFF1C1C21)),
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        body: IndexedStack(index: tab, children: const [SearchPage(), LibraryPage(), EqPage(), SettingsPage()]),
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          const MiniPlayer(),
          Glass(
            child: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.search), label: 'Поиск'),
                NavigationDestination(icon: Icon(Icons.library_music_outlined), label: 'Библиотека'),
                NavigationDestination(icon: Icon(Icons.equalizer), label: 'Эквалайзер'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Настройки'),
              ],
            ),
          ),
        ]),
      );
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
        stream: handler.mediaItem,
        builder: (c, snap) {
          final m = snap.data;
          if (m == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: GestureDetector(
              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const PlayerPage())),
              child: Glass(
                radius: 16,
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  Thumb(m.artUri, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(m.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    ]),
                  ),
                  StreamBuilder<PlaybackState>(
                    stream: handler.playbackState,
                    builder: (c, s) {
                      final playing = s.data?.playing ?? false;
                      return IconButton(
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        onPressed: playing ? handler.pause : handler.play,
                      );
                    },
                  ),
                  IconButton(icon: const Icon(Icons.skip_next), onPressed: handler.skipToNext),
                ]),
              ),
            ),
          );
        },
      );
}
