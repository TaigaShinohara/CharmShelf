// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'viewer_pages_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(viewerPages)
final viewerPagesProvider = ViewerPagesFamily._();

final class ViewerPagesProvider
    extends
        $FunctionalProvider<
          List<ViewerPage>,
          List<ViewerPage>,
          List<ViewerPage>
        >
    with $Provider<List<ViewerPage>> {
  ViewerPagesProvider._({
    required ViewerPagesFamily super.from,
    required ViewerPagesParam super.argument,
  }) : super(
         retry: null,
         name: r'viewerPagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$viewerPagesHash();

  @override
  String toString() {
    return r'viewerPagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<ViewerPage>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<ViewerPage> create(Ref ref) {
    final argument = this.argument as ViewerPagesParam;
    return viewerPages(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ViewerPage> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ViewerPage>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ViewerPagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$viewerPagesHash() => r'7dd8ec2116de73143892dd87f137558f45de6a31';

final class ViewerPagesFamily extends $Family
    with $FunctionalFamilyOverride<List<ViewerPage>, ViewerPagesParam> {
  ViewerPagesFamily._()
    : super(
        retry: null,
        name: r'viewerPagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ViewerPagesProvider call(ViewerPagesParam param) =>
      ViewerPagesProvider._(argument: param, from: this);

  @override
  String toString() => r'viewerPagesProvider';
}
