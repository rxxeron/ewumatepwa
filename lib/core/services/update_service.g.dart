// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(updateListener)
final updateListenerProvider = UpdateListenerProvider._();

final class UpdateListenerProvider extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  UpdateListenerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'updateListenerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$updateListenerHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return updateListener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$updateListenerHash() => r'8893721ac48cbd6ae5ee9d46e96e7e04b7cd8ab6';
