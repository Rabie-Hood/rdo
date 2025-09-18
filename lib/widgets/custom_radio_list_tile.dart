//lib/widgets/custom_radio_list_tile.dart
import 'package:flutter/material.dart';
import '../models/radio_station.dart';

class CustomRadioListTile extends StatelessWidget {
  final RadioStation radio;
  final VoidCallback onTap;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final bool isOffline;

  const CustomRadioListTile({
    Key? key,
    required this.radio,
    required this.onTap,
    this.isPlaying = false,
    this.isFavorite = false,
    required this.onFavorite,
    this.isOffline = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: isOffline ? null : onTap, // désactive le tap si morte
      leading: CircleAvatar(
        backgroundImage: radio.logoUrl != null && radio.logoUrl!.isNotEmpty
              ? NetworkImage(radio.logoUrl!)
              : const AssetImage('assets/default_logo.png') as ImageProvider,
        backgroundColor: Colors.grey[300],
        radius: 20,
      ),
      title: Text(
        radio.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isOffline ? Colors.grey : null,
        ),
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(radio.countryCode),
          if (isOffline) ...[
            const SizedBox(width: 6),
            const Icon(Icons.wifi_off, size: 14, color: Colors.grey),
            const Text('  hors ligne', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlaying) const AnimatedEqualizer(),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isOffline ? Colors.grey[400] : Colors.red,
            ),
            onPressed: isOffline ? null : onFavorite,
          ),
        ],
      ),
    );
  }
}

/// Égaliseur animé pour indiquer la lecture en cours
class AnimatedEqualizer extends StatefulWidget {
  const AnimatedEqualizer({Key? key}) : super(key: key);

  @override
  _AnimatedEqualizerState createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (i) {
              final height =
                  4 + (i % 2 == 0 ? _controller.value : 1 - _controller.value) * 8;
              return Container(
                width: 4,
                height: height,
                color: Colors.green,
              );
            }),
          );
        },
      ),
    );
  }
}