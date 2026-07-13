import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/notification_overlay.dart';
import '../../../image_list/data/models/app_image.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../llm_config/data/models/llm_config.dart';
import '../../../llm_config/logic/llm_configs_cubit.dart';
import '../../data/models/caption_options.dart';
import '../../logic/captioning_cubit.dart';

/// Default conversion prompt used to prefill the editable prompt field.
const String kDefaultConvertPrompt =
    'Write a very detailed natural language caption from the JSON caption '
    'below. Remove mention of color palette, style, atmosphere, but try to '
    'keep as much as possible of the other information.';

/// Dialog that batch-converts captions from a source category into the active
/// category via a text-only LLM transform (no image is sent). Mirrors the
/// batch captioning option model (current / missing / all).
class ConvertCaptionsDialog extends StatefulWidget {
  const ConvertCaptionsDialog({super.key});

  @override
  State<ConvertCaptionsDialog> createState() => _ConvertCaptionsDialogState();
}

class _ConvertCaptionsDialogState extends State<ConvertCaptionsDialog> {
  late final TextEditingController _promptController;
  String? _sourceCategory;
  CaptionOptions _selectedOption = CaptionOptions.missing;
  String? _selectedConfigId;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: kDefaultConvertPrompt);
    _promptController.addListener(_persistPrompt);
    _loadSavedPrompt();
    final ImageListState imageState = context.read<ImageListCubit>().state;
    final String active = imageState.activeCategory ?? 'default';
    _sourceCategory = imageState.categories.firstWhere(
      (String c) => c != active,
      orElse: () => active,
    );
    final LlmConfigsState configState = context.read<LlmConfigsCubit>().state;
    _selectedConfigId = configState.llmConfigs.selectedConfigId;
  }

  @override
  void dispose() {
    _promptController.removeListener(_persistPrompt);
    _promptController.dispose();
    super.dispose();
  }

  void _persistPrompt() {
    CacheService.saveConvertPrompt(_promptController.text);
  }

  Future<void> _loadSavedPrompt() async {
    final String? saved = await CacheService.loadConvertPrompt();
    if (saved != null && saved.isNotEmpty && mounted) {
      _promptController.text = saved;
    }
  }

  void _restoreDefaultPrompt() {
    _promptController.text = kDefaultConvertPrompt;
    _promptController.selection = TextSelection.fromPosition(
      TextPosition(offset: _promptController.text.length),
    );
  }

  Future<void> _submit() async {
    final String prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      NotificationOverlay.show(
        context,
        message: 'Enter a conversion prompt',
        backgroundColor: destructive,
      );
      return;
    }
    final ImageListCubit imageListCubit = context.read<ImageListCubit>();
    final String target = imageListCubit.state.activeCategory ?? 'default';
    if (_sourceCategory == null || _sourceCategory == target) {
      NotificationOverlay.show(
        context,
        message: 'Pick a different source category',
        backgroundColor: destructive,
      );
      return;
    }
    final LlmConfigsState configState = context.read<LlmConfigsCubit>().state;
    if (_selectedConfigId == null) {
      NotificationOverlay.show(
        context,
        message: 'Select an LLM configuration first',
        backgroundColor: destructive,
      );
      return;
    }
    final LlmConfig llm = configState.llmConfigs.configs.firstWhere(
      (LlmConfig c) => c.id == _selectedConfigId,
    );

    context.read<CaptioningCubit>().convertCaptionsBatch(
      llm: llm,
      sourceCategory: _sourceCategory!,
      prompt: prompt,
      option: _selectedOption,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState imageState) {
        final String active = imageState.activeCategory ?? 'default';
        final List<String> sourceCategories = imageState.categories
            .where((String c) => c != active)
            .toList(growable: false);

        return BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
          builder: (BuildContext context, LlmConfigsState configState) {
            final List<LlmConfig> configs = configState.llmConfigs.configs;
            if (_selectedConfigId != null &&
                !configs.any((LlmConfig c) => c.id == _selectedConfigId)) {
              _selectedConfigId = configs.isNotEmpty ? configs.first.id : null;
            }

            final _ConvertCounts counts = _computeCounts(
              imageState,
              active,
              _sourceCategory,
            );

            return AlertDialog(
              backgroundColor: panelRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title: const Row(
                children: <Widget>[
                  Icon(Icons.transform, color: lightPink, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Convert captions',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 18,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _label('Source category (read from)'),
                      const SizedBox(height: 6),
                      _buildSourceDropdown(sourceCategories, active),
                      const SizedBox(height: 14),
                      _label(
                        'Target category (write to): '
                        '$active — switch tab first to change',
                      ),
                      const SizedBox(height: 14),
                      _label('Which images'),
                      const SizedBox(height: 6),
                      _buildOptionDropdown(counts),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          _label('Prompt'),
                          TextButton(
                            onPressed: _restoreDefaultPrompt,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Restore default',
                              style: TextStyle(fontSize: 11, color: lightPink),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _promptController,
                        minLines: 4,
                        maxLines: 8,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          height: 1.4,
                          color: textPrimary,
                        ),
                        decoration: _fieldDecoration(
                          'Conversion instructions for the model',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _label('Model / Provider'),
                      const SizedBox(height: 6),
                      _buildConfigDropdown(configs),
                      const SizedBox(height: 10),
                      _infoBanner(counts.total),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: textSecondary),
                  ),
                ),
                AppButton(
                  text: 'Convert',
                  backgroundColor: lightPink,
                  onTap: _submit,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      color: textSecondary,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _buildSourceDropdown(List<String> sourceCategories, String active) {
    if (sourceCategories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: _boxDecoration(),
        child: Text(
          'No other categories. Create one (e.g. "$active" is the only tab).',
          style: const TextStyle(fontSize: 13, color: destructive),
        ),
      );
    }
    if (_sourceCategory == null ||
        !sourceCategories.contains(_sourceCategory)) {
      _sourceCategory = sourceCategories.first;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _boxDecoration(),
      child: DropdownButton<String>(
        value: _sourceCategory,
        isExpanded: true,
        dropdownColor: panelDark,
        underline: const SizedBox.shrink(),
        style: const TextStyle(color: textPrimary, fontSize: 14),
        items: sourceCategories
            .map<DropdownMenuItem<String>>(
              (String c) => DropdownMenuItem<String>(value: c, child: Text(c)),
            )
            .toList(),
        onChanged: (String? value) {
          if (value != null) {
            setState(() => _sourceCategory = value);
          }
        },
      ),
    );
  }

  Widget _buildOptionDropdown(_ConvertCounts counts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _boxDecoration(),
      child: DropdownButton<CaptionOptions>(
        value: _selectedOption,
        isExpanded: true,
        dropdownColor: panelDark,
        underline: const SizedBox.shrink(),
        style: const TextStyle(color: textPrimary, fontSize: 14),
        items: <DropdownMenuItem<CaptionOptions>>[
          DropdownMenuItem<CaptionOptions>(
            value: CaptionOptions.current,
            child: Text('This image (${counts.current})'),
          ),
          DropdownMenuItem<CaptionOptions>(
            value: CaptionOptions.missing,
            child: Text('Missing in target, has source (${counts.missing})'),
          ),
          DropdownMenuItem<CaptionOptions>(
            value: CaptionOptions.all,
            child: Text('All with source (${counts.all})'),
          ),
        ],
        onChanged: (CaptionOptions? value) {
          if (value != null) {
            setState(() => _selectedOption = value);
          }
        },
      ),
    );
  }

  Widget _buildConfigDropdown(List<LlmConfig> configs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _boxDecoration(),
      child: DropdownButton<String>(
        value: _selectedConfigId,
        isExpanded: true,
        dropdownColor: panelDark,
        underline: const SizedBox.shrink(),
        hint: const Text(
          'Select a model...',
          style: TextStyle(color: textMuted, fontSize: 14),
        ),
        style: const TextStyle(color: textPrimary, fontSize: 14),
        items: configs
            .map<DropdownMenuItem<String>>(
              (LlmConfig c) =>
                  DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
            )
            .toList(),
        onChanged: (String? id) {
          setState(() => _selectedConfigId = id);
        },
      ),
    );
  }

  Widget _infoBanner(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: lightPink.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, size: 14, color: lightPink.withAlpha(180)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Text-only — no image is sent. '
              '$total image${total == 1 ? '' : 's'} will be converted into '
              'the active tab.',
              style: TextStyle(
                fontSize: 11,
                color: lightPink.withAlpha(200),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() =>
      BoxDecoration(color: lightGrey, borderRadius: BorderRadius.circular(8));

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: textMuted),
    filled: true,
    fillColor: Colors.white.withAlpha(15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  );

  _ConvertCounts _computeCounts(
    ImageListState imageState,
    String target,
    String? source,
  ) {
    final bool hasSource = source != null;
    int current = 0;
    int missing = 0;
    int all = 0;
    for (final AppImage image in imageState.images) {
      final bool sourceNonEmpty =
          hasSource && (image.captions[source]?.text ?? '').trim().isNotEmpty;
      if (!sourceNonEmpty) {
        continue;
      }
      all++;
      if ((image.captions[target]?.text ?? '').isEmpty) {
        missing++;
      }
    }
    final AppImage? displayed = context
        .read<ImageListCubit>()
        .currentDisplayedImage;
    if (displayed != null && hasSource) {
      current = (displayed.captions[source]?.text ?? '').trim().isNotEmpty
          ? 1
          : 0;
    }
    return _ConvertCounts(
      current: current,
      missing: missing,
      all: all,
      total: _totalForOption(current, missing, all),
    );
  }

  int _totalForOption(int current, int missing, int all) {
    switch (_selectedOption) {
      case CaptionOptions.current:
        return current;
      case CaptionOptions.missing:
        return missing;
      case CaptionOptions.all:
        return all;
    }
  }
}

class _ConvertCounts {
  const _ConvertCounts({
    required this.current,
    required this.missing,
    required this.all,
    required this.total,
  });
  final int current;
  final int missing;
  final int all;
  final int total;
}
