import 'package:flutter/material.dart';
import 'audio/music_handler.dart';

late MusicHandler handler;
final messengerKey = GlobalKey<ScaffoldMessengerState>();

void toast(String m) => messengerKey.currentState
  ?..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

String fmt(Duration d) {
  final m = d.inMinutes, s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
