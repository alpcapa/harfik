// Geçici iskelet ana ekranı — GERÇEK Setup UI'ı ayrı parça (mobile/CLAUDE.md).
// Bu sürümde kalıcılık bağlandı: devam eden oyun varsa web'in misafir
// kuralları uygulanır — tek slot, "Devam Eden Oyun" satırı, yeni oyun
// açılamaz (anti-kaçış), N sonra silinecek etiketi, 7 günlük terk süpürmesi.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../bootstrap.dart';
import '../config/env.dart';
import '../game/game_controller.dart';
import '../game/local_game_repo.dart';
import '../storage/local_save_store.dart' show abandonTimeout;
import 'game/board_widget.dart';
import 'game/game_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppServices services;
  const HomeScreen({super.key, required this.services});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameController? _demo;
  String? _demoSummary;

  LocalGameRepo? _repo;
  bool _saveChecked = false; // depo hazır + ilk kontrol yapıldı mı
  bool _hasSave = false;
  int? _savedAtMs;

  @override
  void initState() {
    super.initState();
    final storage = widget.services.storage;
    if (storage != null) {
      storage.then((s) async {
        final repo = LocalGameRepo(s);
        // Terk süpürmesi web'deki gibi Setup'a her girişte — süresi dolan
        // kayıt load'da olaya dönüşür, olay burada ceza kuyruğuna işlenir.
        await repo.loadSave().then((_) {}); // süresi dolanı olaya çevirir
        await repo.drainAbandonedGames();
        if (!mounted) return;
        _repo = repo;
        await _refreshSaveStatus();
      });
    } else {
      _saveChecked = true; // depo yok (test ortamı) — kalıcılıksız çalış
    }
  }

  Future<void> _refreshSaveStatus() async {
    final repo = _repo;
    if (repo == null) return;
    final has = await repo.hasSave();
    final at = has ? await repo.savedAtMs() : null;
    if (!mounted) return;
    setState(() {
      _saveChecked = true;
      _hasSave = has;
      _savedAtMs = at;
    });
  }

  /// Web SavedGameRow'un misafir etiketi: kalan süre + "silinecek"
  /// ("teslim sayılacak" DEĞİL — misafirde kesin olan tek sonuç silinme).
  String _remainingLabel() {
    final at = _savedAtMs;
    if (at == null) return '';
    final left = abandonTimeout.inMilliseconds -
        (DateTime.now().millisecondsSinceEpoch - at);
    if (left <= 0) return 'Süresi doldu';
    final days = (left / Duration.millisecondsPerDay).ceil();
    if (days > 1) return '$days gün sonra silinecek';
    final hours = (left / Duration.millisecondsPerHour).ceil();
    return '$hours saat sonra silinecek';
  }

  Future<void> _openGame(GameController controller, SetWordSource words) async {
    final session = _repo?.attach(controller);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(controller: controller, words: words),
    ));
    await session?.end();
    controller.dispose();
    await _refreshSaveStatus();
  }

  Future<void> _startNewGame(SetWordSource words) async {
    final controller = GameController(words: words);
    controller.dispatch(StartAction(const [
      PlayerSetup(name: 'Sen', isAI: false),
      PlayerSetup(name: '', isAI: true),
    ]));
    await _openGame(controller, words);
  }

  Future<void> _resumeSavedGame(SetWordSource words) async {
    final repo = _repo;
    if (repo == null) return;
    final state = await repo.loadSave();
    if (state == null) {
      // Tam bu anda süresi dolmuş/karantinaya düşmüş — listeyi tazele.
      await repo.drainAbandonedGames();
      await _refreshSaveStatus();
      return;
    }
    final controller = GameController(words: words);
    controller.restore(state);
    await _openGame(controller, words);
  }

  @override
  void dispose() {
    _demo?.dispose();
    super.dispose();
  }

  Future<void> _runDemoGame(SetWordSource words) async {
    // Tohumlu YZ vs YZ oyunu — motor + gerçek sözlük cihazda çalışıyor mu
    // testi (kalıcılığa bilerek BAĞLANMAZ — misafir slotunu kirletmesin).
    setState(() => _demoSummary = null);
    final controller = GameController(
      words: words,
      rng: Mulberry32(DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF),
    );
    _demo?.dispose();
    _demo = controller;
    controller.addListener(() {
      final s = controller.state;
      if (s.isGameOver && mounted) {
        setState(() {
          _demoSummary =
              'Bitti — ${s.turnCount} tur. Skorlar: ${s.players.map((p) => '${p.name} ${p.score}').join(', ')}';
        });
      } else if (mounted) {
        setState(() {});
      }
    });
    controller.dispatch(StartAction(const [
      PlayerSetup(name: '', isAI: true),
      PlayerSetup(name: '', isAI: true),
    ]));
  }

  Widget _buildGameEntry(SetWordSource words) {
    if (!_saveChecked) return const Text('Kayıtlar kontrol ediliyor…');
    if (_hasSave) {
      // Web'in misafir "Devam Eden Oyun" görünümü: tek slot, yeni oyun yok.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              border: Border.all(color: const Color(0xFFDCE2EA)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Devam Eden Oyun',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                const Text('Senin Hamlen Bekleniyor',
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    )),
                Text(_remainingLabel(),
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF5A6673))),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => _resumeSavedGame(words),
                  child: const Text('Devam Et'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bu oyun 7 gün boyunca cihazının hafızasında saklanır ve bir '
            'sonraki gelişinde devam edilebilir. Bu oyunu bitirmeden yeni '
            'oyun açamazsın.',
            style: TextStyle(fontSize: 11, color: Color(0xFF5A6673)),
          ),
        ],
      );
    }
    return FilledButton(
      onPressed: () => _startNewGame(words),
      child: const Text('Oyna: Sen vs Yapay Zeka (deneme)'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final demoState = _demo?.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Kelimeki')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sürüm: $appVersion'),
            Text(services.supabase != null
                ? 'Sunucu: bağlı'
                : 'Sunucu: yapılandırılmamış (offline mod)'),
            if (services.storage != null)
              FutureBuilder(
                future: services.storage,
                builder: (context, snap) => Text(snap.hasError
                    ? 'Depolama: hata — ${snap.error}'
                    : snap.hasData
                        ? 'Depolama: hazır'
                        : 'Depolama: açılıyor…'),
              ),
            FutureBuilder<SetWordSource>(
              future: services.dictionary,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text('Sözlük yüklenemedi: ${snap.error}');
                }
                if (!snap.hasData) return const Text('Sözlük: yükleniyor…');
                final words = snap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sözlük: ${words.length} kelime'),
                    const SizedBox(height: 24),
                    _buildGameEntry(words),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _runDemoGame(words),
                      child: const Text('Motor testi: YZ vs YZ oyunu oynat'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (demoState != null && demoState.phase == GamePhase.play) ...[
              Text(_demoSummary ??
                  'Oynanıyor… tur ${demoState.turnCount}, '
                      'skorlar: ${demoState.players.map((p) => p.score).join(' - ')}'),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: BoardWidget(state: demoState),
                  ),
                ),
              ),
            ] else if (_demoSummary != null)
              Text(_demoSummary!),
            if (demoState == null || demoState.phase != GamePhase.play)
              const Spacer(),
            const Text(
              'İskelet ekran — gerçek oyun arayüzü UI portu fazında gelecek '
              '(mobile/CLAUDE.md).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
