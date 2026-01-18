# Refactor Plan: Caption Search Bar

## Current Issues

1. **Single monolithic file**: `caption_search_bar.dart` is 314 lines with all logic mixed in the UI
2. **UI state in widget**: Expansion state, replace mode, and animations are managed by the StatefulWidget
3. **Tight coupling**: Widget directly depends on `ImageListCubit` for search operations
4. **Not following project architecture**: Other features use the `logic/` layer with Cubits

## Proposed Architecture

Create a new `caption_search` feature following the existing pattern:

```
lib/features/caption_search/
├── logic/
│   ├── caption_search_cubit.dart      # Manages UI state and search logic
│   └── caption_search_state.dart      # State definition (part file)
└── presentation/
    └── widgets/
        └── caption_search_bar.dart    # Clean UI widget
```

## Detailed Breakdown

### 1. State Management (`caption_search_state.dart`)

**Responsibilities**: Hold immutable state

```dart
part of 'caption_search_cubit.dart';

class CaptionSearchState extends Equatable {
  final bool isExpanded;
  final bool showReplaceMode;
  final String searchQuery;     // Local copy for UI
  final String replaceText;     // Local copy for UI

  const CaptionSearchState({
    this.isExpanded = false,
    this.showReplaceMode = false,
    this.searchQuery = '',
    this.replaceText = '',
  });

  CaptionSearchState copyWith({...});
  props [...]
}
```

### 2. Business Logic (`caption_search_cubit.dart`)

**Responsibilities**:
- Manage UI state (expanded/collapsed, replace mode)
- Handle user interactions (toggle, clear, execute)
- Delegate to `ImageListCubit` for actual search/replace operations
- Provide computed values for the UI

**Key Methods**:
```dart
class CaptionSearchCubit extends Emitible<CaptionSearchState> {
  final ImageListCubit imageListCubit;

  // UI State Management
  void toggleExpanded();
  void toggleReplaceMode();
  void updateSearchQuery(String query);
  void updateReplaceText(String text);
  void clearSearch();

  // Actions
  Future<void> executeReplace();

  // Computed Properties (getters)
  int get resultCount => imageListCubit.filteredImages.length;
  int get totalCount => imageListCubit.state.images.length;
  bool get canExecuteReplace => state.replaceText.isNotEmpty;
}
```

### 3. UI Widget (`caption_search_bar.dart`)

**Responsibilities**: Pure presentation with BlocBuilder

- Keep animations (AnimationController needs StatefulWidget)
- Keep TextEditingController and FocusNode (UI concerns)
- Listen to cubit state changes
- Delegate all actions to cubit

**Structure**:
```dart
class CaptionSearchBar extends StatefulWidget {
  @override
  State<CaptionSearchBar> createState() => _CaptionSearchBarState();
}

class _CaptionSearchBarState extends State<CaptionSearchBar>
    with SingleTickerProviderStateMixin {

  // UI-only concerns remain:
  // - AnimationController
  // - TextEditingController
  // - FocusNode
  // - Animation setup

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CaptionSearchCubit, CaptionSearchState>(
      builder: (context, state) {
        // Pure UI based on state
      },
    );
  }
}
```

## Migration Steps

### Phase 1: Create New Structure (Non-breaking)
1. Create `lib/features/caption_search/logic/` directory
2. Create `caption_search_cubit.dart` with state
3. Create `caption_search_state.dart` as part file
4. Create `lib/features/caption_search/presentation/widgets/` directory
5. Create new `caption_search_bar.dart` in new location

### Phase 2: Implement Cubit Logic
1. Move state variables from widget to `CaptionSearchState`
2. Move business logic methods to `CaptionSearchCubit`
3. Add `ImageListCubit` dependency injection
4. Register `CaptionSearchCubit` in service_locator

### Phase 3: Update UI Widget
1. Rewrite widget to use `CaptionSearchCubit` instead of local state
2. Keep animation controllers in widget (UI concern)
3. Replace all `setState()` calls with cubit method calls
4. Use `BlocBuilder` for reactive UI updates

### Phase 4: Integration
1. Update `main_area_view.dart` to provide new `CaptionSearchCubit`
2. Update imports across the app
3. Test all functionality

### Phase 5: Cleanup
1. Delete old `lib/features/main_area/presentation/widgets/caption_search_bar.dart`
2. Update service_locator if needed
3. Run tests and fix any issues
4. Run `flutter analyze`

## File Size Comparison

### Before
- `caption_search_bar.dart`: ~314 lines (logic + UI mixed)

### After
- `caption_search_cubit.dart`: ~100-120 lines (pure business logic)
- `caption_search_state.dart`: ~30-40 lines (immutable state)
- `caption_search_bar.dart`: ~150-180 lines (pure UI)

**Result**: Each file has a single, clear responsibility

## Benefits

1. **Separation of Concerns**: UI vs business logic clearly separated
2. **Testability**: Can test cubit logic without widget tests
3. **Reusability**: Cubit can be used by multiple widgets if needed
4. **Maintainability**: Easier to find and modify specific behavior
5. **Consistency**: Matches the architecture of other features
6. **State Management**: Follows BLoC pattern used throughout the app

## Dependencies

### CaptionSearchCubit depends on:
- `ImageListCubit` (for search/replace operations)

### CaptionSearchBar depends on:
- `CaptionSearchCubit` (for state and actions)
- Flutter animation APIs (UI concern)

## Testing Strategy

### Unit Tests for CaptionSearchCubit
```dart
test('initial state is collapsed', () {
  expect(cubit.state.isExpanded, false);
});

test('toggleExpanded changes state', () {
  cubit.toggleExpanded();
  expect(cubit.state.isExpanded, true);
});

test('executeReplace calls ImageListCubit.searchAndReplace', () {
  // Mock ImageListCubit
  // Call executeReplace
  // Verify interaction
});
```

### Widget Tests for CaptionSearchBar
```dart
testWidgets('shows search icon when collapsed', (tester) {
  // Pump widget with mock cubit
  // Verify search icon is shown
});

testWidgets('expands when icon is tapped', (tester) {
  // Tap icon
  // Verify text field appears
});
```

## Estimated Effort

- Phase 1: 15 minutes (file structure)
- Phase 2: 30 minutes (cubit implementation)
- Phase 3: 30 minutes (UI refactoring)
- Phase 4: 20 minutes (integration)
- Phase 5: 15 minutes (cleanup)

**Total**: ~2 hours

## Notes

- AnimationController stays in widget because it's a UI framework concern
- TextEditingController stays in widget for direct TextField binding
- The cubit will NOT store TextEditingController (that's a UI concern)
- The cubit WILL store the text values (searchQuery, replaceText) for state management
