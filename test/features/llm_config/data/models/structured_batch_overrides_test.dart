import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/structured_batch_overrides.dart';

void main() {
  group('StructuredBatchOverrides', () {
    test('defaults to all-disabled state', () {
      const StructuredBatchOverrides o = StructuredBatchOverrides();
      expect(o.enabled, isFalse);
      expect(o.overrideMedium, isFalse);
      expect(o.medium, isNull);
      expect(o.overrideBackground, isFalse);
      expect(o.background, isNull);
    });

    test('toJson includes nullable fields only when set', () {
      const StructuredBatchOverrides empty = StructuredBatchOverrides();
      expect(empty.toJson(), <String, dynamic>{
        'enabled': false,
        'overrideMedium': false,
        'overrideAesthetics': false,
        'overrideLighting': false,
        'overrideBackground': false,
      });

      const StructuredBatchOverrides full = StructuredBatchOverrides(
        enabled: true,
        overrideMedium: true,
        medium: 'oil painting',
        styleMode: 'art_style',
        styleDetail: 'impressionist',
      );
      final Map<String, dynamic> json = full.toJson();
      expect(json['medium'], 'oil painting');
      expect(json['styleMode'], 'art_style');
      expect(json['styleDetail'], 'impressionist');
    });

    test('fromJson restores every field', () {
      final StructuredBatchOverrides o =
          StructuredBatchOverrides.fromJson(const <String, dynamic>{
            'enabled': true,
            'overrideMedium': true,
            'medium': 'photograph',
            'overrideAesthetics': false,
            'aesthetics': null,
            'overrideLighting': true,
            'lighting': 'soft',
            'styleMode': 'photo',
            'styleDetail': '35mm',
            'overrideBackground': false,
            'background': null,
          });
      expect(o.enabled, isTrue);
      expect(o.overrideMedium, isTrue);
      expect(o.medium, 'photograph');
      expect(o.aesthetics, isNull);
      expect(o.overrideLighting, isTrue);
      expect(o.lighting, 'soft');
      expect(o.styleMode, 'photo');
      expect(o.styleDetail, '35mm');
    });

    test('fromJson tolerates missing keys with defaults', () {
      final StructuredBatchOverrides o = StructuredBatchOverrides.fromJson(
        const <String, dynamic>{},
      );
      expect(o.enabled, isFalse);
      expect(o.overrideMedium, isFalse);
      expect(o.medium, isNull);
    });

    group('copyWith clears nullable fields via explicit flags', () {
      const StructuredBatchOverrides base = StructuredBatchOverrides(
        enabled: true,
        medium: 'photograph',
        aesthetics: 'warm',
        lighting: 'soft',
        styleMode: 'photo',
        styleDetail: '35mm',
        background: 'wall',
      );

      test('clearMedium resets medium to null', () {
        final StructuredBatchOverrides o = base.copyWith(clearMedium: true);
        expect(o.medium, isNull);
        expect(o.aesthetics, 'warm'); // untouched
      });

      test('clearAesthetics resets aesthetics to null', () {
        expect(base.copyWith(clearAesthetics: true).aesthetics, isNull);
      });

      test('clearLighting resets lighting to null', () {
        expect(base.copyWith(clearLighting: true).lighting, isNull);
      });

      test('clearStyleMode resets styleMode to null', () {
        expect(base.copyWith(clearStyleMode: true).styleMode, isNull);
      });

      test('clearStyleDetail resets styleDetail to null', () {
        expect(base.copyWith(clearStyleDetail: true).styleDetail, isNull);
      });

      test('clearBackground resets background to null', () {
        expect(base.copyWith(clearBackground: true).background, isNull);
      });

      test('clear flag wins over a simultaneously supplied value', () {
        // ponytail: matches the copyWith ternary — clearMedium is checked first.
        final StructuredBatchOverrides o = base.copyWith(
          medium: 'canvas',
          clearMedium: true,
        );
        expect(o.medium, isNull);
      });

      test('non-cleared fields retain their values', () {
        final StructuredBatchOverrides o = base.copyWith(clearBackground: true);
        expect(o.enabled, isTrue);
        expect(o.medium, 'photograph');
        expect(o.styleDetail, '35mm');
      });
    });

    test('Equatable treats same field set as equal', () {
      const StructuredBatchOverrides a = StructuredBatchOverrides(
        enabled: true,
        medium: 'x',
      );
      const StructuredBatchOverrides b = StructuredBatchOverrides(
        enabled: true,
        medium: 'x',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
