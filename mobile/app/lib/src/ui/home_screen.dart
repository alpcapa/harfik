// Geçici iskelet ana ekranı — GERÇEK UI DEĞİL (UI portu ayrı faz,
// mobile/CLAUDE.md "Sıradaki Fazlar" #4). Amacı, kablolamanın cihaz üzerinde
// uçtan uca çalıştığını kanıtlamak: sözlük yükleniyor mu, Supabase/offline
// durumu ne, motor gerçek sözlükle tam bir oyunu oynatabiliyor mu.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../bootstrap.dart';
import '../config/env.dart';
import '../game/game_controller.dart';

class HomeScreen extends StatefulWidget {
  final AppServices services;
  const HomeScreen({super.key, required this.services});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameController? _demo;
  String? _demoSummary;

  Future<void> _runDemoGame(SetWordSource words) async {
    // Tohumlu YZ vs YZ oyunu — golden vector senaryolarıyla aynı desen.
    // Motor + gerçek sözlük cihazda çalışıyor mu testi; UI fazına kadar
    // görsel tahta yok, yalnızca özet.
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

  @override
  void dispose() {
    _demo?.dispose();
    super.dispose();
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
                    FilledButton(
                      onPressed: () => _runDemoGame(words),
                      child: const Text('Motor testi: YZ vs YZ oyunu oynat'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (demoState != null && demoState.phase == GamePhase.play)
              Text(_demoSummary ??
                  'Oynanıyor… tur ${demoState.turnCount}, '
                      'skorlar: ${demoState.players.map((p) => p.score).join(' - ')}'),
            if (_demoSummary != null) Text(_demoSummary!),
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
