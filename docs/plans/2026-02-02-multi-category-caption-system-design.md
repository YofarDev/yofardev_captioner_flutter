# Multi-Category Caption System Design

**Date:** 2026-02-02
**Status:** Design Approved

## Overview

Enable multiple caption categories per image dataset (e.g., "tags", "short", "detailed") with easy switching between categories and selective export.

## Requirements

- Support user-created caption categories (not pre-defined)
- Store categories per-folder (each dataset has its own set)
- Easy UI for switching between categories (tab bar)
- Export dialog to select which category to export
- Auto-migrate existing single-caption folders

## Architecture

### Data Storage

**Single `db.json` file per folder** contains all caption data and category definitions.

**New structure:**
```json
{
  "version": 2,
  "categories": ["tags", "short", "detailed"],
  "activeCategory": "short",
  "images": [
    {
      "id": "uuid",
      "filename": "image.jpg",
      "captions": {
        "tags": {
          "text": "cat,pet,animal",
          "model": "gpt-4",
          "timestamp": "2025-01-15T10:30:00Z",
          "isEdited": false
        },
        "short": {
          "text": "A cat sitting on a couch",
          "model": "gpt-4",
          "timestamp": "2025-01-15T10:31:00Z",
          "isEdited": false
        }
      },
      "lastModified": "2025-01-15T10:31:00Z"
    }
  ]
}
```

**Key changes from v1:**
- `version` field for future migrations
- `categories` array at root level (defines order)
- `activeCategory` tracks currently selected category
- `captions` becomes a map (category name → caption data)
- Each caption entry: `text`, `model`, `timestamp`, `isEdited`

### Data Models

**AppImage changes:**
```dart
class AppImage {
  final String id;
  final File image;
  final Map<String, CaptionEntry> captions;  // Was: String caption
  final int width;
  final int height;
  final int size;
  final String? error;
  final DateTime? lastModified;

  // Convenience getter for backward compatibility
  String get caption => captions[activeCategory ?? '']?.text ?? '';
}

class CaptionEntry {
  final String text;
  final String? model;
  final DateTime? timestamp;
  final bool isEdited;
}
```

**CaptionDatabase changes:**
```dart
@JsonSerializable(explicitToJson: true)
class CaptionDatabase {
  final int version;  // New
  final List<String> categories;  // New
  final String? activeCategory;  // New
  final List<ImageCaptionData> images;  // Changed structure
}
```

## UI Design

### Category Tab Bar

**Location:** Above caption text area

**Features:**
- Display all categories as tabs
- Click tab → switch `activeCategory` → show that category's caption
- Highlight active tab
- Drag tabs to reorder

**Category Management:**
- Add button (+) to create new category
- Right-click/long-press tab → context menu:
  - Rename category
  - Delete category (with confirmation)
  - Duplicate category (copies caption text)
- Prevent deleting last category
- Prevent duplicate category names

### Caption Editing

- Text area shows `captions[activeCategory].text`
- Saving updates correct category entry
- Track `isEdited = true` for manual edits
- AI-generated sets `isEdited = false`

### Header Counter

**Before:** `42 / 100 captions`
**After:** `42 / 100 captions (short)`

Count only captions from active category.

Words per caption also category-aware.

### Export Dialog

**New flow:**
1. User clicks "Export as Archive"
2. Show dialog:
   - Category dropdown/radio selection
   - Preview count: "Will export X images with captions from 'tags'"
   - Warning if missing captions: "⚠️ 15 images have no caption in this category"
3. Selected category's caption text exported as `.txt` files

## Migration Strategy

### Detecting Old Format

Check for `version` field in `db.json`. Missing = old format (v1).

### Migration Process

1. Detect old `db.json` (no `version` field)
2. Create "default" category
3. Read all `.txt` files and migrate to `captions.default.text`
4. Migrate `captionModel`, `captionTimestamp` from old structure
5. Set `version: 2`
6. Write new `db.json`
7. Show cleanup dialog

### Cleanup Dialog

```
┌─────────────────────────────────────────┐
│  Folder Migrated                        │
├─────────────────────────────────────────┤
│  This folder has been upgraded to       │
│  support multiple caption categories.   │
│                                         │
│  Found 47 existing caption files.       │
│  Migrated to "default" category.        │
│                                         │
│  ☑ Remove old .txt files               │
│     (recommended, they're no longer     │
│      needed)                            │
│                                         │
│            [Done]                       │
└─────────────────────────────────────────┘
```

If user confirms, delete all migrated `.txt` files.

## BLoC Changes

### ImageListCubit

**New state fields:**
- `List<String> categories`
- `String? activeCategory`

**New methods:**
- `addCategory(String name)` - adds to categories array, updates db
- `removeCategory(String name)` - removes and updates db
- `renameCategory(String oldName, String newName)` - updates all images
- `setActiveCategory(String name)` - switches current category
- `reorderCategories(int oldIndex, int newIndex)` - updates order

### CaptioningCubit

- `generateCaption()` takes optional `category` parameter
- Updates `captions[category].text` instead of single field
- Sets `captions[category].model` and `timestamp`

### CaptioningRepository

- `saveCaption()` accepts category parameter
- Updates correct map entry in db

## Edge Cases

1. **Deleting active category:** Auto-switch to first available category
2. **Last category:** Prevent deletion (require at least one)
3. **Duplicate names:** Show error on creation attempt
4. **Export missing captions:** Warn but allow proceeding (skips .txt for those images)
5. **Large datasets:** 10K+ images should work fine (~10MB JSON)
6. **Concurrent access:** Last write wins (acceptable for single-user app)

## Implementation Phases

### Phase 1: Data Model & Storage
- Update `CaptionDatabase` model
- Create `CaptionEntry` model
- Update `AppImage` model
- Implement migration logic
- Add cleanup dialog
- Run build_runner

### Phase 2: BLoC Updates
- Add categories to `ImageListState`
- Implement category management methods
- Update `CaptioningCubit` for categories
- Update `CaptioningRepository`

### Phase 3: UI Components
- Create `CategoryTabBar` widget
- Add category management UI
- Update `CaptionTextArea`
- Update header counter
- Create export dialog

### Phase 4: Testing
- Unit tests for migration
- Unit tests for category management
- Integration tests for caption generation
- Manual testing with real datasets

## Files to Modify

### Models
- `lib/features/captioning/data/models/caption_database.dart`
- `lib/features/captioning/data/models/caption_data.dart`
- `lib/features/image_list/data/models/app_image.dart`

### BLoCs
- `lib/features/image_list/logic/image_list_cubit.dart`
- `lib/features/image_list/logic/image_list_state.dart`
- `lib/features/captioning/logic/captioning_cubit.dart`

### Repositories
- `lib/features/image_list/data/repositories/app_file_utils.dart`
- `lib/features/captioning/data/repositories/captioning_repository.dart`

### UI
- `lib/features/image_list/presentation/widgets/header_widget.dart`
- `lib/features/captioning/presentation/widgets/caption_text_area.dart`
- `lib/features/export/presentation/widgets/export_button.dart`
- New: `lib/features/captioning/presentation/widgets/category_tab_bar.dart`

## Backward Compatibility

- Old `.txt` files left in place after migration (or deleted if user chooses)
- Old `db.json` format automatically detected and migrated
- Export still writes standard `.txt` format (compatible with other tools)
- Old single-caption folders continue to work until opened (then auto-migrate)
