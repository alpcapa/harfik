import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/util/semver.dart';
import 'package:kelimeki/src/util/uuid.dart';

void main() {
  group('compareSemver', () {
    test('temel karşılaştırmalar', () {
      expect(compareSemver('1.0.0', '1.0.0'), 0);
      expect(compareSemver('0.9.9', '1.0.0'), -1);
      expect(compareSemver('1.0.1', '1.0.0'), 1);
      expect(compareSemver('1.10.0', '1.9.0'), 1); // sayısal, sözlüksel değil
      expect(compareSemver('2.0', '2.0.0'), 0); // eksik alan 0
      expect(compareSemver('1.2.3+7', '1.2.3'), 0); // build eki yok sayılır
      expect(compareSemver('0.0.0', '0.1.0'),
          -1); // seed eşiği hiçbir şeyi engellemez
    });
  });

  group('uuidV4', () {
    test('RFC 4122 biçimi ve benzersizlik', () {
      final re = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      final seen = <String>{};
      for (var i = 0; i < 1000; i++) {
        final u = uuidV4();
        expect(re.hasMatch(u), isTrue, reason: 'geçersiz uuid: $u');
        expect(seen.add(u), isTrue, reason: 'tekrarlanan uuid: $u');
      }
    });
  });
}
