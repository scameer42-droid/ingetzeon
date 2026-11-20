import 'package:flutter_test/flutter_test.dart';
import 'package:ingetzeon/services/translate_service.dart';

void main() {
  test('hasil terjemahan ngawur dibuang', () {
    expect(TranslateService.sane('saya mau makan', 'Google Translate'), isFalse);
    expect(TranslateService.sane('saya mau makan nasi goreng', 'Saya mau makan nasi goreng'), isFalse);
    expect(TranslateService.sane('saya mau makan', 'I want to eat'), isTrue);
    expect(TranslateService.sane('singa', 'lion'), isTrue);
    expect(TranslateService.sane('Google', 'Google'), isTrue);
    expect(TranslateService.sane('buka google translate', 'open google translate'), isTrue);
  });
}
