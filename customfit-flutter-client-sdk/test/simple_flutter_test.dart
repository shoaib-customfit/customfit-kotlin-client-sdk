import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Simple Flutter Test', () {
    test('Test basic Dart functionality', () {
      expect(1 + 1, equals(2));
      expect('hello'.toUpperCase(), equals('HELLO'));
    });

    test('Test list operations', () {
      final list = [1, 2, 3];
      expect(list.length, equals(3));
      expect(list.contains(2), isTrue);
    });

    test('Test map operations', () {
      final map = {'key1': 'value1', 'key2': 'value2'};
      expect(map['key1'], equals('value1'));
      expect(map.keys.length, equals(2));
    });
  });
} 