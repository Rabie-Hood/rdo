import 'package:mysql1/mysql1.dart';

class DatabaseService {
  static Future<MySqlConnection> _connect() async {
    final settings = ConnectionSettings(
      host: 'YOUR_GOOGLE_CLOUD_SQL_IP', // Remplacez par l'IP ou le nom d'hôte de votre base de données
      port: 3306, // Port MySQL par défaut
      user: 'YOUR_DB_USER', // Nom d'utilisateur de la base de données
      password: 'YOUR_DB_PASSWORD', // Mot de passe de la base de données
      db: 'YOUR_DB_NAME', // Nom de la base de données
    );

    return await MySqlConnection.connect(settings);
  }

  // Méthode pour récupérer une publicité aléatoire depuis la base de données
  static Future<Map<String, String>> fetchRandomAd() async {
    final conn = await _connect();

    try {
      final results = await conn.query('SELECT ad_text, ad_image_url FROM ads ORDER BY RAND() LIMIT 1');
      if (results.isNotEmpty) {
        final row = results.first;
        return {
          'adText': row['ad_text'],
          'adImageUrl': row['ad_image_url'],
        };
      } else {
        return {
          'adText': 'Default Ad Text',
          'adImageUrl': '', // URL vide si aucune image n'est disponible
        };
      }
    } catch (e) {
      print('Error fetching ad from database: $e');
      return {
        'adText': 'Default Ad Text',
        'adImageUrl': '',
      };
    } finally {
      await conn.close();
    }
  }

  // Méthode pour insérer une nouvelle publicité dans la base de données
  static Future<void> insertAd(String adText, String adImageUrl) async {
    final conn = await _connect();

    try {
      await conn.query(
        'INSERT INTO ads (ad_text, ad_image_url) VALUES (?, ?)',
        [adText, adImageUrl],
      );
    } catch (e) {
      print('Error inserting ad into database: $e');
    } finally {
      await conn.close();
    }
  }

  // Méthode pour supprimer une publicité par ID
  static Future<void> deleteAd(int adId) async {
    final conn = await _connect();

    try {
      await conn.query('DELETE FROM ads WHERE id = ?', [adId]);
    } catch (e) {
      print('Error deleting ad from database: $e');
    } finally {
      await conn.close();
    }
  }
}