// Test penceresini GERÇEK telefon boyutuna indirir — `setSurfaceSize` tek
// başına YETMEZ: yalnızca çizim yüzeyini küçültür, MediaQuery hâlâ 800×600
// varsayılan test penceresini bildirir. GameHeader gibi MediaQuery'den
// (web'in vw eşleniği) akıcı boyut hesaplayan widget'lar bu yüzden kendini
// 800px'te sanıp maksimum boyda çizer ve dar yüzeyde taşar — kullanıcının
// "kutular GİRİŞ'in altına giriyor" diye bildirdiği ekran görüntüsü
// artefaktının kökü buydu (6 Ağustos 2026, cihazda sorun yoktu).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> setPhoneViewSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}
