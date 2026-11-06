// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pwa_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PwaController)
final pwaControllerProvider = PwaControllerProvider._();

final class PwaControllerProvider
    extends $NotifierProvider<PwaController, PwaState> {
  PwaControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'pwaControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$pwaControllerHash();

  @$internal
  @override
  PwaController create() => PwaController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PwaState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PwaState>(value),
    );
  }
}

String _$pwaControllerHash() => r'd86971cea249dd198b42e517629d84410edb8e93';

abstract class _$PwaController extends $Notifier<PwaState> {
  PwaState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PwaState, PwaState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<PwaState, PwaState>, PwaState, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}
