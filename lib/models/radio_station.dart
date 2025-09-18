// lib/models/radios_station.dart
class RadioStation {
  final String name;
  final String? code;
  final String? logo;
  final String? tag;
  final String? workingUrl; // URL valide trouvée
  final List<String>? allUrls; // toutes les URLs testées

  RadioStation({
    required this.name,
    this.code,
    this.logo,
    this.tag,
    this.workingUrl,
    this.allUrls,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    final allUrls = <String>[];
    for (int i = 1; i <= 12; i++) {
      final url = json['url$i'];
      if (url != null && url != 'null' && url is String && url.isNotEmpty) {
        allUrls.add(url);
      }
    }

    return RadioStation(
      name: json['name'] ?? 'Unknown',
      code: json['code'],
      logo: json['logo'],
      tag: json['tag'],
      workingUrl: null, // sera rempli après test
      allUrls: allUrls,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'logo': logo,
      'tag': tag,
      'workingUrl': workingUrl,
      'allUrls': allUrls,
    };
  }

  // Getters utiles
  String? get logoUrl => logo;
  String get countryCode => code ?? 'XX';
  String get url => workingUrl ?? allUrls?.firstOrNull ?? '';
}