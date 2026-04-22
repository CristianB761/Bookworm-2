import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _temaKey = 'tema_app';
  bool _esModoOscuro = false;

  ThemeProvider() {
    _cargarTema();
  }

  bool get esModoOscuro => _esModoOscuro;
  ThemeMode get themeMode => _esModoOscuro ? ThemeMode.dark : ThemeMode.light;

  Future<void> _cargarTema() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _esModoOscuro = prefs.getBool(_temaKey) ?? false;
      notifyListeners();
    } catch (e) {
    }
  }

  Future<void> alternarTema() async {
    _esModoOscuro = !_esModoOscuro;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_temaKey, _esModoOscuro);
    } catch (e) {
    }
    notifyListeners();
  }
}