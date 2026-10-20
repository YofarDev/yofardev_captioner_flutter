import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/models/ideogram_caption.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/notification_overlay.dart';
import '../../../image_list/image_list.dart';
import '../../../image_operations/image_operations.dart';
import '../../../llm_config/llm_config.dart';
import '../../../structured_captioning/structured_captioning.dart';
import '../../domain/models/batch_apply_template.dart';
import '../../domain/models/caption_options.dart';
import '../bloc/batch_apply/batch_json_apply_cubit.dart';
import '../bloc/batch_apply/batch_json_apply_state.dart';
import '../bloc/captioning_cubit.dart';
import 'batch_json_apply_dialog.dart';
import 'batch_progress_panel.dart';
import 'caption_mode_selector.dart';
import 'convert_captions_dialog.dart';
import 'guidance_dialog.dart';

class CaptionControls extends StatefulWidget {
  const CaptionControls({super.key});

  @override
  State<CaptionControls> createState() => _CaptionControlsState();
}

class _CaptionControlsState extends State<CaptionControls> {
  CaptionOptions _selectedOption = CaptionOptions.values.first;
  bool _scopeToFiltered = false;
  String? _jsonContextCategory;

  @override
  Widget build(BuildContext context) {
    final ImageListState imageState = context.read<ImageListCubit>().state;
    final int totalImages = imageState.images.length;

    return BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
      builder: (BuildContext context, LlmConfigsState configState) {
        final bool ideogramMode = configState.llmConfigs.ideogramJsonEnabled;
        final String category = imageState.activeCategory ?? 'default';
        final int missingCount = imageState.images
            .where((AppImage img) => _isMissing(img, category, ideogramMode))
            .length;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SettingsButton(),
                const LlmConfigWidget(),
                const SizedBox(width: 16),
                Expanded(
                  child: CaptionModeSelector(
                    selected: _selectedOption,
                    onChanged: (CaptionOptions? value) {
                      if (value != null) {
                        setState(() => _selectedOption = value);
                      }
                    },
                    missingCount: missingCount,
                    totalImages: totalImages,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRunButton(count: totalImages),
          ],
        );
      },
    );
  }

  bool _isMissing(AppImage img, String category, bool ideogramMode) {
    final String text = img.captions[category]?.text ?? '';
    if (ideogramMode) {
      return text.isEmpty ||
          !IdeogramCaption.isIdeogramJson(text) ||
          IdeogramCaption.hasEmptyHighLevelDescription(text);
    }
    return text.isEmpty;
  }

  Widget _buildScopeToFilteredCheckbox(ImageListState imageState) {
    final bool hasActiveSearch = imageState.searchQuery.isNotEmpty;
    if (!hasActiveSearch) {
      return const SizedBox.shrink();
    }
    final ImageListCubit cubit = context.read<ImageListCubit>();
    final List<AppImage> filtered = cubit.filteredImages;
    final int scopeCount;
    if (_selectedOption == CaptionOptions.missing) {
      final bool ideogramMode = context
          .read<LlmConfigsCubit>()
          .state
          .llmConfigs
          .ideogramJsonEnabled;
      final String category = imageState.activeCategory ?? 'default';
      scopeCount = filtered
          .where((AppImage img) => _isMissing(img, category, ideogramMode))
          .length;
    } else {
      scopeCount = filtered.length;
    }
    final bool disabledForCurrent = _selectedOption == CaptionOptions.current;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Opacity(
        opacity: disabledForCurrent ? 0.4 : 1.0,
        child: AbsorbPointer(
          absorbing: disabledForCurrent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(unselectedWidgetColor: lightPink.withAlpha(120)),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _scopeToFiltered,
                    onChanged: (bool? value) {
                      setState(() {
                        _scopeToFiltered = value ?? false;
                      });
                    },
                    activeColor: lightPink,
                    checkColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Limit to search results ($scopeCount)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(220),
                  decoration: disabledForCurrent
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJsonContextControl(ImageListState imageState) {
    final List<String> otherCategories = imageState.categories
        .where((String c) => c != (imageState.activeCategory ?? 'default'))
        .toList(growable: false);
    if (otherCategories.isEmpty) {
      return const SizedBox.shrink();
    }
    final String? selected = otherCategories.contains(_jsonContextCategory)
        ? _jsonContextCategory
        : null;
    if (selected == null && _jsonContextCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _jsonContextCategory = null);
      });
    }
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Theme(
            data: Theme.of(
              context,
            ).copyWith(unselectedWidgetColor: lightPink.withAlpha(120)),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: selected != null,
                onChanged: (bool? value) {
                  setState(() {
                    _jsonContextCategory = (value ?? false)
                        ? otherCategories.first
                        : null;
                  });
                },
                activeColor: lightPink,
                checkColor: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'JSON context:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withAlpha(220),
            ),
          ),
          const SizedBox(width: 6),
          DropdownButton<String?>(
            value: selected,
            underline: const SizedBox.shrink(),
            dropdownColor: panelRaised,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(child: Text('None')),
              for (final String c in otherCategories)
                DropdownMenuItem<String?>(value: c, child: Text(c)),
            ],
            onChanged: (String? value) {
              setState(() => _jsonContextCategory = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRunButton({
    required int count,
  }) => BlocBuilder<ImageListCubit, ImageListState>(
    builder: (BuildContext context, ImageListState imageListState) {
      return BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
        builder: (BuildContext context, LlmConfigsState configState) {
          final bool ideogramMode = configState.llmConfigs.ideogramJsonEnabled;

          if (ideogramMode) {
            return BlocBuilder<
              StructuredCaptioningCubit,
              StructuredCaptioningState
            >(
              builder:
                  (
                    BuildContext context,
                    StructuredCaptioningState structuredState,
                  ) {
                    return _buildRunRow(
                      context: context,
                      imageListState: imageListState,
                      configState: configState,
                      isInProgress:
                          structuredState.status ==
                          StructuredCaptioningStatus.inProgress,
                      processedImages: structuredState.processedImages,
                      totalImages: structuredState.totalImages,
                      isCancelling: structuredState.isCancelling,
                      stepLabel: structuredState.stepLabel,
                      error: structuredState.error,
                      isIdeogram: true,
                      imageCount: count,
                    );
                  },
            );
          }

          return BlocBuilder<CaptioningCubit, CaptioningState>(
            builder: (BuildContext context, CaptioningState captioningState) {
              return _buildRunRow(
                context: context,
                imageListState: imageListState,
                configState: configState,
                isInProgress:
                    captioningState.status == CaptioningStatus.inProgress,
                processedImages: captioningState.processedImages,
                totalImages: captioningState.totalImages,
                isCancelling: captioningState.isCancelling,
                stepLabel: null,
                error: captioningState.error,
                isIdeogram: false,
                imageCount: count,
              );
            },
          );
        },
      );
    },
  );

  Widget _buildGuidanceToggle(
    BuildContext context,
    ImageListState imageListState,
  ) {
    final bool enabled = imageListState.guidanceEnabled;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Guidance',
            style: TextStyle(
              color: enabled ? textPrimary : textMuted,
              fontSize: 12,
            ),
          ),
          IconButton(
            tooltip: 'Edit per-image guidance',
            icon: Icon(
              Icons.tune,
              size: 16,
              color: enabled ? lightPink : textMuted,
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: () => showDialog<void>(
              context: context,
              // The dialog is inserted into the navigator overlay, which sits
              // above the BlocProvider tree — so re-provide the existing cubit
              // instance into the dialog subtree.
              builder: (BuildContext _) => BlocProvider<ImageListCubit>.value(
                value: context.read<ImageListCubit>(),
                child: const GuidanceDialog(),
              ),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (bool v) =>
                context.read<ImageListCubit>().setGuidanceEnabled(v),
            activeThumbColor: lightPink,
            activeTrackColor: lightPink.withValues(alpha: 0.35),
            inactiveThumbColor: textSecondary,
            inactiveTrackColor: hairline,
            trackOutlineColor: WidgetStateProperty.all<Color>(
              Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunRow({
    required BuildContext context,
    required ImageListState imageListState,
    required LlmConfigsState configState,
    required bool isInProgress,
    required int processedImages,
    required int totalImages,
    required bool isCancelling,
    required String? stepLabel,
    required String? error,
    required bool isIdeogram,
    required int imageCount,
  }) {
    final Color accentColor = isIdeogram
        ? Colors.teal.withAlpha(220)
        : lightPink.withAlpha(220);
    final bool scoped =
        _scopeToFiltered && imageListState.searchQuery.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (imageListState.searchQuery.isNotEmpty) ...<Widget>[
          _buildScopeToFilteredCheckbox(imageListState),
          const SizedBox(width: 12),
        ],
        if (!isIdeogram) ...<Widget>[
          _buildJsonContextControl(imageListState),
          const SizedBox(width: 12),
        ],
        _buildGuidanceToggle(context, imageListState),
        const SizedBox(width: 12),
        GestureDetector(
          onSecondaryTap: () {
            if (!isInProgress) {
              context.read<LlmConfigsCubit>().setIdeogramJsonEnabled(
                !isIdeogram,
              );
            }
          },
          child: Tooltip(
            message: isIdeogram
                ? 'Run AI structured captioning (right-click to toggle mode)'
                : 'Run AI caption generation (right-click to toggle mode)',
            child: AppButton(
              text: isIdeogram ? "▶  JSON Run" : "▶  Run",
              isLoading: isInProgress,
              backgroundColor: accentColor,
              onTap:
                  imageListState.images.isNotEmpty &&
                      configState.llmConfigs.selectedConfigId != null &&
                      !isInProgress
                  ? () async {
                      final LlmConfig llm = configState.llmConfigs.configs
                          .firstWhere(
                            (LlmConfig c) =>
                                c.id == configState.llmConfigs.selectedConfigId,
                          );
                      if (!await _confirmOverwriteAll(context) ||
                          !context.mounted) {
                        return;
                      }
                      if (isIdeogram) {
                        context
                            .read<StructuredCaptioningCubit>()
                            .runStructuredCaptioner(
                              llm: llm,
                              option: _selectedOption,
                              overrides:
                                  configState
                                      .llmConfigs
                                      .structuredBatchOverrides
                                      .enabled
                                  ? configState
                                        .llmConfigs
                                        .structuredBatchOverrides
                                  : null,
                              debugMode: configState.llmConfigs.debugMode,
                              disableSam: configState.llmConfigs.disableSam,
                              vlmEmitsXyxy: configState.llmConfigs.vlmEmitsXyxy,
                              multiStage: configState.llmConfigs.multiStage,
                              scopeToFiltered: scoped,
                            );
                      } else {
                        context.read<CaptioningCubit>().runCaptioner(
                          llm: llm,
                          prompt: configState.llmConfigs.selectedPrompt!,
                          option: _selectedOption,
                          scopeToFiltered: scoped,
                          jsonContextCategory: _jsonContextCategory,
                        );
                      }
                    }
                  : null,
            ),
          ),
        ),
        if (!isIdeogram) ...<Widget>[
          const SizedBox(width: 8),
          Tooltip(
            message:
                'Convert captions between categories '
                '(text-only, no image sent)',
            child: AppButton(
              text: 'Convert',
              iconData: Icons.transform,
              isOutline: true,
              backgroundColor: lightPink,
              foregroundColor: lightPink,
              onTap:
                  !isInProgress &&
                      imageListState.categories.length > 1 &&
                      configState.llmConfigs.selectedConfigId != null
                  ? () => showDialog<void>(
                      context: context,
                      builder: (BuildContext _) => MultiBlocProvider(
                        providers: <BlocProvider<dynamic>>[
                          BlocProvider<CaptioningCubit>.value(
                            value: context.read<CaptioningCubit>(),
                          ),
                          BlocProvider<ImageListCubit>.value(
                            value: context.read<ImageListCubit>(),
                          ),
                          BlocProvider<LlmConfigsCubit>.value(
                            value: context.read<LlmConfigsCubit>(),
                          ),
                        ],
                        child: const ConvertCaptionsDialog(),
                      ),
                    )
                  : null,
            ),
          ),
        ],
        if (isIdeogram) const SizedBox(width: 8),
        if (isIdeogram)
          _buildBatchApplyButton(context, configState, imageCount),
        if (isInProgress) ...<Widget>[
          BatchProgressPanel(
            isIdeogram: isIdeogram,
            stepLabel: stepLabel,
            processedImages: processedImages,
            totalImages: totalImages,
            isCancelling: isCancelling,
            onStop: () {
              if (isIdeogram) {
                context
                    .read<StructuredCaptioningCubit>()
                    .cancelStructuredCaptioning();
              } else {
                context.read<CaptioningCubit>().cancelCaptioning();
              }
            },
          ),
          const SizedBox(width: 10),
          StopButton(
            isCancelling: isCancelling,
            onTap: () {
              if (isIdeogram) {
                context
                    .read<StructuredCaptioningCubit>()
                    .cancelStructuredCaptioning();
              } else {
                context.read<CaptioningCubit>().cancelCaptioning();
              }
            },
          ),
        ],
        if (error != null && error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Tooltip(
              message: error,
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: error));
                  NotificationOverlay.show(
                    context,
                    message: 'Error copied to clipboard',
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: destructive.withAlpha(100),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: destructive,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// For "All" runs, confirm before overwriting images that already have a
  /// caption in the active category.
  // ponytail: duplicates the cubits' all-option target selection; if their
  // filter rules diverge this count drifts. Move into a shared domain preview.
  Future<bool> _confirmOverwriteAll(BuildContext context) async {
    if (_selectedOption != CaptionOptions.all) return true;
    final ImageListCubit cubit = context.read<ImageListCubit>();
    final ImageListState imgState = cubit.state;
    final String category = imgState.activeCategory ?? 'default';
    final bool scoped = _scopeToFiltered && imgState.searchQuery.isNotEmpty;
    final List<AppImage> base = scoped ? cubit.filteredImages : imgState.images;
    final List<AppImage> target = scoped
        ? base.toList()
        : base.where((AppImage i) => !i.isCaptionEdited).toList();
    final int wouldOverwrite = target
        .where((AppImage i) => (i.captions[category]?.text ?? '').isNotEmpty)
        .length;
    if (wouldOverwrite == 0) return true;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: panelRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: <Widget>[
            Icon(Icons.warning_amber_rounded, color: amberWarn, size: 22),
            SizedBox(width: 10),
            Text(
              'Replace existing captions?',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Captioning "All" will overwrite existing captions for '
          '$wouldOverwrite image${wouldOverwrite == 1 ? '' : 's'}. '
          'This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: amberWarn,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Widget _buildBatchApplyButton(
    BuildContext context,
    LlmConfigsState configState,
    int imageCount,
  ) {
    return BlocBuilder<BatchJsonApplyCubit, BatchJsonApplyState>(
      builder: (BuildContext context, BatchJsonApplyState state) {
        final bool isInProgress = state is BatchJsonApplyInProgress;
        final bool hasError = state is BatchJsonApplyError;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Tooltip(
              message:
                  'Overwrite captions for selected images using a '
                  'structured JSON template',
              child: AppButton(
                text: 'Batch Apply',
                isOutline: true,
                backgroundColor: accentPink,
                foregroundColor: accentPink,
                onTap: isInProgress
                    ? null
                    : () async {
                        if (_selectedOption == CaptionOptions.all &&
                            imageCount > 1) {
                          final bool? confirmed = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext ctx) {
                              return AlertDialog(
                                backgroundColor: panelRaised,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                title: const Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: amberWarn,
                                      size: 22,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Confirm Batch Apply',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                                content: Text(
                                  'This will overwrite captions for '
                                  '$imageCount images. '
                                  'This action cannot be undone.',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: amberWarn,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Continue'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirmed != true || !context.mounted) return;
                        }
                        final BatchApplyTemplate? template =
                            await showDialog<BatchApplyTemplate>(
                              context: context,
                              builder: (BuildContext _) =>
                                  const BatchJsonApplyDialog(),
                            );
                        if (template != null && context.mounted) {
                          context.read<BatchJsonApplyCubit>().apply(template);
                        }
                      },
              ),
            ),
            if (isInProgress) ...<Widget>[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentPink.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.processedImages}/${state.totalImages}',
                  style: const TextStyle(
                    color: accentPink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StopButton(
                isCancelling: false,
                onTap: () => context.read<BatchJsonApplyCubit>().cancel(),
              ),
            ],
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Tooltip(
                  message: state.message,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: destructive.withAlpha(100),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: destructive,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
