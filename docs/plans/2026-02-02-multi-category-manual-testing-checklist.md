# Multi-Category Caption System - Manual Testing Checklist

**Date:** 2026-02-02
**Status:** Ready for Testing

## Pre-Test Setup

1. Create a test folder with sample images (5-10 images)
2. Optionally create an old-format folder with `.txt` caption files
3. Have an LLM API configured in the app settings

## Test Scenarios

### 1. Open Old Folder (v1 format)

**Setup:** Use a folder with existing `db.json` (v1) and `.txt` caption files

- [ ] Folder opens without errors
- [ ] Auto-migrates to v2 format
- [ ] Creates "default" category
- [ ] All existing captions are preserved in "default" category
- [ ] No `.txt` files are deleted (unless user opts in)

### 2. Category Management

- [ ] Add new category (+ button)
  - [ ] Dialog appears
  - [ ] New category appears in tab bar
  - [ ] Category is selectable
- [ ] Rename category (long-press → Rename)
  - [ ] Dialog appears with current name
  - [ ] Category name updates in tab bar
  - [ ] Active category updates if renamed
- [ ] Delete category (long-press → Delete)
  - [ ] Confirmation dialog appears
  - [ ] Category removed from tab bar
  - [ ] Active category switches if deleting active
  - [ ] Cannot delete last category (disabled or shows error)
- [ ] Duplicate name prevention
  - [ ] Cannot create category with existing name
  - [ ] Cannot rename to existing category name

### 3. Switching Categories

- [ ] Tab bar shows all categories
- [ ] Clicking tab highlights as active
- [ ] Caption text area updates to show selected category's caption
- [ ] Header counter updates for selected category
- [ ] Word count updates for selected category
- [ ] Active category persists when switching images
- [ ] Active category remembered when reopening folder

### 4. Editing Captions

- [ ] Text area shows caption for active category
- [ ] Typing updates the caption
- [ ] Changes are saved to active category only
- [ ] Word count updates in real-time
- [ ] Other categories are unaffected
- [ ] Copy button copies active category's caption

### 5. AI Caption Generation

- [ ] Generate caption for current image
  - [ ] Caption appears in active category
- [ ] Generate for all images
  - [ ] All images get captions in active category
- [ ] Generate for missing captions
  - [ ] Only images without captions in active category are processed
- [ ] Other categories' captions are not overwritten
- [ ] Model and timestamp are stored correctly

### 6. Export Functionality

- [ ] Export button shows category selection dialog
- [ ] Dropdown shows all available categories
- [ ] Preview shows correct image count
- [ ] Preview shows caption count for selected category
- [ ] Warning shown for missing captions
- [ ] Export creates zip with:
  - [ ] All images
  - [ ] `.txt` files with captions from selected category
  - [ ] `db.json` file with all category data

### 7. Search and Filter

- [ ] Search searches in active category
- [ ] Search results update when switching categories
- [ ] Clearing search works correctly
- [ ] Case-sensitive toggle works

### 8. Sort Functionality

- [ ] Sort by caption length uses active category
- [ ] Sort order updates when switching categories
- [ ] Sort order persists when navigating

### 9. Persistence

- [ ] Categories saved after closing app
- [ ] Active category remembered
- [ ] All captions saved per category
- [ ] Reopening folder restores all data

### 10. Edge Cases

- [ ] Opening folder with no images
- [ ] Opening folder with only images (no db.json)
- [ ] Switching categories rapidly
- [ ] Editing while AI generation is running
- [ ] Exporting with no captions in selected category
- [ ] Large dataset (100+ images)

## Performance Checks

- [ ] Folder opens within 3 seconds (100 images)
- [ ] Category switching is instant
- [ ] No lag when typing captions
- [ ] Export completes within reasonable time

## UI/UX Checks

- [ ] Tab bar styling is consistent
- [ ] Active category is clearly highlighted
- [ ] Icons and tooltips are clear
- [ ] Dialogs are properly styled
- [ ] No text overflow issues
- [ ] Scroll works in tab bar (many categories)

## Regression Testing

- [ ] Existing single-caption folders still work (after migration)
- [ ] Image operations (crop, resize) still work
- [ ] File renaming still works
- [ ] Batch operations still work

## Bug Reporting

Document any issues found with:
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots if applicable
