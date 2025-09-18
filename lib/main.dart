import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';   
import 'dart:io';                                    

import 'screens/united_screen.dart';
import 'localization/app_localizations.dart';
import 'services/aman/encrypted_asset_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // ← required on desktop

  // Télécharge le blob chiffré le plus récent (sans bloquer le démarrage)
  await pullLatestEncryptedAsset(); // ← ajout

  final dir = await getApplicationSupportDirectory();
  final file = File('${dir.path}/lst_rdo.aes');
  debugPrint('>>> AES file exists: ${file.existsSync()}');
  debugPrint('>>> AES file length: ${file.lengthSync()}');

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
                      final json = await decryptJson();
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