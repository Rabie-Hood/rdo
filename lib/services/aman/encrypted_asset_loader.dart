// lib/services/aman/encrypted_asset_loader.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class EncryptedAssetLoader {
  /* ==========================================
     1.  Clé obfusquée (32 caractères exacts)
     ========================================== */
  static String _obfKey() {
    final parts = ['MyVery', 'Long32', 'BytesSecret', 'Key123456'];
    return parts.join(); // 32 bytes
  }

  /* ==========================================
     2.  Télécharge le dernier AES depuis GitHub
     ========================================== */
  static Future<bool> pullLatestEncryptedAsset() async {
    const url = 'https://raw.githubusercontent.com/Rabie-Hood/rdo/main/assets/lst_rdo.aes';
    
    try {
      print('📥 Téléchargement des données radio...');
      final resp = await http.get(Uri.parse(url));
      
      if (resp.statusCode != 200) {
        print('❌ Erreur HTTP ${resp.statusCode}');
        return false;
      }

      final dir = await getApplicationSupportDirectory();
      final file = File(join(dir.path, 'lst_rdo.aes'));

      await file.writeAsBytes(resp.bodyBytes, flush: true);
      print('✅ Données mises à jour (${resp.bodyBytes.length} bytes)');
      return true;
      
    } catch (e) {
      print('❌ Erreur lors du téléchargement: $e');
      return false;
    }
  }

  /* ==========================================
     3.  Vérifie si une mise à jour est nécessaire
     ========================================== */
  static Future<bool> needsUpdate() async {
    try {
      // Récupérer les infos du fichier distant
      const url = 'https://api.github.com/repos/Rabie-Hood/rdo/commits?path=assets/lst_rdo.aes&page=1&per_page=1';
      final resp = await http.get(Uri.parse(url));
      
      if (resp.statusCode != 200) return false;
      
      final commits = jsonDecode(resp.body);
      if (commits.isEmpty) return false;
      
      final remoteDate = DateTime.parse(commits[0]['commit']['committer']['date']);
      
      // Comparer avec la date locale
      final dir = await getApplicationSupportDirectory();
      final file = File(join(dir.path, 'lst_rdo.aes'));
      
      if (!await file.exists()) return true;
      
      final localDate = await file.lastModified();
      return remoteDate.isAfter(localDate);
      
    } catch (e) {
      print('⚠️  Impossible de vérifier les mises à jour: $e');
      return false;
    }
  }

  /* ==========================================
     4.  Lit le blob (local ou asset) → déchiffre
     ========================================== */
  static Future<List<int>> _loadEncrypted() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(join(dir.path, 'lst_rdo.aes'));

    if (await file.exists()) {
      print('📁 Utilisation du fichier local');
      return file.readAsBytes();
    }

    print('📁 Utilisation du fichier asset');
    final blob = await rootBundle.load('assets/lst_rdo.aes');
    return blob.buffer.asUint8List();
  }

  /* ==========================================
     5.  Déchiffre et retourne le JSON
     ========================================== */
  static Future<List<dynamic>> loadRadioStations() async {
    try {
      final data = await _loadEncrypted();
      print('🔐 Déchiffrement de ${data.length} bytes...');
      
      final iv = IV(Uint8List.fromList(data.sublist(0, 12)));
      final cipher = Encrypted(Uint8List.fromList(data.sublist(12)));
      final key = Key.fromUtf8(_obfKey());
      final enc = Encrypter(AES(key, mode: AESMode.gcm));

      final plain = enc.decrypt(cipher, iv: iv);
      final jsonData = jsonDecode(plain);
      
      print('✅ ${jsonData.length} stations chargées');
      return jsonData;
      
    } catch (e) {
      print('❌ Erreur de déchiffrement: $e');
      return []; // Retourne liste vide en cas d'erreur
    }
  }

  /* ==========================================
   6.  Facade : déchiffre → JSON brut (String)
   ========================================== */
  static Future<String> decryptJson() async {
  try {
    final data = await _loadEncrypted();
    final iv     = IV(Uint8List.fromList(data.sublist(0, 12)));
    final cipher = Encrypted(Uint8List.fromList(data.sublist(12)));
    final key    = Key.fromUtf8(_obfKey());
    final enc    = Encrypter(AES(key, mode: AESMode.gcm));

    final plain = enc.decrypt(cipher, iv: iv);
    return plain; // ← String JSON brut
  } catch (e) {
    print('❌ decryptJson error : $e');
    return '[]'; // JSON vide en cas d’échec
  }
  }

}