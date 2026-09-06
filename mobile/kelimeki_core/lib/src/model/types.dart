// Kelimeki core — paylaşılan küçük tipler (src/game/types.ts portunun parçası).

/// Bir hücre koordinatı (r, c).
typedef Cell = (int, int);

/// Bonus kare türü: yalnızca tahtanın tam ortasındaki tek X3 hücresi kullanır.
/// (TS: BonusType = 'tw')
enum BonusType { tw }

/// TS'teki 'setup' | 'play'.
enum GamePhase { setup, play }

/// TS'teki 'normal' | 'surrender'.
enum EndReason { normal, surrender }

/// TS'teki '' | 'ok' | 'err' | 'warn' — `none` boş dizeye karşılık gelir.
enum MessageKind { none, ok, err, warn }

extension GamePhaseJson on GamePhase {
  String get json => this == GamePhase.setup ? 'setup' : 'play';
  static GamePhase parse(String s) =>
      s == 'setup' ? GamePhase.setup : GamePhase.play;
}

extension EndReasonJson on EndReason {
  String get json => this == EndReason.normal ? 'normal' : 'surrender';
  static EndReason parse(String s) =>
      s == 'surrender' ? EndReason.surrender : EndReason.normal;
}

extension MessageKindJson on MessageKind {
  String get json => switch (this) {
        MessageKind.none => '',
        MessageKind.ok => 'ok',
        MessageKind.err => 'err',
        MessageKind.warn => 'warn',
      };
  static MessageKind parse(String s) => switch (s) {
        'ok' => MessageKind.ok,
        'err' => MessageKind.err,
        'warn' => MessageKind.warn,
        _ => MessageKind.none,
      };
}

/// YZ zorluk seviyesi (TS: AiLevel = 'kolay' | 'normal' | 'zor', ROADMAP #23).
/// Normal = en yüksek puanlı hamle (N=1), Kolay = en iyi `aiLevelTopN` (4)
/// hamleden rastgele biri, Zor = Faz 5'in yeni motoru (o güne kadar Normal).
enum AiLevel { kolay, normal, zor }

extension AiLevelJson on AiLevel {
  String get json => switch (this) {
        AiLevel.kolay => 'kolay',
        AiLevel.normal => 'normal',
        AiLevel.zor => 'zor',
      };

  /// Bilinmeyen/eksik değer → Normal (sunucudaki `null = Normal` sözleşmesi).
  static AiLevel parse(String? s) => switch (s) {
        'kolay' => AiLevel.kolay,
        'zor' => AiLevel.zor,
        _ => AiLevel.normal,
      };

  /// Codec için: alan YOKSA null kalır (web'in JSON'u Normal'de anahtarı
  /// hiç yazmaz; golden derin karşılaştırması buna dayanır).
  static AiLevel? parseOrNull(String? s) => s == null ? null : parse(s);
}
