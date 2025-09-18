//lib/services/radio_sources.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import '../models/radio_station.dart';

/* ----------------------------------------------------------
   1. Source GitHub brute (Midea3)
---------------------------------------------------------- */
class Midea3GitHubSource {
  static const String _url =
      'https://raw.githubusercontent.com/Rabie-Hood/rdo/main/lst_rdo.json';

  Future<List<RadioStation>> fetchByCountry(String countryCode) async {
    try {
      final resp = await http.get(Uri.parse(_url));
      if (resp.statusCode != 200) return [];

      final List<dynamic> data = json.decode(resp.body);
      return data
          .map((e) => RadioStation.fromJson(e))
          .where((s) => (s.code ?? '').toUpperCase() == countryCode.toUpperCase())
          .toList();
    } catch (_) {
      return [];
    }
  }
}

/* ----------------------------------------------------------
   2. Scraper radio.co.XX
---------------------------------------------------------- */
class RadioCoScraper {
  static Future<List<RadioStation>> scrapeCountry(String code) async {
    final homeUrl = 'https://radio.co.${code.toLowerCase()}';
    try {
      final resp = await http.get(Uri.parse(homeUrl));
      if (resp.statusCode != 200) return [];

      final doc = parse(resp.body);
      final anchors = doc.querySelectorAll('a[href^="#"]');
      final keys = anchors
          .map((e) => e.attributes['href']?.substring(1))
          .where((h) => h != null && h.isNotEmpty)
          .cast<String>()
          .toSet();

      final futures = keys.map((k) => _scrapeStation(code, k));
      final results = await Future.wait(futures);
      return results.whereType<RadioStation>().toList();
    } catch (_) {
      return [];
    }
  }

  static Future<RadioStation?> _scrapeStation(String code, String key) async {
    final sectionUrl = 'https://radio.co.${code.toLowerCase()}#$key';
    try {
      final resp = await http.get(Uri.parse(sectionUrl));
      if (resp.statusCode != 200) return null;

      final doc = parse(resp.body);
      final nameEl  = doc.querySelector('.station-name');
      final script  = doc.querySelector('script')?.text ?? '';
      final logoEl  = doc.querySelector('.station-logo');

      if (nameEl == null || logoEl == null) return null;

      final name     = nameEl.text.trim();
      final logo     = logoEl.attributes['src'] ?? '';
      final streamMatch = RegExp(r'https://stream\.rcast\.net/\d+').firstMatch(script);
      final streamUrl = streamMatch?.group(0);

      if (streamUrl == null) return null;

      return RadioStation(
        name: name,
        code: code.toUpperCase(),
        logo: logo,
        workingUrl: streamUrl,
      );
    } catch (_) {
      return null;
    }
  }
}

/* ----------------------------------------------------------
   3. Egypte spécifique
---------------------------------------------------------- */
class EgyptRadioScraper {
  static Future<List<RadioStation>> scrapeEgypt() async {
    const homeUrl = 'https://egyptradio.net/';
    try {
      final resp = await http.get(Uri.parse(homeUrl));
      if (resp.statusCode != 200) return [];

      final doc = parse(resp.body);
      final stations = doc.querySelectorAll('a.station');

      return stations.map((el) {
        final name   = el.attributes['data-name'] ?? 'Egypt Station';
        final relUrl = el.attributes['href']      ?? '';
        final logo   = el.attributes['data-logo'] ?? '';
        final playerUrl = 'https://egyptradio.net$relUrl';
        final logoUrl   = logo.startsWith('http') ? logo : 'https://egyptradio.net$logo';

        return RadioStation(
          name: name,
          code: 'EG',
          logo: logoUrl,
          workingUrl: playerUrl,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

/* ----------------------------------------------------------
   4. Orchestrateur unique (AUCUNE dé-duplication)
---------------------------------------------------------- */
class RadioSourceManager {
  Future<List<RadioStation>> getAllByCountry(String code) async {
    code = code.toUpperCase();
    final out = <RadioStation>[];

    // 1. JSON GitHub
    out.addAll(await Midea3GitHubSource().fetchByCountry(code));

    // 2. radio.co.XX
    out.addAll(await RadioCoScraper.scrapeCountry(code));

    // 3. Egypte uniquement
    if (code == 'EG') out.addAll(await EgyptRadioScraper.scrapeEgypt());

    // ❌ AUCUN filtre « seen » → on renvoie la liste brute
    return out;
  }
}