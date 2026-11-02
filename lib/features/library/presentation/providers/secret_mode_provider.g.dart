// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secret_mode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SecretMode)
final secretModeProvider = SecretModeProvider._();

final class SecretModeProvider
    extends $AsyncNotifierProvider<SecretMode, bool> {
  SecretModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secretModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secretModeHash();

  @$internal
  @override
  SecretMode create() => SecretMode();
}

String _$secretModeHash() => r'e168c8719f58c5f7b80e8035a76306bae2a7a1e5';

abstract class _$SecretMode extends $AsyncNotifier<bool> {
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
