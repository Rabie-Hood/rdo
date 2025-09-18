import 'package:flutter/material.dart';
import '../services/ad_service.dart';

class AdBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: AdService.fetchAdData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error loading ad'));
        } else {
          final adText = snapshot.data!['adText'];
          final adImageUrl = snapshot.data!['adImageUrl'];

          return Container(
            height: 100,
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(adText ?? 'Default Ad Text'),
                  ),
                ),
                if (adImageUrl != null)
                  Image.network(
                    adImageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
              ],
            ),
          );
        }
      },
    );
  }
}