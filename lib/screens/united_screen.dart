// lib/screens/united_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:media_kit/media_kit.dart'; // loop-back
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart'; // ← ajout
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import '../services/audio_recorder.dart';
import '../services/aman/encrypted_asset_loader.dart'; // ← ajout
import '../widgets/custom_radio_list_tile.dart';
import '../screens/Mouvement_Btn/Btm_quit.dart';

/// Icône animée « ondes » pour la radio active
class _AnimatedRadioIcon extends StatefulWidget {
  final bool isActive;
  const _AnimatedRadioIcon({required this.isActive});

  @override
  State<_AnimatedRadioIcon> createState() => _AnimatedRadioIconState();
}

class _AnimatedRadioIconState extends State<_AnimatedRadioIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox(width: 24);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        return Transform.scale(
          scale: _pulse.value,
          child: child,
        );
      },
      child: const Icon(Icons.wifi_tethering, color: Colors.blue, size: 24),
    );
  }
}

/* *************************************************************************
                              ÉCRAN PRINCIPAL
   ************************************************************************* */

class UnScreen extends StatefulWidget {
  const UnScreen({super.key});

  @override
  State<UnScreen> createState() => _UnScreenState();
}

class _UnScreenState extends State<UnScreen> {
  /* --------------------  PAYS  -------------------- */
  List<Map<String, String>> _countries = [];
  String? _selectedCountry;
  String? _selectedCountryCode;

  /* --------------------  STATIONS  -------------------- */
  final RadioService _service = RadioService();
  List<RadioStation> _stations = [];
  bool _loading = false;

  /* --------------------  AUDIO  -------------------- */
  final AudioPlayer _player = AudioPlayer();
  final Player _recorderPlayer = Player(); // loop-back carte son
  RadioStation? _current;
  bool _isPlaying = false;
  bool _isRecording = false;
  String? _recordPath;
  final Set<String> _favs = {};

  /* ========================================================= */
  /*                    INITIALISATION                         */
  /* ========================================================= */
  @override
  void initState() {
    super.initState();
    _loadCountries().then((_) => _selectSystemCountry());
    _loadFavs();
    _player.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    /* 🔒 Enregistrement tâche périodique (6 h) – existingWorkPolicy pour remplacer l’ancienne */
    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    Workmanager().registerPeriodicTask(
      'updateAES',
      'updateAES',
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _recorderPlayer.dispose();
    super.dispose();
  }

  /* ========================================================= */
  /*              PAYS PAR DÉFAUT (SYSTÈME)                    */
  /* ========================================================= */
  Future<void> _selectSystemCountry() async {
    final String systemCountry = Platform.localeName.split('_').last;
    final found = _countries.cast<Map<String, String>?>().firstWhere(
          (c) => c!['code'] == systemCountry,
          orElse: () => null,
        );
    final target = found ??
        _countries.cast<Map<String, String>?>().firstWhere(
              (c) => c!['code'] == 'MA',
              orElse: () => _countries.first,
            );
    if (target != null) {
      setState(() {
        _selectedCountry = target['name'];
        _selectedCountryCode = target['code'];
      });
      _loadStations();
    }
  }

  /* ========================================================= */
  /*                      PAYS  (JSON)                         */
  /* ========================================================= */
  Future<void> _loadCountries() async {
    final raw = await rootBundle.loadString('assets/countries.json');
    final list = (jsonDecode(raw) as List?)
        ?.whereType<Map<String, dynamic>>()
        .where((e) => e['name'] is String && e['code'] is String && e['flag'] is String)
        .toList();
    if (list == null) return;
    setState(() {
      _countries = list.map<Map<String, String>>((e) {
        return {'name': e['name'], 'code': e['code'], 'flag': e['flag']};
      }).toList();
    });
  }

  /* ========================================================= */
  /*                     STATIONS                              */
  /* ========================================================= */
  Future<void> _loadStations() async {
    if (_selectedCountryCode == null) return;
    setState(() => _loading = true);
    try {
      final list = await _service.fetchRadiosByCountry(_selectedCountryCode!);
      final seen = <String>{};
      final dedup = list.where((s) => seen.add(s.name.trim().toLowerCase())).toList();
      setState(() => _stations = dedup);
    } catch (_) {
      setState(() => _stations = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur de chargement des stations')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    //***
    debugPrint('>>> _selectedCountryCode = $_selectedCountryCode');
    //***
  }

  /* ========================================================= */
  /*                   LECTURE  RADIO                          */
  /* ========================================================= */
  Future<void> _play(RadioStation st) async {
    // 0. Coupe l'ancien flux avant tout (évite double lecture)
    await _player.stop();

    // 1. Même station : on toggle play/pause
    if (_current == st && _isPlaying) {
      await _player.pause();
      return;
    }
    
    // 2. Nouvelle station (ou pas en cours) : on charge et on joue
    await _player.setAudioSource(AudioSource.uri(Uri.parse(st.url)));

    // On met la station courante AVANT de jouer pour que L1 s’affiche tout de suite
    setState(() {
      _current = st;
    });

    await _player.play(); // démarre la lecture (déclenche playingStream)
  }

  void _toggleFav(RadioStation st) {
    setState(() {
      _favs.contains(st.name) ? _favs.remove(st.name) : _favs.add(st.name);
    });
    _saveFavs();
  }

  /* ========================================================= */
  /*         ENREGISTREMENT LOOP-BACK CARTE SON                */
  /* ========================================================= */
  final AudioRecorder _audioRecorder = AudioRecorder(); // notre classe

  Future<void> _toggleRecord() async {
    debugPrint('>>> _toggleRecord début - _current = $_current - _isRecording = $_isRecording');

    if (_current == null) {
      debugPrint('>>> _current null → on sort');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune station sélectionnée')),
      );
      return;
    }

    if (_isRecording) {
      debugPrint('>>> on STOPPE l’enregistrement');
      final path = await _audioRecorder.stop();
      debugPrint('>>> stop terminé, path = $path');

      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistrement terminé :\n$path') ),
      );
      return;
    }

    debugPrint('>>> on DÉMARRE l’enregistrement');
    try {
      final path = await _audioRecorder.start(config: {'input': _current!.url});
      debugPrint('>>> start terminé, path = $path');
      setState(() {
        _isRecording = true;
        _recordPath = path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistrement du flux…\n$path')),
      );
    } catch (e) {
      debugPrint('>>> ERREUR start : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  /* ========================================================= */
  /*                     FAVORIS                               */
  /* ========================================================= */
  Future<void> _loadFavs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('favs') ?? <String>[];
    setState(() {
      _favs.clear();
      _favs.addAll(saved);
    });
  }

  Future<void> _saveFavs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favs', _favs.toList());
  }

  /* ========================================================= */
  /*                         UI                                */
  /* ========================================================= */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Live World Radio'),
        leading: const BtmQuit(),   // ← notre bouton
      ),
      body: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.30,
                child: Column(
                  children: [
                    _countryDropdownOnly(), // ← unique dropdown
                    const SizedBox(height: 8),
                    Expanded(child: _stationList()),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _currentZone(),
                    const SizedBox(height: 4),
                    _adBanner(),
                    const SizedBox(height: 4),
                    _bottomZone(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ---------------  WIDGET PAYS  (UNIQUE DROPDOWN)  --------------- */
  Widget _countryDropdownOnly() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Map<String, String>>(
            isExpanded: true,
            value: _countries.cast<Map<String, String>?>().firstWhere(
                  (e) => e!['name'] == _selectedCountry,
                  orElse: () => null,
                ),
            hint: const Text('Sélectionner un pays'),
            items: _countries.map((c) {
              return DropdownMenuItem<Map<String, String>>(
                value: c,
                child: Row(
                  children: [
                    Image.network(
                      c['flag']!,
                      width: 24,
                      height: 16,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.flag, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(c['name']!),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _selectedCountry = val['name'];
                _selectedCountryCode = val['code'];
              });
              _loadStations();
            },
          ),
        ),
      ),
    );
  }

  /* ---------------  WIDGET STATIONS  --------------- */
  Widget _stationList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_selectedCountryCode == null) {
      return const Center(child: Text('Veuillez choisir un pays'));
    }
    if (_stations.isEmpty) {
      return const Center(child: Text('Aucune station en ligne'));
    }
    return ListView.separated(                           // ← plus souple
      padding: const EdgeInsets.symmetric(horizontal: 4), // ← réduit
      itemCount: _stations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (_, i) {
        final st = _stations[i];
        return CustomRadioListTile(
          radio: st,
          isPlaying: _current == st && _isPlaying,
          isFavorite: _favs.contains(st.name),
          isOffline: false,
          onTap: () => _play(st),
          onFavorite: () => _toggleFav(st),
        );
      },
    );
  }

  /* ---------------  WIDGETS DÉCORATIFS  --------------- */
  Widget _currentZone() {
    return Expanded(
      flex: 1,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
        child: Text(_current?.name ?? 'Aucune station', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _adBanner() {
    return Expanded(
      flex: 1,
      child: Container(
        decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8)),
        child: Center(child: Marquee(text: 'Ici votre publicité - Offre spéciale - ', velocity: 30, blankSpace: 60, pauseAfterRound: const Duration(seconds: 1), style: const TextStyle(color: Colors.black))),
      ),
    );
  }

  Widget _bottomZone() {
    return Expanded(
      flex: 1,
      child: Container(
        decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8)),
        child: Scrollbar(                           // ← défilement si besoin
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              if (_current != null) ...[
                IconButton(
                  icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 40,
                      color: Colors.blue),
                  onPressed: () async {
                    if (_current == null) return;
                    if (_isPlaying) {
                      await _player.pause();
                    } else {
                      await _player.play();
                    }
                  },
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(_isPlaying ? 'Lecture en cours' : 'En pause',
                      style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: ElevatedButton.icon(
                    icon: Icon(_isRecording ? Icons.stop : Icons.radio),
                    label: Text(_isRecording ? 'Arrêter' : 'Enregistrer'),
                    onPressed: _toggleRecord,
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isRecording ? Colors.red : Colors.green),
                  ),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Zone L3 (lecteur, boutons…)',
                      textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ==========================================================
   Callback TOP-LEVEL obligatoire pour Workmanager
   ========================================================== */
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'updateAES') await pullLatestEncryptedAsset();
    return Future.value(true);
  });
}