import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const eqPresets = <String, List<double>>{
  'Плоский': [0, 0, 0, 0, 0],
  'Рок': [5, 3, -2, 3, 5],
  'Поп': [-1, 2, 4, 2, -1],
  'Хип-хоп': [6, 4, 0, 1, 3],
  'Джаз': [3, 2, -2, 2, 4],
  'Классика': [4, 3, -2, 3, 4],
  'Электроника': [5, 3, 0, 2, 5],
  'Вокал': [-2, 0, 4, 3, 1],
  'Басс-буст': [8, 6, 2, 0, 0],
};

class Settings extends ChangeNotifier {
  static final i = Settings._();
  Settings._();
  late SharedPreferences _p;

  bool glass = true, eqOn = false, bass = false;
  String preset = 'Плоский';
  List<double> gains = List.filled(5, 0.0);

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    glass = _p.getBool('glass') ?? true;
    eqOn = _p.getBool('eqOn') ?? false;
    bass = _p.getBool('bass') ?? false;
    preset = _p.getString('preset') ?? 'Плоский';
    final g = (_p.getStringList('gains') ?? []).map(double.parse).toList();
    if (g.length == 5) gains = g;
  }

  void update(void Function() change) {
    change();
    _p.setBool('glass', glass);
    _p.setBool('eqOn', eqOn);
    _p.setBool('bass', bass);
    _p.setString('preset', preset);
    _p.setStringList('gains', gains.map((e) => e.toString()).toList());
    notifyListeners();
  }
}
