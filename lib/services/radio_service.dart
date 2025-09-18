// lib/services/radio_service.dart
import 'dart:convert';
import 'dart:developer' as dev; // ← pour debugPrint
import 'package:radio_app/services/aman/encrypted_asset_loader.dart'; // decryptJson
import '../models/radio_station.dart';
import 'radio_sources.dart'; // gardé pour compatibilité

/// Facade sans vérification d'URL : TOUTES les stations sont considérées vivantes
class RadioService {
  final _manager = RadioSourceManager();

  /* 1. Liste brute (depuis asset chiffré) */
  Future<List<RadioStation>> fetchRadiosByCountry(String countryCode) async {
    try {
      final jsonStr = await decryptJson();
      final data = jsonDecode(jsonStr) as List;
      return data
          .map((e) => RadioStation.fromJson(e))
          .where((s) => (s.code ?? '').toUpperCase() == countryCode.toUpperCase())
          .toList();
    } catch (e, s) {
      dev.log('>>> fetchRadiosByCountry ERROR: $e\n$s'); // ← trace
      rethrow; // pour que l’écran affiche le SnackBar
    }
  }

  /* 2. Liste « vivante » → on retourne TOUTES les stations dont l'URL n'est pas vide */
  Future<List<RadioStation>> fetchRadiosByCountryAliveOnly(String countryCode) async {
    final all = await fetchRadiosByCountry(countryCode);
    return all.where((r) => r.url.isNotEmpty).toList();
  }

  /* 3. isUrlAlive : toujours vrai (pour compatibilité si autre widget l'appelle) */
  Future<bool> isUrlAlive(String url, String countryCode) async => true;

  /* 4. Reset cache (inutile ici, mais gardé pour ne pas casser l'appel) */
  static void clearDeadCacheFor(String countryCode) {}
}