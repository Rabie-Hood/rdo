import 'package:mysql1/mysql1.dart';

class AdService {
  static Future<Map<String, String>> fetchAdData() async {
    final settings = ConnectionSettings(
      host: 'YOUR_GOOGLE_CLOUD_SQL_IP',
      port: 3306,
      user: 'YOUR_DB_USER',
      password: 'YOUR_DB_PASSWORD',
      db: 'YOUR_DB_NAME',
    );

    final conn = await MySqlConnection.connect(settings);

    final results = await conn.query('SELECT ad_text, ad_image_url FROM ads ORDER BY RAND() LIMIT 1');
    final row = results.first;

    await conn.close();

    return {
      'adText': row['ad_text'],
      'adImageUrl': row['ad_image_url'],
    };
  }
}