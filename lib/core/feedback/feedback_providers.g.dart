// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedback_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HapticsEnabledAsync)
final hapticsEnabledAsyncProvider = HapticsEnabledAsyncProvider._();

final class HapticsEnabledAsyncProvider
    extends $AsyncNotifierProvider<HapticsEnabledAsync, bool> {
  HapticsEnabledAsyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hapticsEnabledAsyncProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hapticsEnabledAsyncHash();

  @$internal
  @override
  HapticsEnabledAsync create() => HapticsEnabledAsync();
}

String _$hapticsEnabledAsyncHash() =>
    r'2e5e7bc701fb2e2e1a977932592c262fcdfcc32c';

abstract class _$HapticsEnabledAsync extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(hapticsEnabled)
final hapticsEnabledProvider = HapticsEnabledProvider._();

final class HapticsEnabledProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  HapticsEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hapticsEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hapticsEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return hapticsEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hapticsEnabledHash() => r'6b9b7e0b6940c1bc85f0863197a6c5b8db07d93d';

@ProviderFor(SoundEnabledAsync)
final soundEnabledAsyncProvider = SoundEnabledAsyncProvider._();

final class SoundEnabledAsyncProvider
    extends $AsyncNotifierProvider<SoundEnabledAsync, bool> {
  SoundEnabledAsyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soundEnabledAsyncProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soundEnabledAsyncHash();

  @$internal
  @override
  SoundEnabledAsync create() => SoundEnabledAsync();
}

String _$soundEnabledAsyncHash() => r'bf482557e1a9cf7045ed6a79136e3bc4914322ed';

abstract class _$SoundEnabledAsync extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(soundEnabled)
final soundEnabledProvider = SoundEnabledProvider._();

final class SoundEnabledProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  SoundEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soundEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soundEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return soundEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$soundEnabledHash() => r'35ceb89e26469897507dfc95eabaf30e1cfd47c2';

@ProviderFor(soundService)
final soundServiceProvider = SoundServiceProvider._();

final class SoundServiceProvider
    extends $FunctionalProvider<SoundService, SoundService, SoundService>
    with $Provider<SoundService> {
  SoundServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'soundServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$soundServiceHash();

  @$internal
  @override
  $ProviderElement<SoundService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SoundService create(Ref ref) {
    return soundService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SoundService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SoundService>(value),
    );
  }
}

String _$soundServiceHash() => r'bfa61d37a2c3795952c4870e72fbec10c33f8a49';

@ProviderFor(feedbackService)
final feedbackServiceProvider = FeedbackServiceProvider._();

final class FeedbackServiceProvider
    extends
        $FunctionalProvider<FeedbackService, FeedbackService, FeedbackService>
    with $Provider<FeedbackService> {
  FeedbackServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedbackServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedbackServiceHash();

  @$internal
  @override
  $ProviderElement<FeedbackService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FeedbackService create(Ref ref) {
    return feedbackService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeedbackService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeedbackService>(value),
    );
  }
}

String _$feedbackServiceHash() => r'87d4f46d1517f3f36b86f189efb797fb06ad0a4f';
