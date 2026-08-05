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
