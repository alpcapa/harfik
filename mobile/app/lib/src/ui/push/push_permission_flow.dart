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
    final izin = await messaging.permission();

    // Karar ne olursa olsun token durumu İZİNLE hizalanmalı — kullanıcı
    // ayarlardan açmış olabilir (o zaman yazılır) ya da kapatmış olabilir
    // (o zaman silinir). Bu, sormaktan BAĞIMSIZ.
    await repo.senkronize(userId: userId, izin: izin);

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
