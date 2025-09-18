import 'package:shared_preferences/shared_preferences.dart';
import '../models/radio_station.dart';
import 'dart:convert';

class FavoritesService {
  static const _key = 'favorites';

  Future<List<RadioStation>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((e) => RadioStation.fromJson(jsonDecode(e))).toList();
  }

  Future<void> toggleFavorite(RadioStation radio) async {
    final favs = await getFavorites();
    final exists = favs.any((r) => r.name == radio.name);
    if (exists) {
      favs.removeWhere((r) => r.name == radio.name);
    } else {
      favs.add(radio);
    }
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
        _key, favs.map((e) => jsonEncode(e.toJson())).toList());
  }
}