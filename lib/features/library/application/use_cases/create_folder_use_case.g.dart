// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_folder_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(createFolderUseCase)
final createFolderUseCaseProvider = CreateFolderUseCaseProvider._();

final class CreateFolderUseCaseProvider
    extends
        $FunctionalProvider<
          CreateFolderUseCase,
          CreateFolderUseCase,
          CreateFolderUseCase
        >
    with $Provider<CreateFolderUseCase> {
  CreateFolderUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'createFolderUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$createFolderUseCaseHash();

  @$internal
  @override
  $ProviderElement<CreateFolderUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CreateFolderUseCase create(Ref ref) {
    return createFolderUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreateFolderUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreateFolderUseCase>(value),
    );
  }
}

String _$createFolderUseCaseHash() =>
    r'9bc8c12cb92ab325057981f03c2cbeeb249f021c';
