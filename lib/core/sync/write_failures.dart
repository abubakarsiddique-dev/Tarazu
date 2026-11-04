import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the user was trying to do when a background write failed.
enum WriteKind { slip, voidSlip, material, other }

typedef WriteErrorHandler = void Function(WriteKind kind, Object error);

/// Starts a Firestore write WITHOUT awaiting it (offline-first: the future only
/// completes once the server confirms) but never swallows a failure.
/// If the server rejects the write, the local cache silently reverts, so the
/// user must be told or they will think the entry was saved.
void sendWrite(Future<void> write, WriteKind kind, WriteErrorHandler? onError) {
  write.catchError((Object e, StackTrace s) {
    debugPrint('Firestore write failed ($kind): $e');
    onError?.call(kind, e);
  });
}

// Kept here so this feature is a pure copy-paste. Move into AppStrings later
// if you want all texts (and a future Urdu translation) in one place.
const errSlipRejected =
    'The last purchase slip could not be saved and was removed. Please enter it again.';
const errVoidRejected = 'The purchase could not be cancelled. Please try again.';
const errMaterialRejected = 'The material change could not be saved. Please try again.';
const errWriteRejected = 'A change could not be saved. Please try again.';

/// One failure event. Deliberately has no == override, so two failures in a row
/// are two different events and both reach listeners.
class WriteFailure {
  WriteFailure(this.kind, this.error);

  final WriteKind kind;
  final Object error;

  String get message => switch (kind) {
        WriteKind.slip => errSlipRejected,
        WriteKind.voidSlip => errVoidRejected,
        WriteKind.material => errMaterialRejected,
        WriteKind.other => errWriteRejected,
      };
}

class WriteFailureNotifier extends Notifier<WriteFailure?> {
  @override
  WriteFailure? build() => null;

  void report(WriteKind kind, Object error) => state = WriteFailure(kind, error);
}

final writeFailureProvider =
    NotifierProvider<WriteFailureNotifier, WriteFailure?>(WriteFailureNotifier.new);
