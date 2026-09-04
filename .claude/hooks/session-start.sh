#!/bin/bash
# Kelimeki — oturum başlangıcı: testlerin ve linter'ların KOŞABİLİR olmasını sağlar.
#
# NEDEN VAR (4 Eylül 2026): bu ortamda Flutter SDK'sı yoktu, yani portun
# Dart testleri YALNIZCA CI'da koşabiliyordu. Bedeli aynı gün ölçüldü: bir
# metin düzeltmesinde `help_modal_test.dart`ın eski metne bakan iddiası
# gözden kaçtı, PR kırmızıya döndü ve bir tur (~25 dk CI) yandı — yerelde
# `flutter test` koşulabilseydi push edilmeden görülürdü. Aynı sınır daha
# önce de not edilmişti ("Dart yarısının kanıtı CI", Parça 124 ve #431).
#
# İDEMPOTENT: kurulu olanı yeniden kurmaz; konteyner durumu hook bittikten
# sonra önbelleğe alındığından ikinci oturumdan itibaren saniyeler sürer.
set -euo pipefail

# Yalnızca uzak (Claude Code on the web) oturumlarda. Yerelde geliştiricinin
# kendi kurulumuna dokunmayız.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

# ── 1) Web bağımlılıkları ────────────────────────────────────────────────
# `npm install` (ci DEĞİL): önbelleğe alınmış node_modules'ü yeniden
# kullanabilsin diye.
if [ ! -d node_modules ]; then
  echo "[kelimeki] npm install…"
  npm install --no-audit --no-fund
fi

# ── 2) Flutter SDK ───────────────────────────────────────────────────────
# Kanal `stable` — CI'ın `subosito/flutter-action@v2 (channel: stable)`
# davranışının aynısı. Sürüm SABİTLENMİYOR: sabitlenirse CI ile sessizce
# ayrışır ve bu hook'un var olma sebebi (CI'ın gördüğünü yerelde görmek)
# ortadan kalkar. Belirli bir sürüm gerekirse FLUTTER_VERSION ile geç.
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/.flutter-sdk}"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "[kelimeki] Flutter SDK kuruluyor…"
  BASE="https://storage.googleapis.com/flutter_infra_release/releases"
  ARCHIVE=$(curl -fsSL --max-time 60 "$BASE/releases_linux.json" | python3 -c "
import json,sys,os
d=json.load(sys.stdin)
want=os.environ.get('FLUTTER_VERSION','')
rels=[r for r in d['releases'] if r['channel']=='stable']
r=next((x for x in rels if x['version']==want), None) if want else None
if r is None:
    r=next(x for x in rels if x['hash']==d['current_release']['stable'])
print(d['base_url']+'/'+r['archive'])
")
  echo "[kelimeki] indiriliyor: $ARCHIVE"
  mkdir -p "$(dirname "$FLUTTER_DIR")"
  TMP=$(mktemp -d)
  curl -fsSL --max-time 900 -o "$TMP/flutter.tar.xz" "$ARCHIVE"
  # ⚠ Arşiv kendi içinde `flutter/` klasörü taşıyor — doğrudan
  # `dirname $FLUTTER_DIR`e açmak SDK'yı `.../flutter`a koyar, hedef yola
  # DEĞİL (4 Eylül 2026'da tam bu şekilde `flutter: command not found`
  # alındı). Geçici bir yere açıp içindeki klasörü hedefe taşıyoruz.
  tar -xJf "$TMP/flutter.tar.xz" -C "$TMP"
  mv "$TMP/flutter" "$FLUTTER_DIR"
  rm -rf "$TMP"
  # Arşiv bir git checkout'u taşıyor; sahibi farklı olduğunda flutter
  # "dubious ownership" deyip sürümünü okuyamıyor.
  git config --global --add safe.directory "$FLUTTER_DIR" || true
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

# Yolu oturumun geri kalanına taşı.
LINE="export PATH=\"$FLUTTER_DIR/bin:\$PATH\""
if [ -n "${CLAUDE_ENV_FILE:-}" ] && ! grep -qF "$LINE" "$CLAUDE_ENV_FILE" 2>/dev/null; then
  echo "$LINE" >> "$CLAUDE_ENV_FILE"
fi

# ── 3) Dart paketleri ────────────────────────────────────────────────────
# İlk `flutter` çağrısı kendi aracını derliyor (bir kez, ~1 dk) — burada
# yapılırsa ilk teste denk gelmez.
echo "[kelimeki] flutter pub get (mobile/app)…"
(cd mobile/app && flutter pub get >/dev/null)

# Saf Dart motor paketi ayrı: `dart run test/run_all.dart` onu kullanıyor.
echo "[kelimeki] dart pub get (mobile/kelimeki_core)…"
(cd mobile/kelimeki_core && dart pub get >/dev/null)

echo "[kelimeki] hazır: $(flutter --version | head -1)"
