// Supabase istemci kurulumu — src/lib/supabase.ts'in eşleniği:
// anahtarlar yoksa null döner, uygulama tamamen offline çalışır.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

Future<SupabaseClient?> initSupabase() async {
  if (!supabaseConfigured) return null;
  // `anonKey` deprecated uyarısı BİLİNÇLİ olarak susturuluyor: web istemcisi
  // (VITE_SUPABASE_ANON_KEY) legacy anon key kullanıyor; publishable key'e
  // geçiş iki istemcinin BİRLİKTE vereceği ayrı bir karar — tek taraflı
  // geçmek iki farklı anahtar türünü aynı anda yönetmek demek olurdu.
  // ignore: deprecated_member_use
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  return Supabase.instance.client;
}
