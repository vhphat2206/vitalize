import 'package:flutter_test/flutter_test.dart';
import 'package:vitalize/logic/search.dart';

void main() {
  test('foldVi drops the marks and the case', () {
    expect(foldVi('Bánh Mì Đặc Biệt'), 'banh mi dac biet');
    expect(foldVi('Phở bò tái'), 'pho bo tai');
  });

  test('matchesVi finds every word, in any order', () {
    expect(matchesVi('Ức gà luộc', 'uc ga'), isTrue);
    expect(matchesVi('Ức gà luộc', 'ga uc'), isTrue);
    expect(matchesVi('Ức gà luộc', 'bo'), isFalse);
    expect(matchesVi('Phở bò tái', '  '), isTrue);
  });
}
