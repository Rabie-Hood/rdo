import 'dart:convert';
import 'package:flutter/material.dart'; // Pour Locale, BuildContext, LocalizationsDelegate
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // Méthode statique pour accéder à l'instance de localisation depuis le contexte
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // Map contenant les traductions chargées
  late Map<String, String> _localizedStrings;

  // Charge les traductions depuis le fichier JSON correspondant à la langue
  Future<void> load() async {
    try {
      // Charge le fichier JSON en fonction de la langue (ex: 'lib/localization/en.json')
      final jsonString = await rootBundle.loadString('lib/localization/${locale.languageCode}.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);

      // Convertit la map dynamique en map de type <String, String>
      _localizedStrings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      // En cas d'erreur, initialisez une map vide ou affichez un message
      _localizedStrings = {};
      print('Error loading localization file: $e');
    }
  }

  // Traduit une clé donnée en texte dans la langue actuelle
  String translate(String key) {
    return _localizedStrings[key] ?? key; // Retourne la clé elle-même si la traduction n'est pas trouvée
  }
}

// Délégué pour charger les localisations
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  // Liste des langues prises en charge
  @override
  bool isSupported(Locale locale) {
    return ['en', 'fr', 'es', 'ar'].contains(locale.languageCode);
  }

  // Charge les localisations pour une langue donnée
  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load(); // Charge les traductions
    return localizations;
  }

  // Indique si les localisations doivent être rechargées lorsqu'elles changent
  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}