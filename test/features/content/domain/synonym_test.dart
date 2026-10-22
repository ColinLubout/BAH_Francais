import 'package:bah_francais/features/content/domain/content_types.dart';
import 'package:bah_francais/features/content/domain/synonym.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('synonyms are equal when word, gender and elision are', () {
    const a = Synonym('auto', elides: true);
    expect(a, const Synonym('auto', elides: true));
    expect(a.hashCode, const Synonym('auto', elides: true).hashCode);
    expect(a, isNot(const Synonym('auto')));
    expect(a, isNot(const Synonym('auto', gender: Gender.feminine)));
    expect(a.toString(), 'Synonym(auto, null, true)');
  });
}
