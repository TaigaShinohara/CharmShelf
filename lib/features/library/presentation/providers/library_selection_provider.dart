import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'library_selection_provider.g.dart';

/// 複数選択状態のイミュータブルな状態データ
class LibrarySelectionState {
  final bool isSelectionMode;
  final Set<int> selectedIds;

  const LibrarySelectionState({
    this.isSelectionMode = false,
    this.selectedIds = const {},
  });

  int get selectedCount => selectedIds.length;
  bool isSelected(int id) => selectedIds.contains(id);

  LibrarySelectionState copyWith({
    bool? isSelectionMode,
    Set<int>? selectedIds,
  }) {
    return LibrarySelectionState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

@riverpod
class LibrarySelectionNotifier extends _$LibrarySelectionNotifier {
  @override
  LibrarySelectionState build() {
    return const LibrarySelectionState();
  }

  void toggleSelectionMode() {
    final nextMode = !state.isSelectionMode;
    state = state.copyWith(
      isSelectionMode: nextMode,
      selectedIds: nextMode ? state.selectedIds : const {},
    );
  }

  void toggleSelection(int id) {
    final nextSelected = Set<int>.from(state.selectedIds);
    if (nextSelected.contains(id)) {
      nextSelected.remove(id);
      final nextMode = nextSelected.isNotEmpty && state.isSelectionMode;
      state = state.copyWith(
        isSelectionMode: nextMode,
        selectedIds: nextSelected,
      );
    } else {
      nextSelected.add(id);
      state = state.copyWith(isSelectionMode: true, selectedIds: nextSelected);
    }
  }

  void selectAll(Iterable<int> ids) {
    state = state.copyWith(
      isSelectionMode: true,
      selectedIds: Set<int>.from(ids),
    );
  }

  void deselectAll() {
    state = state.copyWith(selectedIds: const {});
  }

  void clearSelection() {
    state = const LibrarySelectionState();
  }
}
