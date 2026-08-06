// Kurulum ekranı — src/components/Setup.tsx'in MİSAFİR akışının portu
// (uygulamanın bu fazında auth yok; girişli dallar — cloudSaves, hesap
// satırı, MembershipPerksBox — auth fazının işi). İskelet HomeScreen'in
// yerine geçer; kalıcılık akışı (LocalGameRepo süpürmesi, tek slot,
// anti-kaçış) oradan buraya taşındı.
//
// Web paritesi: logo + tanıtım metni, "Oyun Tipi" sekmeleri (Arkadaşınla =
// dürüst "sonraki sürümde" diyaloğu), Oyuncu Sayısı 2/4, renkli Oyuncular
// listesi (Misafir + "Yapay Zeka N"), sözlük hazır olana dek "HAZIRLANIYOR…"
// gösteren Oyunu Başlat; misafirin tekil kaydı varsa form yerine "Devam Eden
// Oyun" satırı (avatarlar + Sıra: + kalan süre) ve 7 gün paragrafı.
// "Nasıl oynanır?" linki kurallar modalını açar; "Arkadaşınla paylaş"
// (native share) bilinçli eksik — ayrı parça.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../../bootstrap.dart';
import '../../config/env.dart';
import '../../game/game_controller.dart';
import '../../game/local_game_repo.dart';
import '../../storage/local_save_store.dart' show abandonTimeout;
import '../game/game_screen.dart';
import '../game/help_modal.dart';
import '../game/logo_mark.dart';
import '../game/neo_button.dart';
import '../game/player_badge.dart';
import '../game/player_colors.dart';
import '../auth/account_button.dart';
import '../auth/k_avatar.dart';

const _panel = Color(0xFFF5F7FA);
const _border = Color(0xFFDCE2EA);
const _muted = Color(0xFF5A6673);
const _text = Color(0xFF1B2430);

class SetupScreen extends StatefulWidget {
  final AppServices services;
  const SetupScreen({super.key, required this.services});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _count = 2;

  LocalGameRepo? _repo;
  bool _saveChecked = false;
  GameState? _savedState; // null = kayıt yok
  int? _savedAtMs;

  @override
  void initState() {
    super.initState();
    final storage = widget.services.storage;
    if (storage != null) {
      storage.then((s) async {
        final repo = LocalGameRepo(s);
        _repo = repo;
        await _refreshSaveStatus(); // load süresi dolanı olaya çevirir
        await repo.drainAbandonedGames(); // web'in Setup süpürme refleksi
      });
    } else {
      _saveChecked = true; // depo yok (test ortamı) — kalıcılıksız çalış
    }
  }

  Future<void> _refreshSaveStatus() async {
    final repo = _repo;
    if (repo == null) return;
    final state = await repo.loadSave();
    final at = state != null ? await repo.savedAtMs() : null;
    if (!mounted) return;
    setState(() {
      _saveChecked = true;
      _savedState = state;
      _savedAtMs = at;
    });
  }

  Future<void> _openGame(GameController controller, SetWordSource words) async {
    final session = _repo?.attach(controller);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        controller: controller,
        words: words,
        meanings: widget.services.meanings,
        auth: widget.services.auth,
      ),
    ));
    await session?.end();
    controller.dispose();
    await _refreshSaveStatus();
  }

  Future<void> _startNewGame(SetWordSource words) async {
    final controller = GameController(words: words);
    // Web doStart paritesi: 1. oyuncu her zaman gerçek kişi — oturum
    // açıksa hesap sahibi (accountName), değilse misafir; diğerleri
    // "Yapay Zeka N" adıyla YZ.
    final me = widget.services.auth.accountName ?? guestPlayerName;
    controller.dispatch(StartAction([
      PlayerSetup(name: me, isAI: false),
      for (var i = 1; i < _count; i++)
        PlayerSetup(name: 'Yapay Zeka ${i + 1}', isAI: true),
    ]));
    await _openGame(controller, words);
  }

  Future<void> _resumeSavedGame(SetWordSource words) async {
    final repo = _repo;
    if (repo == null) return;
    final state = await repo.loadSave();
    if (state == null) {
      // Tam bu anda süresi dolmuş/karantinaya düşmüş — görünümü tazele.
      await repo.drainAbandonedGames();
      await _refreshSaveStatus();
      return;
    }
    final controller = GameController(words: words);
    controller.restore(state);
    await _openGame(controller, words);
  }

  void _showComingSoon(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('TAMAM'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.services.auth;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // Oturum/profil değişince (giriş, çıkış, profil gelmesi) tüm ekran
        // tazelenir — web'de useAuth context'inin yeniden render etmesiyle
        // aynı; auth yapılandırılmamışsa hiç notify etmez, maliyeti yok.
        child: ListenableBuilder(
          listenable: auth,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Web: Setup'ın üstünde sağa yaslı UserMenu (App.tsx,
                    // kurulum dalı) — GİRİŞ / avatar burada da sağ üstte.
                    if (auth.configured)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AccountButton(auth: auth),
                        ),
                      ),
                    const Center(child: LogoMark(height: 52)),
                    const SizedBox(height: 16),
                    const Text(
                      'Kelimeler kurarak bölgeni genişlet, rakiplerini kuşat. '
                      'Ama dikkat et: Hamlen rakibinin bölgesine temas ederse, '
                      'kazandığın puanın bir kısmını onunla paylaşmak zorunda '
                      'kalırsın. Her hamle bir strateji, her kelime bir mücadele.',
                      style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 12,
                        height: 1.5,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Web Setup'taki "Nasıl oynanır?" linki (yanındaki
                    // "Arkadaşınla paylaş" native share parçasının işi).
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => showHelpModal(context),
                        behavior: HitTestBehavior.opaque,
                        child: const Text(
                          'Nasıl oynanır?',
                          style: TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('OYUN TİPİ'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ChoiceButton(
                            label: 'YAPAY ZEKA İLE',
                            selected: true,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ChoiceButton(
                            label: 'ARKADAŞINLA',
                            selected: false,
                            onTap: () => _showComingSoon(
                              'Arkadaşınla',
                              'Canlı oyun (arkadaşlarınla gerçek zamanlı) '
                                  'uygulamanın sonraki sürümünde gelecek. '
                                  'Şimdilik Yapay Zeka\'ya karşı oynayabilirsin.',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<SetWordSource>(
                      future: widget.services.dictionary,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Text('Sözlük yüklenemedi: ${snap.error}',
                              style: const TextStyle(color: Color(0xFFDC2626)));
                        }
                        final words = snap.data;
                        if (!_saveChecked) {
                          return const _SectionLabel(
                              'KAYITLAR KONTROL EDİLİYOR…');
                        }
                        return _savedState != null
                            ? _buildSavedGameView(words)
                            : _buildNewGameForm(words);
                      },
                    ),
                    const SizedBox(height: 32),
                    // Teşhis alt satırı (iskelet HomeScreen'in durum
                    // panelinden kalan tek iz — cihazda ilk açılış doğrulaması
                    // için faydalı, göze batmayan tek satır).
                    FutureBuilder<SetWordSource>(
                      future: widget.services.dictionary,
                      builder: (context, snap) => Text(
                        [
                          'Sürüm $appVersion',
                          snap.hasData
                              ? 'Sözlük: ${snap.data!.length} kelime'
                              : 'Sözlük: yükleniyor…',
                          widget.services.supabase != null
                              ? 'sunucu bağlı'
                              : 'offline mod',
                        ].join(' · '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 9,
                          color: Color(0xFF8A93A2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Misafirin tekil kaydı — web'in anti-kaçış kuralı: bu görünümde yeni
  /// oyun formu HİÇ yok, kayıt bitene/silinene kadar tek yol devam etmek.
  Widget _buildSavedGameView(SetWordSource? words) {
    final state = _savedState!;
    final current =
        state.players.isNotEmpty ? state.players[state.current].name : '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('DEVAM EDEN OYUN'),
        const SizedBox(height: 8),
        _SavedGameRow(
          state: state,
          subtitle: 'Sıra: $current',
          savedAtMs: _savedAtMs ?? 0,
          onTap: words == null ? null : () => _resumeSavedGame(words),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bu oyun 7 gün boyunca cihazınızın hafızasında saklanır ve bir '
          'sonraki gelişinizde devam edilebilir. Üye değilseniz bu oyunu '
          'bitirmeden yeni oyun açamazsınız.',
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 11,
            height: 1.5,
            color: _muted,
          ),
        ),
      ],
    );
  }

  Widget _buildNewGameForm(SetWordSource? words) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('OYUNCU SAYISI'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final n in const [2, 4]) ...[
              if (n != 2) const SizedBox(width: 8),
              Expanded(
                child: _ChoiceButton(
                  label: '$n OYUNCULU',
                  selected: _count == n,
                  onTap: () => setState(() => _count = n),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        const _SectionLabel('OYUNCULAR'),
        const SizedBox(height: 8),
        for (var i = 0; i < _count; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _PlayerRow(
            index: i,
            accountName: widget.services.auth.accountName,
            accountAvatarUrl: widget.services.auth.profile?.avatarUrl,
            accountPending: widget.services.auth.accountPending,
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          // Web: `btn-raised bg-accent ... disabled:opacity-35` — NeoButton
          // disabled durumu birebir aynı görünümü verir.
          child: NeoButton(
            label: words == null ? 'HAZIRLANIYOR…' : 'OYUNU BAŞLAT',
            variant: NeoButtonVariant.accent,
            fontSize: 14,
            letterSpacing: 2,
            onPressed: words == null ? null : () => _startNewGame(words),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'SpaceMono',
        fontSize: 10,
        letterSpacing: 1.5,
        color: _muted,
      ),
    );
  }
}

/// Web'in btn-raised/btn-raised-neutral sekme/seçim butonu: seçili = accent
/// zemin + beyaz, değil = panel zemin + çerçeve — gölgeler NeoButton'dan
/// (index.css btn-raised / btn-raised-neutral değerleri).
class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NeoButton(
      label: label,
      variant: selected ? NeoButtonVariant.accent : NeoButtonVariant.neutral,
      fontSize: 13,
      letterSpacing: 1,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      onPressed: onTap,
    );
  }
}

/// Oyuncular listesindeki renkli satır — web: tint zemin + base çerçeve,
/// PlayerBadge + ad + sağda "Sen"/"YZN" etiketi.
class _PlayerRow extends StatelessWidget {
  final int index;

  /// Oturum açıksa 1. koltuk hesap sahibidir (web isAccount): avatar +
  /// kilitli isim. Profil beklenirken (accountPending) nötr "Yükleniyor…"
  /// gösterilir — bir anlık "Misafir" yazıp gerçek adla değişmesin (web'de
  /// yaşanmış kimlik-değişimi hatası).
  final String? accountName;
  final String? accountAvatarUrl;
  final bool accountPending;

  const _PlayerRow({
    required this.index,
    this.accountName,
    this.accountAvatarUrl,
    this.accountPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final col = playerColors[index % playerColors.length];
    final isAccount = index == 0 && accountName != null;
    final isPending = index == 0 && accountPending;
    final name = index == 0
        ? (accountName ?? (isPending ? 'Yükleniyor…' : guestPlayerName))
        : 'Yapay Zeka ${index + 1}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: col.tint,
        border: Border.all(color: col.base),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (isAccount)
            KAvatar(url: accountAvatarUrl, name: accountName, size: 20)
          else if (isPending)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _panel,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
            )
          else
            PlayerBadge(index: index),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isPending ? _muted : _text,
              ),
            ),
          ),
          Text(
            index == 0 ? 'SEN' : 'YZ${index + 1}',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 9,
              letterSpacing: 1,
              color: col.base,
            ),
          ),
        ],
      ),
    );
  }
}

/// Web SavedGameRow portu: solda katılımcı avatarları (misafir "?" + robot)
/// ve "Sıra: X", sağda yeşil "SENİN HAMLEN BEKLENİYOR" + kalan süre.
class _SavedGameRow extends StatelessWidget {
  final GameState state;
  final String subtitle;
  final int savedAtMs;
  final VoidCallback? onTap;
  const _SavedGameRow({
    required this.state,
    required this.subtitle,
    required this.savedAtMs,
    this.onTap,
  });

  /// Web remainingTime portu (willSurrender=false — misafir dili: kesin olan
  /// tek sonuç silinme; <24 saatte kırmızı + dakika hassasiyeti).
  ({String text, bool urgent}) _remaining() {
    const verb = 'silinecek';
    final ms = savedAtMs +
        abandonTimeout.inMilliseconds -
        DateTime.now().millisecondsSinceEpoch;
    if (ms <= 0) return (text: 'Bugün $verb', urgent: true);
    final totalMinutes = (ms / (60 * 1000)).ceil();
    final totalHours = totalMinutes ~/ 60;
    final days = totalHours ~/ 24;
    final hours = totalHours % 24;
    final minutes = totalMinutes % 60;
    final text = days > 0
        ? '$days gün $hours saat sonra $verb'
        : '$hours saat $minutes dakika sonra $verb';
    return (text: text, urgent: days < 1);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AvatarStrip(players: state.players),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 9,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'SENİN HAMLEN BEKLENİYOR',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // trUpper ŞART — native toUpperCase 'silinecek'i noktasız
                  // I ile 'SILINECEK' yapar (test yakaladı; web'de CSS
                  // uppercase tr locale ile doğruydu).
                  trUpper(remaining.text),
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 8,
                    letterSpacing: 0.5,
                    color: remaining.urgent ? const Color(0xFFDC2626) : _muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// PlayerAvatarRow'un misafir/YZ alt kümesi: hafif üst üste binen 20px
/// çemberler — misafir koltuk "?" (webde Avatar'ın boş-isim yedeği),
/// YZ koltuklar robot. Fotoğraflı üye avatarı auth fazının işi.
class _AvatarStrip extends StatelessWidget {
  final List<Player> players;
  const _AvatarStrip({required this.players});

  @override
  Widget build(BuildContext context) {
    const size = 20.0;
    const overlap = 4.0;
    final width = size + (players.length - 1) * (size - overlap);
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < players.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: players[i].isAI
                      ? const Color(0xFFE8EBEF) // web bg-void (robot)
                      : _panel,
                  border: Border.all(color: _border),
                  shape: BoxShape.circle,
                ),
                child: players[i].isAI
                    ? const Icon(Icons.smart_toy_outlined,
                        size: 12, color: _muted)
                    : const Text(
                        '?',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _muted,
                          height: 1,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
