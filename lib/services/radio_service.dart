// lib/services/radio_service.dart
// REMARQUES (inchangées) :
// 1. Clé obfusquée 32 caractères exacts
// 2. Télécharge le dernier AES depuis GitHub
// 3. Lit le blob (local ou asset) → déchiffre
// -------------------------------------------------

import 'dart:convert';
import 'dart:developer' as dev; // ← pour debugPrint
import 'package:radio_app/services/aman/encrypted_asset_loader.dart'; // decryptJson
import '../models/radio_station.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Facade sans vérification d'URL : TOUTES les stations sont considérées vivantes
class RadioService {
  /* 1. Liste brute (depuis asset chiffré LOCAL UNIQUEMENT) */
  Future<List<RadioStation>> fetchRadiosByCountry(String countryCode) async {
    try {
      final jsonStr = await EncryptedAssetLoader.decryptJson(); // ← avec classe
      final data = jsonDecode(jsonStr) as List;
      return data
          .map((e) => RadioStation.fromJson(e))
          .where((s) {
            final code = (s.code ?? '').trim().toUpperCase();
            return code == countryCode.toUpperCase();
            })
          .toList();
    } catch (e, s) {
      dev.log('>>> fetchRadiosByCountry ERROR: $e\n$s');
      rethrow; // pour SnackBar
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