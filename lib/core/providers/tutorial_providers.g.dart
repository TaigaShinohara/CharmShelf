// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tutorial_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TutorialState)
final tutorialStateProvider = TutorialStateProvider._();

final class TutorialStateProvider
    extends $AsyncNotifierProvider<TutorialState, Map<String, bool>> {
  TutorialStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tutorialStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tutorialStateHash();

  @$internal
  @override
  TutorialState create() => TutorialState();
}

String _$tutorialStateHash() => r'bfb893198813f2cc7c3508320278ff2cdc66876d';

abstract class _$TutorialState extends $AsyncNotifier<Map<String, bool>> {
  FutureOr<Map<String, bool>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<Map<String, bool>>, Map<String, bool>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Map<String, bool>>, Map<String, bool>>,
              AsyncValue<Map<String, bool>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
