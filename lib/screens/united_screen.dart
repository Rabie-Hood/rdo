// lib/screens/united_screen.dart
// REMARQUES (inchangées) :
// 1. Clé obfusquée 32 caractères exacts
// 2. Télécharge le dernier AES depuis GitHub
// 3. Lit le blob (local ou asset) → déchiffre
// -------------------------------------------------

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
  List<RadioStation> _stations = [];       // ← filtrées à l’affichage
  List<RadioStation> _allStations = [];    // ← cache global (chargé 1 fois)
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
    // ✅ 1) Pays + 2) Stations une seule fois → 3) Pays système
    _loadCountries().then((_) async {
      await _loadAllStations(); // ← déchiffre 1 seule fois
      _selectSystemCountry();   // ← filtre rapide
    });
    _loadFavs();
    _player.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    /* 🔒 Tâche de fond – desktop exclu */
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
      Workmanager().registerPeriodicTask(
        'updateAES',
        'updateAES',
        frequency: const Duration(hours: 6),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    }
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
      _loadStations(); // ← filtre rapide depuis le cache
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
  /*              CHARGEMENT UNIQUE DES STATIONS               */
  /* ========================================================= */
  Future<void> _loadAllStations() async {
    if (_allStations.isNotEmpty) return; // déjà en mémoire
    try {
      final jsonStr = await EncryptedAssetLoader.decryptJson(); // 1 seul déchiffrement
      final data  = jsonDecode(jsonStr) as List;
      _allStations = data.map((e) => RadioStation.fromJson(e)).toList();
    } catch (_) {
      _allStations = [];
    }
  }

  /* ========================================================= */
  /*                     FILTRAGE RAPIDE                       */
  /* ========================================================= */
  Future<void> _loadStations() async {
    if (_selectedCountryCode == null) return;
    setState(() => _loading = true);

    // ✅ Filtre ultra-rapide depuis le cache mémoire
    final countryCode = _selectedCountryCode!.toUpperCase();
    final dedup = _allStations.where((s) {
      final code = (s.code ?? '').trim().toUpperCase();
      return code == countryCode;
    }).toList();

    setState(() {
      _stations = dedup;
      _loading = false;
    });
  }

  /* ========================================================= */
  /*                   LECTURE  RADIO                          */
  /* ========================================================= */
  Future<void> _play(RadioStation st) async {
    await _player.stop(); // coupe l’ancien flux

    if (_current == st && _isPlaying) { // même station → pause
      await _player.pause();
      return;
    }
    
    await _player.setAudioSource(AudioSource.uri(Uri.parse(st.url)));
    setState(() => _current = st);
    await _player.play();
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
  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<void> _toggleRecord() async {
    if (_current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune station sélectionnée')),
      );
      return;
    }

    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistrement terminé :\n$path')),
      );
      return;
    }

    try {
      final path = await _audioRecorder.start(config: {'input': _current!.url});
      setState(() {
        _isRecording = true;
        _recordPath = path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistrement du flux…\n$path')),
      );
    } catch (e) {
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
        leading: const BtmQuit(),
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
                    _countryDropdownOnly(),
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
                      c['flag']!.trim(),
                      width: 24,
                      height: 16,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Image.asset('assets/flags/unknown.png', width: 24, height: 16, fit: BoxFit.cover),
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
              _loadStations(); // ← filtre rapide
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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
        child: Scrollbar(
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
    if (task == 'updateAES') await EncryptedAssetLoader.pullLatestEncryptedAsset(); // ← classe
    return Future.value(true);
  });
}