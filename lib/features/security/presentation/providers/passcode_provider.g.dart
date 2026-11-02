// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passcode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PasscodeNotifier)
final passcodeNotifierProvider = PasscodeNotifierFamily._();

final class PasscodeNotifierProvider
    extends $NotifierProvider<PasscodeNotifier, PasscodeState> {
  PasscodeNotifierProvider._({
    required PasscodeNotifierFamily super.from,
    required PasscodeMode super.argument,
  }) : super(
         retry: null,
         name: r'passcodeNotifierProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$passcodeNotifierHash();

  @override
  String toString() {
    return r'passcodeNotifierProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PasscodeNotifier create() => PasscodeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PasscodeState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PasscodeState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PasscodeNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$passcodeNotifierHash() => r'eced8814ded39f1c0405c789b49fb6b164df65af';

final class PasscodeNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          PasscodeNotifier,
          PasscodeState,
          PasscodeState,
          PasscodeState,
          PasscodeMode
        > {
  PasscodeNotifierFamily._()
    : super(
        retry: null,
        name: r'passcodeNotifierProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PasscodeNotifierProvider call(PasscodeMode mode) =>
      PasscodeNotifierProvider._(argument: mode, from: this);

  @override
  String toString() => r'passcodeNotifierProvider';
}

abstract class _$PasscodeNotifier extends $Notifier<PasscodeState> {
  late final _$args = ref.$arg as PasscodeMode;
  PasscodeMode get mode => _$args;

  PasscodeState build(PasscodeMode mode);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PasscodeState, PasscodeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PasscodeState, PasscodeState>,
              PasscodeState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
