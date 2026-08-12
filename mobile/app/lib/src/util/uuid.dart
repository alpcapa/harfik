// UUID v4 üretimi — `uuid` paketine bağımlılık almamak için elle
// (Random.secure, RFC 4122 sürüm/varyant bitleri). Kullanım yeri:
// submit_move'un p_move_id idempotency anahtarı (OnlineApi).
import 'dart:math';

final Random _rng = Random.secure();

String uuidV4() {
  final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // sürüm 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // varyant 10xx
  final h = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')];
  return '${h[0]}${h[1]}${h[2]}${h[3]}-${h[4]}${h[5]}-${h[6]}${h[7]}-'
      '${h[8]}${h[9]}-${h[10]}${h[11]}${h[12]}${h[13]}${h[14]}${h[15]}';
}
