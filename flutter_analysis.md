# Flutter Pre-Analysis - 2026-10-20
_Project: `/Users/yofardev/development/Projects/Flutter/yofardev_captioner`_

_This report is heuristic only. Use it to guide the audit, not to replace file reads._

## Lib overview
```text
lib/
+-- .DS_Store (0 lines)
+-- core/ (12 dart files)
+-- features/ (117 dart files)
+-- helpers/ (1 dart files)
+-- main.dart (238 lines)
```

## Feature map
- **agent_api**: data presentation | 2 dart files | 0 cubits/blocs
- **caption_search**: data presentation | 9 dart files | 1 cubits/blocs
- **captioning**: data presentation | 29 dart files | 2 cubits/blocs
- **export**: presentation | 2 dart files | 0 cubits/blocs
- **image_list**: data presentation | 10 dart files | 1 cubits/blocs
- **image_operations**: data presentation | 11 dart files | 1 cubits/blocs
- **llm_config**: data presentation | 14 dart files | 1 cubits/blocs
- **main_area**: presentation | 3 dart files | 0 cubits/blocs
- **structured_captioning**: data presentation | 32 dart files | 2 cubits/blocs
- **tab_manager**: data presentation | 5 dart files | 1 cubits/blocs

## Core layout
Present directories: config constants presentation services utils widgets
⚠️ core/di missing
⚠️ core/router missing

## Large files to inspect
_Heuristic only. Long files are cohesion review candidates, not automatic violations._
_Thresholds: general >300 | screen/widget/cubit/bloc >350 | service/repo/api >400_
- `lib/core/presentation/pages/home_page.dart` - 322 lines (threshold 300)
- `lib/features/agent_api/data/services/agent_api_service.dart` - 620 lines (threshold 400)
- `lib/features/caption_search/data/models/filter_query.dart` - 450 lines (threshold 300)
- `lib/features/caption_search/data/services/filter_parser.dart` - 332 lines (threshold 300)
- `lib/features/caption_search/presentation/widgets/caption_search_bar.dart` - 655 lines (threshold 300)
- `lib/features/caption_search/presentation/widgets/search_autocomplete_overlay.dart` - 385 lines (threshold 300)
- `lib/features/caption_search/presentation/widgets/tag_filter_chips_overlay.dart` - 307 lines (threshold 300)
- `lib/features/captioning/data/services/caption_service.dart` - 579 lines (threshold 400)
- `lib/features/captioning/logic/captioning_cubit.dart` - 417 lines (threshold 350)
- `lib/features/captioning/presentation/widgets/caption_controls.dart` - 1010 lines (threshold 300)
- `lib/features/captioning/presentation/widgets/caption_text_area.dart` - 486 lines (threshold 300)
- `lib/features/captioning/presentation/widgets/category_tab_bar.dart` - 460 lines (threshold 300)
- `lib/features/captioning/presentation/widgets/convert_captions_dialog.dart` - 459 lines (threshold 350)
- `lib/features/export/presentation/widgets/export_button.dart` - 307 lines (threshold 300)
- `lib/features/image_list/data/repositories/app_file_utils.dart` - 522 lines (threshold 300)
- `lib/features/image_list/logic/image_list_cubit.dart` - 839 lines (threshold 350)
- `lib/features/image_list/presentation/widgets/tag_editor.dart` - 348 lines (threshold 300)
- `lib/features/llm_config/presentation/widgets/models_prompts_panel.dart` - 644 lines (threshold 300)
- `lib/features/llm_config/presentation/widgets/structured_panel.dart` - 765 lines (threshold 300)
- `lib/features/structured_captioning/data/models/ideogram_caption.dart` - 334 lines (threshold 300)
- `lib/features/structured_captioning/data/repositories/structured_caption_repository.dart` - 2264 lines (threshold 400)
- `lib/features/structured_captioning/logic/structured_editor_cubit.dart` - 794 lines (threshold 350)
- `lib/features/structured_captioning/presentation/pages/structured_editor_page.dart` - 734 lines (threshold 300)
- `lib/features/structured_captioning/presentation/widgets/element_detail_section.dart` - 616 lines (threshold 300)
- `lib/features/structured_captioning/presentation/widgets/ideogram_caption_view.dart` - 314 lines (threshold 300)
- `lib/features/structured_captioning/presentation/widgets/interactive_bbox_canvas.dart` - 375 lines (threshold 300)

## Cross-feature imports

**Imports into another feature's internal layers**
- `lib/features/image_list/logic/image_list_cubit.dart`: **image_list** -> **image_operations/data**
  `11:import '../../../features/image_operations/data/utils/image_utils.dart';`
- `lib/features/structured_captioning/logic/structured_captioning_cubit.dart`: **structured_captioning** -> **captioning/data**
  `6:import '../../../features/captioning/data/models/caption_entry.dart';`
✅ No cross-feature domain/shared imports to review

## Heuristic signals
_These are grep-based leads. Inspect surrounding code before turning them into audit findings._

**Direct color usage to inspect**
- `lib/core/presentation/pages/home_page.dart`
- `lib/core/widgets/app_button.dart`
- `lib/core/widgets/notification_overlay.dart`
- `lib/features/agent_api/presentation/widgets/agent_api_panel.dart`
- `lib/features/caption_search/presentation/widgets/caption_search_bar.dart`
- `lib/features/caption_search/presentation/widgets/filter_help_dialog.dart`
- `lib/features/caption_search/presentation/widgets/search_autocomplete_overlay.dart`
- `lib/features/caption_search/presentation/widgets/tag_filter_chips_overlay.dart`
- `lib/features/captioning/presentation/widgets/batch_json_apply_dialog.dart`
- `lib/features/captioning/presentation/widgets/caption_controls.dart`
- `lib/features/captioning/presentation/widgets/caption_text_area.dart`
- `lib/features/captioning/presentation/widgets/category_tab_bar.dart`
- `lib/features/captioning/presentation/widgets/convert_captions_dialog.dart`
- `lib/features/captioning/presentation/widgets/highlight_text_controller.dart`
- `lib/features/captioning/presentation/widgets/paste_json_dialog.dart`
- `lib/features/captioning/presentation/widgets/rewrite_caption_dialog.dart`
- `lib/features/export/presentation/widgets/caption_files_button.dart`
- `lib/features/export/presentation/widgets/export_button.dart`
- `lib/features/image_list/presentation/widgets/image_list_item.dart`
- `lib/features/image_list/presentation/widgets/tag_editor.dart`
- `lib/features/image_operations/presentation/pages/aspect_ratio_dialog.dart`
- `lib/features/image_operations/presentation/pages/crop_image_screen.dart`
- `lib/features/image_operations/presentation/widgets/controls_widgets.dart`
- `lib/features/llm_config/presentation/pages/llm_config_widget.dart`
- `lib/features/llm_config/presentation/pages/llm_settings_screen.dart`
- `lib/features/llm_config/presentation/widgets/models_prompts_panel.dart`
- `lib/features/llm_config/presentation/widgets/settings_section_header.dart`
- `lib/features/llm_config/presentation/widgets/structured_panel.dart`
- `lib/features/main_area/presentation/pages/current_image_view.dart`
- `lib/features/structured_captioning/presentation/pages/structured_editor_page.dart`
- `lib/features/structured_captioning/presentation/utils/bbox_utils.dart`
- `lib/features/structured_captioning/presentation/widgets/bbox_overlay.dart`
- `lib/features/structured_captioning/presentation/widgets/color_palette_editor.dart`
- `lib/features/structured_captioning/presentation/widgets/color_picker_dialog.dart`
- `lib/features/structured_captioning/presentation/widgets/element_detail_section.dart`
- `lib/features/structured_captioning/presentation/widgets/ideogram_caption_summary_card.dart`
- `lib/features/structured_captioning/presentation/widgets/ideogram_caption_view.dart`
- `lib/features/structured_captioning/presentation/widgets/image_eyedropper_dialog.dart`
- `lib/features/structured_captioning/presentation/widgets/interactive_bbox_canvas.dart`
- `lib/features/structured_captioning/presentation/widgets/interactive_bbox_painter.dart`
- `lib/features/structured_captioning/presentation/widgets/layer_thumbnail.dart`
- `lib/features/structured_captioning/presentation/widgets/layer_tile.dart`
- `lib/features/structured_captioning/presentation/widgets/recaption_element_dialog.dart`
- `lib/features/structured_captioning/presentation/widgets/structured_caption_controls.dart`
- `lib/features/tab_manager/presentation/widgets/tab_bar_widget.dart`
- `lib/main.dart`

**print / debugPrint to inspect**
- `lib/core/config/service_locator.dart`
- `lib/features/image_list/presentation/utils/folder_utils.dart`
- `lib/features/image_operations/data/utils/image_utils.dart`
- `lib/helpers/image_operations_helper.dart`

**Widget helper methods to inspect**
- `lib/core/widgets/app_button.dart:28:  Widget _buildChild() {`
- `lib/features/caption_search/presentation/widgets/caption_search_bar.dart:399:  Widget _buildContainer(`
- `lib/features/caption_search/presentation/widgets/caption_search_bar.dart:413:  Widget _buildToggleButton(`
- `lib/features/caption_search/presentation/widgets/caption_search_bar.dart:431:  Widget _buildAnimatedContent(`
- `lib/features/caption_search/presentation/widgets/filter_help_dialog.dart:116:  Widget _buildFilterTable() {`
- `lib/features/caption_search/presentation/widgets/filter_help_dialog.dart:182:  Widget _buildExample(String query, String description) {`
- `lib/features/caption_search/presentation/widgets/search_autocomplete_overlay.dart:318:  Widget _buildHeader(String text) {`
- `lib/features/caption_search/presentation/widgets/search_autocomplete_overlay.dart:334:  Widget _buildSuggestionItem(AutocompleteSuggestion suggestion, int index) {`
- `lib/features/captioning/presentation/widgets/caption_controls.dart:111:  Widget _buildRadioButton({`
- `lib/features/captioning/presentation/widgets/caption_controls.dart:177:  Widget _buildScopeToFilteredCheckbox(ImageListState imageState) {`
- `lib/features/captioning/presentation/widgets/caption_controls.dart:246:  Widget _buildJsonContextControl(ImageListState imageState) {`
- `lib/features/captioning/presentation/widgets/convert_captions_dialog.dart:260:  Widget _buildSourceDropdown(List<String> sourceCategories, String active) {`
- `lib/features/captioning/presentation/widgets/convert_captions_dialog.dart:298:  Widget _buildOptionDropdown(_ConvertCounts counts) {`
- `lib/features/captioning/presentation/widgets/convert_captions_dialog.dart:331:  Widget _buildConfigDropdown(List<LlmConfig> configs) {`
- `lib/features/image_list/presentation/widgets/header_widget.dart:57:  Widget _buildFolderInfoRow(BuildContext context, ImageListState state) {`
- `lib/features/image_list/presentation/widgets/header_widget.dart:100:  Widget _buildImageCountRow(List<AppImage> images, String? activeCategory) {`
- `lib/features/image_list/presentation/widgets/header_widget.dart:140:  Widget _buildWordsPerCaptionRow(BuildContext context) {`
- `lib/features/image_operations/presentation/pages/aspect_ratio_dialog.dart:117:  Widget _buildTagsSection(`
- `lib/features/image_operations/presentation/pages/aspect_ratio_dialog.dart:164:  Widget _buildSection(`
- `lib/features/image_operations/presentation/pages/aspect_ratio_dialog.dart:202:  Widget _buildItemCard(BuildContext context, _RatioItem item) {`
- `lib/features/image_operations/presentation/widgets/controls_view.dart:31:  Widget _buildProjectActionsRow() => Container(`
- `lib/features/image_operations/presentation/widgets/controls_view.dart:46:  Widget _buildGenerationControlPanel() => Container(`
- `lib/features/llm_config/presentation/widgets/llm_config_dialog.dart:221:  Widget _buildField(`
- `lib/features/llm_config/presentation/widgets/models_prompts_panel.dart:149:  Widget _buildModelsList(LlmConfigsState state) {`
- `lib/features/llm_config/presentation/widgets/models_prompts_panel.dart:200:  Widget _buildPromptsList(LlmConfigsState state) {`
- `lib/features/main_area/presentation/pages/current_image_view.dart:193:  Widget _buildTimestamp(BuildContext context, AppImage currentImage) {`
- `lib/features/main_area/presentation/pages/current_image_view.dart:223:  Widget _buildSizeInfos(AppImage image) {`
- `lib/features/structured_captioning/presentation/widgets/ideogram_caption_view.dart:41:  Widget _buildStructuredView(Map<String, dynamic> data) {`
- `lib/features/structured_captioning/presentation/widgets/ideogram_caption_view.dart:98:  Widget _buildSectionHeader(IconData icon, String title) {`
- `lib/features/structured_captioning/presentation/widgets/ideogram_caption_view.dart:117:  Widget _buildStyleSection(Map<String, dynamic> style) {`
- `lib/features/structured_captioning/presentation/widgets/image_eyedropper_dialog.dart:115:  Widget _buildBody() {`
- `lib/features/structured_captioning/presentation/widgets/structured_caption_controls.dart:67:  Widget _buildRadioButton({`
- `lib/features/structured_captioning/presentation/widgets/structured_caption_controls.dart:123:  Widget _buildRunButton() => BlocBuilder<ImageListCubit, ImageListState>(`

**BlocConsumer usage to inspect**
- `lib/features/image_operations/presentation/pages/convert_images_dialog.dart:17:    return BlocConsumer<ImageOperationsCubit, ImageOperationsState>(`

## DI wiring integrity
✅ `lib/core/config/service_locator.dart` - 7 registration(s)
✅ No obvious manual cubit/bloc construction detected

## Cubit coupling analysis
**Cubit/bloc count per feature** (raw counts only — judge boundaries by cohesion, not by number):
- agent_api: 0
- caption_search: 1
- captioning: 2
- export: 0
- image_list: 1
- image_operations: 1
- llm_config: 1
- main_area: 0
- structured_captioning: 2
- tab_manager: 1

**Stored cubit/bloc dependencies** (should usually be 0):
- ⚠️ `lib/features/caption_search/logic/caption_search_cubit.dart`
  `23:  final ImageListCubit imageListCubit;`
- ⚠️ `lib/features/captioning/logic/batch_apply/batch_json_apply_cubit.dart`
  `17:  final ImageListCubit _imageListCubit;`
  `23:    final List<AppImage> allImages = _imageListCubit.state.images;`
  `26:      final String category = _imageListCubit.state.activeCategory ?? 'default';`
- ⚠️ `lib/features/captioning/logic/captioning_cubit.dart`
  `22:  final ImageListCubit _imageListCubit;`
  `54:    final String category = _imageListCubit.state.activeCategory ?? 'default';`
  `58:        final AppImage? currentImage = _imageListCubit.currentDisplayedImage;`
  `99:    final AppImage? guidanceSource = _imageListCubit.currentDisplayedImage;`
  `227:    final AppImage? currentImage = _imageListCubit.currentDisplayedImage;`
  `231:    final String category = _imageListCubit.state.activeCategory ?? 'default';`
  `275:        final AppImage? currentImage = _imageListCubit.currentDisplayedImage;`
- ⚠️ `lib/features/image_operations/logic/image_operations_cubit.dart`
  `15:  final ImageListCubit _imageListCubit;`
  `60:    final int totalImages = _imageListCubit.state.images.length;`
- ⚠️ `lib/features/structured_captioning/logic/structured_captioning_cubit.dart`
  `24:  final ImageListCubit _imageListCubit;`
  `58:        final AppImage? currentImage = _imageListCubit.currentDisplayedImage;`
  `106:    final AppImage? guidanceSource = _imageListCubit.currentDisplayedImage;`
- ⚠️ `lib/features/structured_captioning/logic/structured_editor_cubit.dart`
  `45:  final ImageListCubit _imageListCubit;`
- ⚠️ `lib/features/tab_manager/logic/tab_manager_cubit.dart`
  `14:  final Map<String, ImageListCubit> _tabCubits = <String, ImageListCubit>{};`

## Routing
⚠️ No router file found

## Test coverage
Total: 68 | Cubit/BLoC: 11 | Widget/Screen: 2 | Repo: 3

- ✅ agent_api (3 file(s))
- ✅ caption_search (15 file(s))
- ✅ captioning (26 file(s))
- ✅ export (4 file(s))
- ✅ image_list (18 file(s))
- ✅ image_operations (15 file(s))
- ✅ llm_config (10 file(s))
- ⚠️ main_area (no obvious feature tests)
- ✅ structured_captioning (33 file(s))
- ✅ tab_manager (5 file(s))
