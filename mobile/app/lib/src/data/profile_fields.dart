// Profil alanları — src/utils/profileFields.ts portu (kayıt formu ve
// ileride hesap ayarları arasında ortak).

/// Web GENDER_OPTIONS — değerler `profiles.gender` sütunuyla birebir.
const genderOptions = <(String value, String label)>[
  ('female', 'Kadın'),
  ('male', 'Erkek'),
];

/// Doğum tarihi metin alanına yazarken "/" ayırıcılarını otomatik ekler
/// (ör. "01011990" → "01/01/1990") — web formatTrDateInput birebir.
String formatTrDateInput(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final d = digits.length > 8 ? digits.substring(0, 8) : digits;
  if (d.length > 4) {
    return '${d.substring(0, 2)}/${d.substring(2, 4)}/${d.substring(4)}';
  }
  if (d.length > 2) return '${d.substring(0, 2)}/${d.substring(2)}';
  return d;
}

/// "gg/aa/yyyy" girdisini `date` sütununa uygun ISO dizgeye çevirir; boşsa
/// null, bozuksa Türkçe mesajla fırlatır — web trDateToIso birebir
/// (hata metinleri dahil).
String? trDateToIso(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  final m = RegExp(r'^(\d{1,2})[./](\d{1,2})[./](\d{4})$').firstMatch(s);
  if (m == null) {
    throw const FormatException('Doğum tarihini GG/AA/YYYY biçiminde gir.');
  }
  final d = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final y = int.parse(m.group(3)!);
  if (y < 1900 || y > DateTime.now().year) {
    throw const FormatException('Doğum yılı geçersiz.');
  }
  if (mo < 1 || mo > 12) throw const FormatException('Doğum ayı geçersiz.');
  final date = DateTime(y, mo, d);
  if (date.year != y || date.month != mo || date.day != d) {
    throw const FormatException('Geçersiz doğum tarihi.');
  }
  final mm = mo.toString().padLeft(2, '0');
  final dd = d.toString().padLeft(2, '0');
  return '${y.toString().padLeft(4, '0')}-$mm-$dd';
}

/// ISO `yyyy-mm-dd` → "gg/aa/yyyy" (hesap ayarları fazında kullanılacak).
String isoToTrDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final parts = iso.split('-');
  if (parts.length != 3) return '';
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}
