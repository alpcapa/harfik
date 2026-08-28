// Bildirim izni akışı — KARAR `util/push_rules.dart`ta, burada yalnızca
// sırayı yürütmek var.
//
// ⚠ SIRA KRİTİK ve tek bir sebebi var: Android 13+'ta sistem diyaloğu
// kalıcı olarak susturulabiliyor (`deniedPermanently`). Bu yüzden ÖNCE bizim
// kartımız çıkıyor; sistem diyaloğu ANCAK kullanıcı orada "Aç" derse
// tetikleniyor. "Şimdi Değil" bir sistem denemesi HARCAMAZ — ara adımın tek
// varlık sebebi bu.
//
// Tetikleyici (ürün kararı, 28 Ağustos 2026): "Canlı sekmesi açıldı VE en az
// bir aktif oyun/bekleyen davet var". Konum değil DURUM — oyunu olmayan
// birine, olmayan oyunlar için bildirim sorulmuyor. Aynı kontrol oyun
// kurma/kabul anında da çalışır (hangisi önce gelirse).
import 'package:flutter/material.dart';

import '../../data/push_repo.dart';
import '../../storage/flags_store.dart';
import '../../util/push_rules.dart';
import '../game/dialog_shell.dart';

/// Gerekiyorsa izin kartını gösterir ve sonucuna göre token'ı senkronlar.
///
/// Her çağrıda önce SİSTEM durumu okunuyor — yerel sayaç tek başına yeterli
/// değil: kullanıcı izni sistem ayarlarından açmış/kapatmış olabilir ve o
/// bilgi bizde yok.
///
/// Hiçbir yolu fırlatmaz: bu akış Canlı sekmesinin açılışında çalışıyor,
/// bir izin/eklenti hatası sekmeyi düşüremez.
/// Token durumunu sistem izniyle HİZALAR — hiçbir şey sormadan.
///
/// **NEDEN AYRI BİR FONKSİYON (28 Ağustos 2026, cihaz testinde bulundu):**
/// hizalama eskiden yalnızca `pushIzniAkisi`'nin içindeydi, o da yalnızca
/// Canlı sekmesinin `_reload()`'undan çağrılıyordu. Sonuç: bildirimi SİSTEM
/// AYARLARINDAN kapatan ve Canlı sekmesine girmeyen kullanıcının token'ı
/// tabloda kalıyordu — sunucu göndermeye devam ediyor, işletim sistemi
/// sessizce yutuyordu. Cihazda ÖLÇÜLDÜ: bildirim kapatılıp uygulama tamamen
/// kapatılıp açıldı, satır durdu (`updated_at` bile değişmedi); Canlı
/// sekmesi açılınca AYNI SANİYE silindi. Yani mekanizma doğruydu,
/// tetikleyicisi yanlış yerdeydi.
///
/// Kritik nokta: **sistem ayarı uygulamanın DIŞINDA değişiyor.** Bunu
/// yakalamanın tek güvenilir anı uygulamanın öne dönüşü (`resumed`) —
/// bir sekmenin açılmasına bağlamak yapısal olarak yetersiz. Çağrı yerleri
/// artık `_HomeGate` (açılış + `resumed` + oturum değişimi) ve Canlı sekmesi.
///
/// Uygulanan izni döndürür; hata olursa `null` (fırlatmaz — bu akış hiçbir
/// ekranı düşüremez).
Future<PushPermission?> pushTokenlariHizala({
  required PushMessaging messaging,
  required PushRepo repo,
  required String userId,
}) async {
  try {
    final izin = await messaging.permission();
    await repo.senkronize(userId: userId, izin: izin);
    return izin;
  } catch (e) {
    debugPrint('[Kelimeki] push token hizalama hatası: $e');
    return null;
  }
}

Future<void> pushIzniAkisi(
  BuildContext context, {
  required PushMessaging messaging,
  required PushRepo repo,
  required FlagsStore flags,
  required String userId,
  required bool aktifOyunVar,
  DateTime? simdi,
}) async {
  try {
    // Karar ne olursa olsun token durumu İZİNLE hizalanır — kullanıcı
    // ayarlardan açmış olabilir (yazılır) ya da kapatmış olabilir (silinir).
    // Bu, sormaktan BAĞIMSIZ ve tek kaynaktan (yukarıdaki fonksiyon) geçer.
    final izin = await pushTokenlariHizala(
      messaging: messaging,
      repo: repo,
      userId: userId,
    );
    if (izin == null) return; // hata zaten loglandı

    final sorulmali = pushIzniSorulmali(
      aktifOyunVar: aktifOyunVar,
      izinZatenVerildi: izin == PushPermission.granted,
      kaliciReddedildi: izin == PushPermission.permanentlyDenied,
      soruldu: flags.pushSorulmaSayisi,
      sonSorulma: flags.pushSonSorulma,
      simdi: simdi ?? DateTime.now(),
    );
    if (!sorulmali || !context.mounted) return;

    // ⚠ Sayaç kartı GÖSTERMEDEN ÖNCE artıyor. Sonra artırsaydık, kart
    // açıkken uygulama kapanan bir kullanıcıya her açılışta yeniden
    // sorulurdu — "üç kez" sınırı sessizce sonsuza dönerdi.
    await flags.pushSorulduIsaretle(simdi ?? DateTime.now());
    if (!context.mounted) return;

    final kabul = await showKConfirm(
      context,
      title: 'Bildirimleri açalım mı?',
      message: 'Sıra sana geldiğinde ve oyunun süresi dolmak üzereyken haber '
          'verelim. İstediğin zaman Hesap Ayarları\'ndan kapatabilirsin.',
      confirmLabel: 'BİLDİRİMLERİ AÇ',
      cancelLabel: 'ŞİMDİ DEĞİL',
    );
    if (!kabul) return;

    // Sistem diyaloğu YALNIZCA buradan açılıyor.
    final yeniIzin = await messaging.requestPermission();
    await repo.senkronize(userId: userId, izin: yeniIzin);
  } catch (e) {
    debugPrint('[Kelimeki] push izin akışı hatası: $e');
  }
}
