// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_tree_thumbnail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(fileTreeNodeThumbnail)
final fileTreeNodeThumbnailProvider = FileTreeNodeThumbnailFamily._();

final class FileTreeNodeThumbnailProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          FutureOr<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $FutureProvider<Uint8List?> {
  FileTreeNodeThumbnailProvider._({
    required FileTreeNodeThumbnailFamily super.from,
    required FileTreeNode super.argument,
  }) : super(
         retry: null,
         name: r'fileTreeNodeThumbnailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fileTreeNodeThumbnailHash();

  @override
  String toString() {
    return r'fileTreeNodeThumbnailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Uint8List?> create(Ref ref) {
    final argument = this.argument as FileTreeNode;
    return fileTreeNodeThumbnail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FileTreeNodeThumbnailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fileTreeNodeThumbnailHash() =>
    r'01122194c40a332601c4e29a021fd2e4cbf93636';

final class FileTreeNodeThumbnailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Uint8List?>, FileTreeNode> {
  FileTreeNodeThumbnailFamily._()
    : super(
        retry: null,
        name: r'fileTreeNodeThumbnailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FileTreeNodeThumbnailProvider call(FileTreeNode node) =>
      FileTreeNodeThumbnailProvider._(argument: node, from: this);

  @override
  String toString() => r'fileTreeNodeThumbnailProvider';
}
