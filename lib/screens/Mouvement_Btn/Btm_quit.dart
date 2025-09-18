// lib/screens/Mouvement_Btn/Btm_quit.dart
// Bouton flèche « ← » qui **quitte l’application** en un clic.
// Compatible : iOS, Android, Windows, Linux, macOS, Web.

import 'package:flutter/foundation.dart';   // kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// dart:io uniquement importé si NON web (évite erreur compilation Web)
import 'dart:io' if (kIsWeb) '';

class BtmQuit extends StatelessWidget {
  final Color? color;
  const BtmQuit({Key? key, this.color}) : super(key: key);

  ////*******
  // Fonction qui **tue** l’application (Android & iOS)
  Future<void> _quitHard() async {
    if (kIsWeb) return;

    // Channel natif
    const channel = MethodChannel('hard_exit');
    await channel.invokeMethod('quit');
  }
  ////*******

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back_ios_new, color: color),

      onPressed: () async { // ← ajoute async
        if (kIsWeb) {
          Navigator.of(context).maybePop();
          return;
        }
        if (Platform.isAndroid || Platform.isIOS) {
          // Pas besoin d’await ici, le canal natif est synchrone
          await _quitHard(); // VRAIE fermeture
        } else {
          exit(0); // Desktop
        }
      },
    );
  }
}