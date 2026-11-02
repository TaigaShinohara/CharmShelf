// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(privacyRepository)
final privacyRepositoryProvider = PrivacyRepositoryProvider._();

final class PrivacyRepositoryProvider
    extends
        $FunctionalProvider<
          PrivacyRepository,
          PrivacyRepository,
          PrivacyRepository
        >
    with $Provider<PrivacyRepository> {
  PrivacyRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privacyRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privacyRepositoryHash();

  @$internal
  @override
  $ProviderElement<PrivacyRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PrivacyRepository create(Ref ref) {
    return privacyRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrivacyRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrivacyRepository>(value),
    );
  }
}

String _$privacyRepositoryHash() => r'380ee08ce77b87be29d42be5ffd7e80e1de4f229';

@ProviderFor(hasPasscode)
final hasPasscodeProvider = HasPasscodeProvider._();

final class HasPasscodeProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  HasPasscodeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasPasscodeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasPasscodeHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return hasPasscode(ref);
  }
}

String _$hasPasscodeHash() => r'4b626bf435c6150dea21e361e879961002055e14';

@ProviderFor(PrivacySettingsNotifier)
final privacySettingsNotifierProvider = PrivacySettingsNotifierProvider._();

final class PrivacySettingsNotifierProvider
    extends $AsyncNotifierProvider<PrivacySettingsNotifier, PrivacySettings> {
  PrivacySettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privacySettingsNotifierProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privacySettingsNotifierHash();

  @$internal
  @override
  PrivacySettingsNotifier create() => PrivacySettingsNotifier();
}

String _$privacySettingsNotifierHash() =>
    r'ee97b834f800361a85f9f5e33c96f593bee53c66';

abstract class _$PrivacySettingsNotifier
    extends $AsyncNotifier<PrivacySettings> {
  FutureOr<PrivacySettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PrivacySettings>, PrivacySettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PrivacySettings>, PrivacySettings>,
              AsyncValue<PrivacySettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
