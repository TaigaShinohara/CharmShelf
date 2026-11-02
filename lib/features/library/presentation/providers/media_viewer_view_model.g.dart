// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_viewer_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MediaViewerViewModel)
final mediaViewerViewModelProvider = MediaViewerViewModelProvider._();

final class MediaViewerViewModelProvider
    extends $NotifierProvider<MediaViewerViewModel, MediaViewerState> {
  MediaViewerViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaViewerViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaViewerViewModelHash();

  @$internal
  @override
  MediaViewerViewModel create() => MediaViewerViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaViewerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaViewerState>(value),
    );
  }
}

String _$mediaViewerViewModelHash() =>
    r'25736af72dffc633021fe659109ddd2c8a6d7f71';

abstract class _$MediaViewerViewModel extends $Notifier<MediaViewerState> {
  MediaViewerState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MediaViewerState, MediaViewerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MediaViewerState, MediaViewerState>,
              MediaViewerState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
