// Web tarafı — bkz. web_db.dart. Bu dosya mobil derlemede HİÇ derlenmez.
//
// `databaseFactoryFfiWeb` bir shared worker (web/sqflite_sw.js) + WASM
// sqlite3 (web/sqlite3.wasm) kullanır; ikisi de `dart run
// sqflite_common_ffi_web:setup` ile web/ altına konur ve depoda tutulur —
// derleme anında ağdan indirilmez.
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

DatabaseFactory? webDatabaseFactory() => databaseFactoryFfiWeb;
