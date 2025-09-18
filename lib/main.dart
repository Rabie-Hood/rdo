// lib/main.dart
// REMARQUES (inchangées) :
// 1. Clé obfusquée 32 caractères exacts
// 2. Télécharge le dernier AES depuis GitHub
// 3. Lit le blob (local ou asset) → déchiffre
// -------------------------------------------------

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import 'screens/united_screen.dart';
import 'localization/app_localizations.dart';
import 'services/aman/encrypted_asset_loader.dart'; // ← import unique

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // ← required on desktop

  // Télécharge le blob chiffré le plus récent (sans bloquer le démarrage)
  await EncryptedAssetLoader.pullLatestEncryptedAsset(); // ← appel avec classe

  //********************* */
  final raw = await rootBundle.loadString('assets/countries.json');
  final list = jsonDecode(raw) as List;
  final fr = list.firstWhere((e) => e['code'] == 'FR');
  print('>>> FR flag URL : "${fr['flag']}"');
  print('>>> URL length : ${fr['flag'].length}');
  //**** */
  final dir = await getApplicationSupportDirectory();
  final file = File('${dir.path}/lst_rdo.aes');
  debugPrint('1- >>> AES file exists: ${file.existsSync()}');
  if (file.existsSync()) {
    debugPrint('2- >>> AES file length: ${file.lengthSync()}');
  } else {
    debugPrint('2- >>> AES file MISSING – will try asset or download');
  }

  final json = await EncryptedAssetLoader.decryptJson(); // ← appel avec classe
  final list1 = jsonDecode(json) as List;
  debugPrint('3- >>> TOTAL stations after decrypt = ${list1.length}');
  // détail de la première (et unique) station
  if (list.isNotEmpty) {
    final s = list.first;
    debugPrint('>>> station 0 name   = ${s['name']}');
    debugPrint('>>> station 0 code   = ${s['code']}');
    debugPrint('>>> station 0 code runtime type = ${s['code'].runtimeType}');
  }
  //*************************************

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'World Radio Live',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true), // <-- LIGHT

      supportedLocales: const [
        Locale('en', ''), // Anglais
        Locale('fr', ''), // Français
        Locale('es', ''), // Espagnol
        Locale('ar', ''), // Arabe
      ],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
      home: const _DebugWrapper(child: UnScreen()), // ← wrap temporaire
    );
  }
}

/* ----------------------------------------------------------
   Widget temporaire : bouton « Test decrypt » en haut à droite
   ---------------------------------------------------------- */
class _DebugWrapper extends StatelessWidget {
  final Widget child;
  const _DebugWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          child,
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final json = await EncryptedAssetLoader.decryptJson(); // ← classe
                      final list = jsonDecode(json) as List;
                      debugPrint('>>> JSON OK – ${list.length} stations');
                    } catch (e, s) {
                      debugPrint('>>> DECRYPT ERROR: $e\n$s');
                    }
                  },
                  child: const Text('Test decrypt'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}