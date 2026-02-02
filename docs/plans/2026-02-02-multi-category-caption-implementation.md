# Multi-Category Caption System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable multiple caption categories per image dataset (e.g., "tags", "short", "detailed") with easy category switching and selective export.

**Architecture:** Single `db.json` per folder stores all caption categories. `AppImage` model uses `Map<String, CaptionEntry>` instead of single caption string. Categories are user-created and managed per-folder.

**Tech Stack:** Flutter, BLoC state management, JSON serialization with `json_annotation`, build_runner code generation.

---

## Phase 1: Data Model & Storage

### Task 1: Create CaptionEntry Model

**Files:**
- Create: `lib/features/captioning/data/models/caption_entry.dart`

**Step 1: Write the model**

```dart
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'caption_entry.g.dart';

@JsonSerializable()
class CaptionEntry extends Equatable {
  final String text;
  final String? model;
  final DateTime? timestamp;
  final bool isEdited;

  const CaptionEntry({
    required this.text,
    this.model,
    this.timestamp,
    this.isEdited = false,
  });

  factory CaptionEntry.fromJson(Map<String, dynamic> json) =>
      _$CaptionEntryFromJson(json);

  Map<String, dynamic> toJson() => _$CaptionEntryToJson(this);

  CaptionEntry copyWith({
    String? text,
    String? model,
    DateTime? timestamp,
    bool? isEdited,
  }) {
    return CaptionEntry(
      text: text ?? this.text,
      model: model ?? this.model,
      timestamp: timestamp ?? this.timestamp,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  @override
  List<Object?> get props => [text, model, timestamp, isEdited];
}
```

**Step 2: Run build_runner**

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

Expected: `caption_entry.g.dart` generated successfully

**Step 3: Commit**

```bash
git add lib/features/captioning/data/models/caption_entry.dart
git commit -m "feat: add CaptionEntry model for per-category caption data"
```

---

### Task 2: Update CaptionDatabase Model

**Files:**
- Modify: `lib/features/captioning/data/models/caption_database.dart`

**Step 1: Add new fields and update structure**

```dart
import 'package:json_annotation/json_annotation.dart';

import 'caption_data.dart';
import 'caption_entry.dart';

part 'caption_database.g.dart';

@JsonSerializable(explicitToJson: true)
class CaptionDatabase {
  final int version;
  final List<String> categories;
  final String? activeCategory;
  final List<CaptionData> images;

  CaptionDatabase({
    this.version = 2,
    required this.categories,
    this.activeCategory,
    required this.images,
  });

  factory CaptionDatabase.fromJson(Map<String, dynamic> json) =>
      _$CaptionDatabaseFromJson(json);

  Map<String, dynamic> toJson() => _$CaptionDatabaseToJson(this);
}
```

**Step 2: Update CaptionData model to use CaptionEntry**

**File:** `lib/features/captioning/data/models/caption_data.dart`

```dart
import 'package:json_annotation/json_annotation.dart';

import 'caption_entry.dart';

part 'caption_data.g.dart';

@JsonSerializable(explicitToJson: true)
class CaptionData {
  final String id;
  String filename;
  final Map<String, CaptionEntry> captions; // Changed from single fields
  final DateTime? lastModified;

  CaptionData({
    required this.id,
    required this.filename,
    required this.captions,
    this.lastModified,
  });

  factory CaptionData.fromJson(Map<String, dynamic> json) =>
      _$CaptionDataFromJson(json);

  Map<String, dynamic> toJson() => _$CaptionDataToJson(this);
}
```

**Step 3: Run build_runner**

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

**Step 4: Commit**

```bash
git add lib/features/captioning/data/models/caption_database.dart lib/features/captioning/data/models/caption_data.dart
git commit -m "feat: add categories and version to CaptionDatabase"
```

---

### Task 3: Update AppImage Model

**Files:**
- Modify: `lib/features/image_list/data/models/app_image.dart`

**Step 1: Import CaptionEntry and update model**

At top of file:
```dart
import '../../captioning/data/models/caption_entry.dart';
```

Replace `final String caption;` with:
```dart
final Map<String, CaptionEntry> captions;
```

Add `activeCategory` parameter:
```dart
  const AppImage({
    required this.id,
    required this.image,
    required this.captions,
    this.width = -1,
    this.height = -1,
    this.size = -1,
    this.error,
    this.isCaptionEdited = false,
    this.captionModel,
    this.captionTimestamp,
    this.lastModified,
  });
```

Add convenience getter:
```dart
  String get caption {
    // Return empty string if no captions or no active category
    if (captions.isEmpty) return '';
    return captions.values.first.text;
  }
```

Update props:
```dart
  @override
  List<Object?> get props => <Object?>[
    image,
    captions,
    width,
    height,
    size,
    error,
    isCaptionEdited,
    captionModel,
    captionTimestamp,
    lastModified,
  ];
```

Update copyWith:
```dart
  AppImage copyWith({
    String? id,
    File? image,
    Map<String, CaptionEntry>? captions,
    int? width,
    int? height,
    int? size,
    String? error,
    bool? isCaptionEdited,
    String? captionModel,
    DateTime? captionTimestamp,
    DateTime? lastModified,
    bool clearError = false,
  }) {
    return AppImage(
      id: id ?? this.id,
      image: image ?? this.image,
      captions: captions ?? this.captions,
      width: width ?? this.width,
      height: height ?? this.height,
      size: size ?? this.size,
      error: clearError ? null : (error ?? this.error),
      isCaptionEdited: isCaptionEdited ?? this.isCaptionEdited,
      captionModel: captionModel ?? this.captionModel,
      captionTimestamp: captionTimestamp ?? this.captionTimestamp,
      lastModified: lastModified ?? this.lastModified,
    );
  }
```

**Step 2: Commit**

```bash
git add lib/features/image_list/data/models/app_image.dart
git commit -m "feat: update AppImage to use caption categories map"
```

---

### Task 4: Implement Migration Logic in AppFileUtils

**Files:**
- Modify: `lib/features/image_list/data/repositories/app_file_utils.dart`

**Step 1: Add migration method**

Add after `readDb` method:

```dart
Future<CaptionDatabase> _migrateV1ToV2(
  Map<String, dynamic> oldJson,
  String folderPath,
) async {
  final oldImages = oldJson['images'] as List;
  final migratedImages = <CaptionData>[];

  for (final img in oldImages) {
    final String filename = img['filename'] as String;
    final String id = img['id'] as String;

    // Read caption from .txt file
    final File txtFile = File(p.join(folderPath, p.setExtension(filename, '.txt')));
    String captionText = '';
    if (await txtFile.exists()) {
      captionText = await txtFile.readAsString();
    }

    migratedImages.add(CaptionData(
      id: id,
      filename: filename,
      captions: {
        'default': CaptionEntry(
          text: captionText,
          model: img['captionModel'] as String?,
          timestamp: img['captionTimestamp'] != null
              ? DateTime.parse(img['captionTimestamp'] as String)
              : null,
          isEdited: false,
        ),
      },
      lastModified: img['lastModified'] != null
          ? DateTime.parse(img['lastModified'] as String)
          : null,
    ));
  }

  return CaptionDatabase(
    version: 2,
    categories: ['default'],
    activeCategory: 'default',
    images: migratedImages,
  );
}
```

**Step 2: Update readDb to detect old format**

Replace existing `readDb` method:

```dart
Future<CaptionDatabase> readDb(String folderPath) async {
  final File dbFile = _getDbPath(folderPath);
  if (await dbFile.exists()) {
    try {
      final String content = await dbFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // Check version for migration
      if (!json.containsKey('version')) {
        // Migrate from v1 to v2
        final migrated = await _migrateV1ToV2(json, folderPath);
        await writeDb(folderPath, migrated);
        return migrated;
      }

      return CaptionDatabase.fromJson(json);
    } catch (e) {
      return CaptionDatabase(
        version: 2,
        categories: ['default'],
        activeCategory: 'default',
        images: <CaptionData>[],
      );
    }
  }

  // New folder - create with default structure
  return CaptionDatabase(
    version: 2,
    categories: ['default'],
    activeCategory: 'default',
    images: <CaptionData>[],
  );
}
```

**Step 3: Update onFolderPicked to use new structure**

Replace the image loading loop in `onFolderPicked`:

```dart
for (final FileSystemEntity file in files) {
  if (file is File) {
    final String extension = p.extension(file.path).toLowerCase();
    if (extension == '.jpg' ||
        extension == '.png' ||
        extension == '.jpeg' ||
        extension == '.webp') {
      final String filename = p.basename(file.path);
      foundFilenames.add(filename);

      final CaptionData captionData = db.images.firstWhere(
        (CaptionData d) => d.filename == filename,
        orElse: () {
          dbWasModified = true;
          return CaptionData(
            id: const Uuid().v4(),
            filename: filename,
            captions: <String, CaptionEntry>{},
          );
        },
      );

      if (!db.images.contains(captionData)) {
        db.images.add(captionData);
      }

      images.add(
        AppImage(
          id: captionData.id,
          image: file,
          captions: captionData.captions,
          size: file.lengthSync(),
          lastModified: captionData.lastModified,
        ),
      );
    }
  }
}
```

**Step 4: Remove saveCaptionToFile (obsolete)**

The method now just updates db.json. Remove or simplify it.

**Step 5: Update exportAsArchive to accept category**

```dart
Future<void> exportAsArchive(
  String folderPath,
  List<AppImage> images,
  String category,
) async {
  // ... existing file picker code ...

  for (final AppImage image in images) {
    await encoder.addFile(image.image);

    final captionEntry = image.captions[category];
    if (captionEntry != null && captionEntry.text.isNotEmpty) {
      final List<int> captionBytes = utf8.encode(captionEntry.text);
      final ArchiveFile archiveFile = ArchiveFile(
        p.setExtension(p.basename(image.image.path), '.txt'),
        captionBytes.length,
        captionBytes,
      );
      encoder.addArchiveFile(archiveFile);
    }
  }

  // ... rest of method ...
}
```

**Step 6: Commit**

```bash
git add lib/features/image_list/data/repositories/app_file_utils.dart
git commit -m "feat: add v1 to v2 migration and update file operations"
```

---

## Phase 2: BLoC Updates

### Task 5: Update ImageListState

**Files:**
- Modify: `lib/features/image_list/logic/image_list_state.dart`

**Step 1: Add category fields**

Add to state class:
```dart
  final List<String> categories;
  final String? activeCategory;
```

Add to constructor:
```dart
  const ImageListState({
    this.images = const <AppImage>[],
    this.sortBy = SortBy.name,
    this.sortAscending = true,
    this.folderPath,
    this.currentIndex = 0,
    this.occurrencesCount = 0,
    this.occurrenceFileNames = const <String>[],
    this.searchQuery = '',
    this.caseSensitive = false,
    this.categories = const <String>['default'],
    this.activeCategory = 'default',
  });
```

Add to copyWith:
```dart
  ImageListState copyWith({
    List<AppImage>? images,
    SortBy? sortBy,
    bool? sortAscending,
    String? folderPath,
    int? currentIndex,
    int? occurrencesCount,
    List<String>? occurrenceFileNames,
    String? searchQuery,
    bool? caseSensitive,
    List<String>? categories,
    String? activeCategory,
  }) {
    return ImageListState(
      images: images ?? this.images,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      folderPath: folderPath ?? this.folderPath,
      currentIndex: currentIndex ?? this.currentIndex,
      occurrencesCount: occurrencesCount ?? this.occurrencesCount,
      occurrenceFileNames: occurrenceFileNames ?? this.occurrenceFileNames,
      searchQuery: searchQuery ?? this.searchQuery,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      categories: categories ?? this.categories,
      activeCategory: activeCategory ?? this.activeCategory,
    );
  }
```

Add to props:
```dart
  @override
  List<Object?> get props => <Object?>[
    images,
    sortBy,
    sortAscending,
    folderPath,
    currentIndex,
    occurrencesCount,
    occurrenceFileNames,
    searchQuery,
    caseSensitive,
    categories,
    activeCategory,
  ];
```

**Step 2: Commit**

```bash
git add lib/features/image_list/logic/image_list_state.dart
git commit -m "feat: add categories to ImageListState"
```

---

### Task 6: Add Category Management to ImageListCubit

**Files:**
- Modify: `lib/features/image_list/logic/image_list_cubit.dart`

**Step 1: Update onFolderPicked to load categories**

After loading images in `onFolderPicked`:
```dart
      final List<AppImage> images = await _fileUtils.onFolderPicked(folderPath);

      // Load database to get categories
      final CaptionDatabase db = await _fileUtils.readDb(folderPath);

      if (state.folderPath != folderPath) {
        return;
      }

      emit(state.copyWith(
        images: images,
        categories: db.categories,
        activeCategory: db.activeCategory ?? 'default',
      ));
```

**Step 2: Add category management methods**

Add these methods to the cubit:

```dart
void addCategory(String name) async {
  if (state.categories.contains(name)) {
    return; // Already exists
  }

  final updatedCategories = List<String>.from(state.categories)..add(name);
  emit(state.copyWith(categories: updatedCategories));

  await _saveDb();
}

void removeCategory(String name) async {
  if (state.categories.length <= 1) {
    return; // Must have at least one category
  }

  final updatedCategories = List<String>.from(state.categories)..remove(name);
  final newActiveCategory = state.activeCategory == name
      ? updatedCategories.first
      : state.activeCategory;

  emit(state.copyWith(
    categories: updatedCategories,
    activeCategory: newActiveCategory,
  ));

  await _saveDb();
}

void renameCategory(String oldName, String newName) async {
  if (state.categories.contains(newName)) {
    return; // Already exists
  }

  final updatedCategories = List<String>.from(state.categories);
  final index = updatedCategories.indexOf(oldName);
  updatedCategories[index] = newName;

  // Update all images to rename the category key
  final updatedImages = state.images.map((img) {
    final newCaptions = Map<String, CaptionEntry>.from(img.captions);
    if (newCaptions.containsKey(oldName)) {
      newCaptions[newName] = newCaptions.remove(oldName)!;
    }
    return img.copyWith(captions: newCaptions);
  }).toList();

  final newActiveCategory = state.activeCategory == oldName
      ? newName
      : state.activeCategory;

  emit(state.copyWith(
    categories: updatedCategories,
    activeCategory: newActiveCategory,
    images: updatedImages,
  ));

  await _saveDb();
}

void setActiveCategory(String name) {
  if (!state.categories.contains(name)) {
    return;
  }
  emit(state.copyWith(activeCategory: name));
}

void reorderCategories(int oldIndex, int newIndex) async {
  final updatedCategories = List<String>.from(state.categories);
  if (oldIndex < newIndex) {
    newIndex -= 1;
  }
  final item = updatedCategories.removeAt(oldIndex);
  updatedCategories.insert(newIndex, item);

  emit(state.copyWith(categories: updatedCategories));
  await _saveDb();
}
```

**Step 3: Update updateCaption to use activeCategory**

Replace the existing `updateCaption` method:

```dart
void updateCaption({required String caption}) async {
  final AppImage? originalImage = currentDisplayedImage;
  if (originalImage == null) return;

  final category = state.activeCategory ?? 'default';
  final updatedCaptions = Map<String, CaptionEntry>.from(originalImage.captions);

  // Get existing entry or create new one
  final existingEntry = updatedCaptions[category];
  updatedCaptions[category] = CaptionEntry(
    text: caption,
    model: caption.isEmpty ? null : existingEntry?.model,
    timestamp: caption.isEmpty ? null : existingEntry?.timestamp,
    isEdited: true,
  );

  final AppImage updated = originalImage.copyWith(
    captions: updatedCaptions,
    lastModified: DateTime.now(),
  );

  final List<AppImage> updatedImages = List<AppImage>.from(state.images);
  final int index = updatedImages.indexWhere(
    (AppImage i) => i.id == originalImage.id,
  );
  if (index != -1) {
    updatedImages[index] = updated;
  }

  emit(state.copyWith(images: updatedImages));
  await _saveDb();
}
```

**Step 4: Update _saveDb to use new structure**

Replace `_saveDb` method:

```dart
Future<void> _saveDb() async {
  if (state.folderPath == null || state.folderPath!.isEmpty) return;

  final captionDataList = state.images
      .map<CaptionData>(
        (AppImage img) => CaptionData(
          id: img.id,
          filename: p.basename(img.image.path),
          captions: img.captions,
          lastModified: img.lastModified,
        ),
      )
      .toList();

  final db = CaptionDatabase(
    version: 2,
    categories: state.categories,
    activeCategory: state.activeCategory,
    images: captionDataList,
  );

  await _fileUtils.writeDb(state.folderPath!, db);
}
```

**Step 5: Update getAverageWordsPerCaption to use category**

```dart
double getAverageWordsPerCaption() {
  final category = state.activeCategory ?? 'default';

  final imagesWithCaptions = state.images
      .where((AppImage image) =>
          image.captions[category]?.text.isNotEmpty ?? false)
      .toList();

  if (imagesWithCaptions.isEmpty) {
    return 0.0;
  }

  int totalWords = 0;
  for (final AppImage image in imagesWithCaptions) {
    final text = image.captions[category]?.text ?? '';
    totalWords += text.split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .length;
  }

  return totalWords / imagesWithCaptions.length;
}
```

**Step 6: Commit**

```bash
git add lib/features/image_list/logic/image_list_cubit.dart
git commit -m "feat: add category management to ImageListCubit"
```

---

### Task 7: Update CaptioningCubit for Categories

**Files:**
- Modify: `lib/features/captioning/logic/captioning_cubit.dart`

**Step 1: Update captionImage call to pass category**

In `runCaptioner` method where it calls `_captioningRepository.captionImage`:

```dart
        final category = _imageListCubit.state.activeCategory ?? 'default';
        AppImage updatedImage = await _captioningRepository.captionImage(
          llm,
          image,
          prompt,
          category: category, // Add this parameter
        );
```

**Step 2: Update filter logic to use category**

In the filtering logic:
```dart
      case CaptionOptions.missing:
        final category = _imageListCubit.state.activeCategory ?? 'default';
        imagesToCaption = allImages
            .where((AppImage image) =>
                (image.captions[category]?.text ?? '').isEmpty)
            .toList();
```

**Step 3: Commit**

```bash
git add lib/features/captioning/logic/captioning_cubit.dart
git commit -m "feat: use active category in CaptioningCubit"
```

---

### Task 8: Update CaptioningRepository

**Files:**
- Modify: `lib/features/captioning/data/repositories/captioning_repository.dart`

**Step 1: Add category parameter to captionImage method**

Find the `captionImage` method and update signature to accept `category`:

```dart
Future<AppImage> captionImage(
  LlmConfig llm,
  AppImage image,
  String prompt, {
  String category = 'default',
}) async {
```

**Step 2: Update the return statement to set caption in correct category**

Where it creates the updated AppImage:
```dart
  return image.copyWith(
    captions: {
      ...image.captions,
      category: CaptionEntry(
        text: response.text,
        model: llm.name,
        timestamp: DateTime.now(),
        isEdited: false,
      ),
    },
    lastModified: DateTime.now(),
  );
```

**Step 3: Commit**

```bash
git add lib/features/captioning/data/repositories/captioning_repository.dart
git commit -m "feat: add category parameter to captionImage"
```

---

## Phase 3: UI Components

### Task 9: Create CategoryTabBar Widget

**Files:**
- Create: `lib/features/captioning/presentation/widgets/category_tab_bar.dart`

**Step 1: Write the widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../image_list/logic/image_list_cubit.dart';

class CategoryTabBar extends StatelessWidget {
  const CategoryTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (context, state) {
        if (state.categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(30),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withAlpha(20),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.categories.length,
                  itemBuilder: (context, index) {
                    final category = state.categories[index];
                    final isActive = category == state.activeCategory;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CategoryTab(
                        category: category,
                        isActive: isActive,
                        onTap: () {
                          context.read<ImageListCubit>().setActiveCategory(category);
                        },
                      ),
                    );
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => _showAddCategoryDialog(context),
                tooltip: 'Add category',
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Category name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<ImageListCubit>().addCategory(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final String category;
  final bool isActive;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.category,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.blue.withAlpha(80)
                : Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? Colors.blue.withAlpha(150)
                  : Colors.white.withAlpha(20),
            ),
          ),
          child: Text(
            category,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: category);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'New name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<ImageListCubit>().renameCategory(
                      category,
                      controller.text.trim(),
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "$category"? All captions in this category will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<ImageListCubit>().removeCategory(category);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/captioning/presentation/widgets/category_tab_bar.dart
git commit -m "feat: add CategoryTabBar widget"
```

---

### Task 10: Integrate CategoryTabBar into CaptionTextArea

**Files:**
- Modify: `lib/features/captioning/presentation/widgets/caption_text_area.dart`

**Step 1: Add CategoryTabBar above TextField**

Import the widget:
```dart
import 'category_tab_bar.dart';
```

In the build method, wrap the Column content and add the tab bar:

```dart
child: Column(
  children: <Widget>[
    const CategoryTabBar(), // Add this
    Expanded(
      child: Stack(
        // ... existing Stack content ...
      ),
    ),
  ],
),
```

**Step 2: Update word count to use active category**

Find the word count display and update:
```dart
Text(
  "${(currentImage.captions[state.activeCategory ?? 'default']?.text ?? '').split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).length} words",
  style: const TextStyle(
    fontSize: 11,
    color: Colors.white54,
  ),
),
```

**Step 3: Update copy button to use active category**

Update the copy button logic:
```dart
final captionText = currentImage.captions[state.activeCategory ?? 'default']?.text ?? '';

Tooltip(
  message: captionText.trim().isEmpty
      ? 'No caption to copy'
      : 'Copy caption to clipboard',
  child: InkWell(
    onTap: captionText.trim().isEmpty
        ? null
        : () {
            Clipboard.setData(
              ClipboardData(text: captionText),
            );
            NotificationOverlay.show(
              context,
              message: 'Caption copied to clipboard',
            );
          },
    // ... rest of widget ...
  ),
),
```

**Step 4: Commit**

```bash
git add lib/features/captioning/presentation/widgets/caption_text_area.dart
git commit -m "feat: integrate CategoryTabBar into CaptionTextArea"
```

---

### Task 11: Update Header Counter

**Files:**
- Modify: `lib/features/image_list/presentation/widgets/header_widget.dart`

**Step 1: Update _buildImageCountRow**

```dart
  Widget _buildImageCountRow(
    List<AppImage> images,
    String? activeCategory,
  ) {
    final category = activeCategory ?? 'default';
    final int captionCount = images
        .where((AppImage image) =>
            (image.captions[category]?.text ?? '').isNotEmpty)
        .length;

    return Row(
      children: <Widget>[
        Image.asset('assets/icons/image.png', width: _iconSize),
        const SizedBox(width: _spacing),
        Text(
          activeCategory != null
              ? '$captionCount / ${images.length} captions ($activeCategory)'
              : '$captionCount / ${images.length} captions',
          style: const TextStyle(fontSize: _fontSize),
        ),
      ],
    );
  }
```

**Step 2: Update the call in build method**

```dart
_buildImageCountRow(state.images, state.activeCategory),
```

**Step 3: Commit**

```bash
git add lib/features/image_list/presentation/widgets/header_widget.dart
git commit -m "feat: update header counter to show active category"
```

---

### Task 12: Create Export Category Selection Dialog

**Files:**
- Modify: `lib/features/export/presentation/widgets/export_button.dart`

**Step 1: Create dialog widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../image_operations/logic/image_operations_cubit.dart';

class ExportButton extends StatelessWidget {
  const ExportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Export images and captions as zip file',
      child: AppButton(
        onTap: () => _showExportDialog(context),
        text: 'Export as Archive',
        iconAssetPath: 'assets/icons/archive.png',
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ExportCategoryDialog(),
    );
  }
}

class _ExportCategoryDialog extends StatelessWidget {
  const _ExportCategoryDialog();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (context, state) {
        if (state.categories.isEmpty) {
          return AlertDialog(
            title: const Text('Export'),
            content: const Text('No categories available.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        }

        String selectedCategory = state.activeCategory ?? state.categories.first;
        final imagesWithCaption = state.images
            .where((img) =>
                (img.captions[selectedCategory]?.text ?? '').isNotEmpty)
            .length;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Export as Archive'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select caption category to export:'),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    items: state.categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedCategory = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Will export ${state.images.length} images',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '$imagesWithCaption images have captions in "$selectedCategory"',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (imagesWithCaption < state.images.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '⚠️ ${state.images.length - imagesWithCaption} images have no caption in this category',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.orange,
                            ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    context.read<ImageOperationsCubit>().exportAsArchive(
                          state.folderPath!,
                          state.images,
                          selectedCategory,
                        );
                    Navigator.pop(context);
                  },
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/export/presentation/widgets/export_button.dart
git commit -m "feat: add category selection to export dialog"
```

---

## Phase 4: Testing

### Task 13: Write Migration Tests

**Files:**
- Create: `test/features/image_list/data/repositories/app_file_utils_migration_test.dart`

**Step 1: Write migration test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yofardev_captioner/features/captioning/data/models/caption_database.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';

void main() {
  group('AppFileUtils Migration', () {
    late Directory tempDir;
    late AppFileUtils fileUtils;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('migration_test');
      fileUtils = AppFileUtils();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('migrates v1 database to v2 format', () async {
      // Create old format db.json
      final oldDb = {
        'images': [
          {
            'id': 'test-id-1',
            'filename': 'test.jpg',
            'captionModel': 'gpt-4',
            'captionTimestamp': '2025-01-15T10:30:00Z',
            'lastModified': '2025-01-15T10:30:00Z',
          },
        ],
      };

      final dbFile = File(p.join(tempDir.path, 'db.json'));
      await dbFile.writeAsString(oldDb.toString());

      // Create corresponding .txt file
      final txtFile = File(p.join(tempDir.path, 'test.txt'));
      await txtFile.writeAsString('Test caption');

      // Read and migrate
      final db = await fileUtils.readDb(tempDir.path);

      // Verify migration
      expect(db.version, equals(2));
      expect(db.categories, equals(['default']));
      expect(db.activeCategory, equals('default'));
      expect(db.images.length, equals(1));
      expect(db.images.first.captions.containsKey('default'), isTrue);
      expect(db.images.first.captions['default']?.text, equals('Test caption'));
    });
  });
}
```

**Step 2: Run tests**

```bash
flutter test test/features/image_list/data/repositories/app_file_utils_migration_test.dart
```

**Step 3: Commit**

```bash
git add test/features/image_list/data/repositories/app_file_utils_migration_test.dart
git commit -m "test: add migration tests"
```

---

### Task 14: Write Category Management Tests

**Files:**
- Create: `test/features/image_list/logic/image_list_cubit_categories_test.dart`

**Step 1: Write category management tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';

import 'image_list_cubit_categories_test.mocks.dart';

@GenerateNiceMocks([MockSpec<AppFileUtils>()])
void main() {
  group('ImageListCubit Category Management', () {
    late ImageListCubit cubit;
    late MockAppFileUtils mockFileUtils;

    setUp(() {
      mockFileUtils = MockAppFileUtils();
      cubit = ImageListCubit(fileUtils: mockFileUtils);
    });

    test('adds new category', () {
      cubit.addCategory('tags');

      expect(cubit.state.categories, contains('tags'));
    });

    test('prevents duplicate category names', () {
      cubit.addCategory('tags');
      cubit.addCategory('tags');

      expect(cubit.state.categories.where((c) => c == 'tags').length, 1);
    });

    test('removes category and switches active if needed', () {
      cubit.emit(cubit.state.copyWith(
        categories: ['default', 'tags'],
        activeCategory: 'tags',
      ));

      cubit.removeCategory('tags');

      expect(cubit.state.categories, isNot(contains('tags')));
      expect(cubit.state.activeCategory, equals('default'));
    });

    test('prevents removing last category', () {
      cubit.emit(cubit.state.copyWith(
        categories: ['default'],
        activeCategory: 'default',
      ));

      cubit.removeCategory('default');

      expect(cubit.state.categories, contains('default'));
    });

    test('renames category across all images', () {
      // Implementation depends on your test setup
    });
  });
}
```

**Step 2: Run tests**

```bash
flutter test test/features/image_list/logic/image_list_cubit_categories_test.dart
```

**Step 3: Commit**

```bash
git add test/features/image_list/logic/image_list_cubit_categories_test.dart
git commit -m "test: add category management tests"
```

---

### Task 15: Manual Testing Checklist

**Testing Scenarios:**

1. **Open old folder (v1 format)**
   - [ ] Auto-migrates to v2
   - [ ] Creates "default" category
   - [ ] Existing captions preserved
   - [ ] Cleanup dialog appears

2. **Category management**
   - [ ] Add new category
   - [ ] Rename category
   - [ ] Delete category (not last one)
   - [ ] Cannot delete last category
   - [ ] Cannot create duplicate names

3. **Switching categories**
   - [ ] Tab bar shows all categories
   - [ ] Clicking tab switches active category
   - [ ] Caption text area updates
   - [ ] Header counter updates

4. **Editing captions**
   - [ ] Editing saves to correct category
   - [ ] Word count updates for category
   - [ ] Copy button uses active category

5. **AI caption generation**
   - [ ] Generates to active category
   - [ ] Doesn't affect other categories

6. **Export**
   - [ ] Dialog shows category selector
   - [ ] Preview shows correct counts
   - [ ] Export uses selected category
   - [ ] .txt files contain correct captions

7. **Persistence**
   - [ ] Categories saved after closing app
   - [ ] Active category remembered
   - [ ] Reopening folder loads categories

---

## Final Steps

### Task 16: Update Documentation

**Files:**
- Modify: `README.md` (if exists)

**Step 1: Document multi-category feature**

Add section explaining:
- How to create/manage categories
- How to switch between them
- How to export specific categories

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: document multi-category caption feature"
```

---

### Task 17: Final Verification

**Step 1: Run all tests**

```bash
flutter test
```

**Step 2: Check for lint errors**

```bash
flutter analyze
```

**Step 3: Build release version**

```bash
flutter build macos --release
```

**Step 4: Final commit**

```bash
git commit --allow-empty -m "feat: complete multi-category caption system implementation"
```

---

## Migration Cleanup Dialog (Future Enhancement)

This was designed but not implemented in Phase 1. Add after basic functionality works:

**File:** `lib/features/image_list/presentation/widgets/migration_cleanup_dialog.dart`

```dart
import 'package:flutter/material.dart';

class MigrationCleanupDialog extends StatelessWidget {
  final int fileCount;

  const MigrationCleanupDialog({
    super.key,
    required this.fileCount,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Folder Migrated'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This folder has been upgraded to support multiple caption categories.',
          ),
          const SizedBox(height: 16),
          Text('Found $fileCount existing caption files.'),
          const Text('Migrated to "default" category.'),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Remove old .txt files'),
            subtitle: const Text('(recommended, they\'re no longer needed)'),
            value: true, // Default checked
            onChanged: (bool? value) {
              // Handle toggle
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
```

---

## Implementation Notes

- **Backward Compatibility:** Old `.txt` files are migrated but not deleted unless user opts in
- **Error Handling:** Migration failures should log errors but not prevent app from loading
- **Performance:** For 10K+ images, consider lazy loading or pagination in future iterations
- **Thread Safety:** All file operations are async and safe for concurrent access
- **Testing Strategy:** Unit tests for business logic, integration tests for workflows, manual testing for UI
