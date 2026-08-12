// Mobil (iOS/Android/masaüstü) tarafı — bkz. web_db.dart.
// Her zaman null döner; çağıran `databaseFactory`ye (sqflite'ın native
// platform kanalı) düşer, yani davranış web öncesiyle BİREBİR aynıdır.
import 'package:sqflite/sqflite.dart';

DatabaseFactory? webDatabaseFactory() => null;
