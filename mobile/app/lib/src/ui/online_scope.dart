// Bağlantı durumunun AĞAÇ GENELİNDE erişilebilir hâli.
//
// NEDEN VAR (29 Ağustos 2026, kullanıcı cihazda bildirdi: *"app açıkken
// internet gelince avatar güncellenmedi, sadece aç kapa yapınca
// düzeliyor"*): `KAvatar`, görsel yüklenemeyince baş harflere düşüyor ve
// `_broken` bayrağı YALNIZCA url değişince sıfırlanıyordu — yani bağlantı
// geri gelse bile o widget yaşadığı sürece baş harflerde kalıyordu.
//
// Düzeltmek için avatarın "çevrimiçine dönüldü" bilgisine erişmesi gerekti.
// **Parametre olarak geçirmek ELENDİ:** `KAvatar`ın 19 çağrı yeri var (16
// dosya) ve yeni bir çağrı yerinde birinin unutması, hatayı sessizce geri
// getirirdi — bu kod tabanının en sık tekrarlayan hata sınıfı tam olarak bu
// ("zincirin bir halkası güncellenmedi"). `InheritedNotifier` ile kapsam
// KÖKTE bir kez kuruluyor, çağrı yerlerinin hiçbiri değişmiyor ve bundan
// sonraki her `KAvatar` bunu kendiliğinden alıyor.
//
// Bilinçli olarak `maybeOf`: testler ve izole widget'lar kapsamsız da
// çalışabilmeli — kapsam yoksa davranış eskisiyle aynı (çevrimiçi varsayılır).
library;

import 'package:flutter/widgets.dart';

import '../util/online_status.dart';

class OnlineScope extends InheritedNotifier<OnlineStatus> {
  const OnlineScope({super.key, required OnlineStatus status, required super.child})
      : super(notifier: status);

  /// Kapsam yoksa `null` — çağıran "çevrimiçi" varsaymalı.
  static OnlineStatus? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnlineScope>()?.notifier;
}
