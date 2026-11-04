import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarazu/core/sync/write_failures.dart';

void main() {
  group('sendWrite', () {
    test('reports a failed write with its kind', () async {
      WriteKind? gotKind;
      Object? gotError;

      sendWrite(
        Future<void>.error(StateError('rejected')),
        WriteKind.slip,
        (kind, error) {
          gotKind = kind;
          gotError = error;
        },
      );
      await Future<void>.delayed(Duration.zero);

      expect(gotKind, WriteKind.slip);
      expect(gotError, isA<StateError>());
    });

    test('does not call the handler when the write succeeds', () async {
      var called = false;
      sendWrite(Future<void>.value(), WriteKind.slip, (_, _) => called = true);
      await Future<void>.delayed(Duration.zero);
      expect(called, isFalse);
    });

    test('does not crash when no handler is given', () async {
      sendWrite(Future<void>.error(StateError('x')), WriteKind.other, null);
      await Future<void>.delayed(Duration.zero); // would throw if unhandled
    });
  });

  group('writeFailureProvider', () {
    test('starts empty', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(writeFailureProvider), isNull);
    });

    test('two failures in a row are two separate events', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final seen = <WriteFailure?>[];
      c.listen<WriteFailure?>(writeFailureProvider, (_, next) => seen.add(next));

      final n = c.read(writeFailureProvider.notifier);
      n.report(WriteKind.slip, StateError('a'));
      n.report(WriteKind.slip, StateError('a'));

      expect(seen.length, 2);
    });

    test('message depends on what failed', () {
      expect(WriteFailure(WriteKind.slip, 'x').message, errSlipRejected);
      expect(WriteFailure(WriteKind.voidSlip, 'x').message, errVoidRejected);
      expect(WriteFailure(WriteKind.material, 'x').message, errMaterialRejected);
      expect(WriteFailure(WriteKind.sale, 'x').message, errSaleRejected);
      expect(WriteFailure(WriteKind.voidSale, 'x').message, errVoidSaleRejected);
      expect(WriteFailure(WriteKind.adjustment, 'x').message, errAdjustRejected);
      expect(WriteFailure(WriteKind.other, 'x').message, errWriteRejected);
    });
  });
}
