// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_filter_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MediaFilterNotifier)
final mediaFilterNotifierProvider = MediaFilterNotifierFamily._();

final class MediaFilterNotifierProvider
    extends $NotifierProvider<MediaFilterNotifier, MediaFilter> {
  MediaFilterNotifierProvider._({
    required MediaFilterNotifierFamily super.from,
    required AppMode super.argument,
  }) : super(
         retry: null,
         name: r'mediaFilterNotifierProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaFilterNotifierHash();

  @override
  String toString() {
    return r'mediaFilterNotifierProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MediaFilterNotifier create() => MediaFilterNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaFilter>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MediaFilterNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaFilterNotifierHash() =>
    r'c2bda71d7617229799b56c1e27c430f659562784';

final class MediaFilterNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          MediaFilterNotifier,
          MediaFilter,
          MediaFilter,
          MediaFilter,
          AppMode
        > {
  MediaFilterNotifierFamily._()
    : super(
        retry: null,
        name: r'mediaFilterNotifierProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MediaFilterNotifierProvider call(AppMode mode) =>
      MediaFilterNotifierProvider._(argument: mode, from: this);

  @override
  String toString() => r'mediaFilterNotifierProvider';
}

abstract class _$MediaFilterNotifier extends $Notifier<MediaFilter> {
  late final _$args = ref.$arg as AppMode;
  AppMode get mode => _$args;

  MediaFilter build(AppMode mode);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MediaFilter, MediaFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MediaFilter, MediaFilter>,
              MediaFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
