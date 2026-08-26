import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/models/create_story_model.dart';

void main() {
  group('CreateStoryModel equality', () {
    test('equal when media bytes, mediaType, and caption match by content', () {
      final a = CreateStoryModel(
        media: Uint8List.fromList([1, 2, 3]),
        mediaType: MediaType.image,
        caption: 'hello',
      );
      final b = CreateStoryModel(
        media: Uint8List.fromList([1, 2, 3]),
        mediaType: MediaType.image,
        caption: 'hello',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when media bytes differ', () {
      final a = CreateStoryModel(
        media: Uint8List.fromList([1, 2, 3]),
        mediaType: MediaType.image,
      );
      final b = CreateStoryModel(
        media: Uint8List.fromList([1, 2, 4]),
        mediaType: MediaType.image,
      );

      expect(a, isNot(equals(b)));
    });

    test('not equal when mediaType differs', () {
      final a = CreateStoryModel(
        media: Uint8List.fromList([1, 2, 3]),
        mediaType: MediaType.image,
      );
      final b = CreateStoryModel(
        media: Uint8List.fromList([1, 2, 3]),
        mediaType: MediaType.video,
      );

      expect(a, isNot(equals(b)));
    });

    test('not equal when caption differs', () {
      final a = CreateStoryModel(
        media: Uint8List.fromList([1, 2, 3]),
        mediaType: MediaType.image,
        caption: 'a',
      );
      final b = CreateStoryModel(
        media: Uint8List.fromList([1, 2, 3]),
        mediaType: MediaType.image,
        caption: 'b',
      );

      expect(a, isNot(equals(b)));
    });
  });
}
