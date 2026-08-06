// Tek kelimenin sözlük kaydı — web `WordMeaning` (src/lib/database.types.ts)
// eşleniği: TDK sözcük türü kısaltması (opsiyonel) + anlam listesi.
import 'dart:convert';

class MeaningEntry {
  /// "a.", "sf.", "-i" gibi tür kısaltması; yoksa null.
  final String? pos;
  final List<String> meanings;

  const MeaningEntry({required this.pos, required this.meanings});

  factory MeaningEntry.fromRow(Map<String, Object?> row) {
    final raw = row['meanings'];
    final decoded = raw is String ? jsonDecode(raw) : const [];
    return MeaningEntry(
      pos: row['pos'] as String?,
      meanings: [
        for (final m in decoded is List ? decoded : const []) m.toString(),
      ],
    );
  }
}
