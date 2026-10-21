import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/models/structured_batch_overrides.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/widgets/rive_animations.dart';
import '../../../caption_search/caption_search.dart';
import '../../../captioning/captioning.dart';
import '../../../export/export.dart';
import '../../../image_list/image_list.dart';
import '../../../image_operations/image_operations.dart';
import '../../../structured_captioning/structured_captioning.dart';
import '../../../tab_manager/tab_manager.dart';
import 'current_image_view.dart';
import 'search_and_replace_widget.dart';

class MainAreaView extends StatelessWidget {
  const MainAreaView({super.key});

  @override
  Widget build(BuildContext context) {
    // Only the emptiness of the list decides between the empty state and the
    // editor shell — select on it so unrelated list changes don't rebuild the
    // whole view.
    return BlocSelector<ImageListCubit, ImageListState, bool>(
      selector: (ImageListState state) => state.images.isEmpty,
      builder: (BuildContext context, bool isEmpty) {
        if (isEmpty) {
          return const _EmptyView();
        }
        return Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                const CurrentImageView(),
                Expanded(
                  child: CaptionTextArea(
                    ideogramSummaryCard:
                        ({
                          required String jsonString,
                          required File imageFile,
                          required String activeCategory,
                        }) => IdeogramCaptionSummaryCard(
                          jsonString: jsonString,
                          imageFile: imageFile,
                          activeCategory: activeCategory,
                        ),
                    openStructuredEditor:
                        (
                          BuildContext context, {
                          required File imageFile,
                          required String captionJson,
                          required String activeCategory,
                          required ImageListCubit imageListCubit,
                        }) {
                          Navigator.of(context).push<bool>(
                            MaterialPageRoute<bool>(
                              builder: (BuildContext routeContext) =>
                                  StructuredEditorPage(
                                    imageFile: imageFile,
                                    captionJson: captionJson,
                                    activeCategory: activeCategory,
                                    imageListCubit: imageListCubit,
                                  ),
                            ),
                          );
                        },
                  ),
                ),
                const ControlsView(
                  searchAndReplace: SearchAndReplaceWidget(outlined: true),
                  captionFiles: CaptionFilesButton(outlined: true),
                  export: ExportButton(outlined: true),
                  captionControls: _StructuredAwareCaptionControls(),
                ),
                const SizedBox(height: 16),
              ],
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: shellBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(32),
                ),
                padding: const EdgeInsets.all(4),
                child: const CaptionSearchBar(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyView extends StatefulWidget {
  const _EmptyView();

  @override
  State<_EmptyView> createState() => _EmptyViewState();
}

class _EmptyViewState extends State<_EmptyView> {
  final CacheService _cacheService = const CacheService();
  String? _lastFolderPath;

  @override
  void initState() {
    super.initState();
    _cacheService.loadFolderPath().then((String? path) {
      if (mounted) {
        setState(() => _lastFolderPath = path);
      }
    });
  }

  Future<void> _reopenLastFolder(String folderPath) async {
    final TabManagerCubit tabManager = context.read<TabManagerCubit>();
    tabManager.updateTabFolderPath(tabManager.state.activeTab.id, folderPath);
    context.read<ImageListCubit>().onInit(folderPath: folderPath);
  }

  @override
  Widget build(BuildContext context) {
    final String? folderName = _lastFolderPath == null
        ? null
        : p.basename(_lastFolderPath!);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const RiveEmptyStateHero(),
          const SizedBox(height: 28),
          const Text(
            'Yofardev Captioner',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              fontFamily: 'Orbitron',
              color: textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Drop a folder of images anywhere to start captioning',
            style: TextStyle(fontSize: 14, color: textSecondary),
          ),
          const SizedBox(height: 28),
          const PickFolderButton(),
          if (folderName != null && folderName.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => _reopenLastFolder(_lastFolderPath!),
              style: TextButton.styleFrom(
                foregroundColor: lightPink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radiusSm),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.history, size: 15),
                  const SizedBox(width: 6),
                  Text('Reopen $folderName'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Binds the structured-captioning cubit into [CaptionControls] via injected
/// data/callbacks, keeping the captioning feature decoupled from
/// structured_captioning (the edge lives here, in the composition root).
class _StructuredAwareCaptionControls extends StatelessWidget {
  const _StructuredAwareCaptionControls();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      StructuredCaptioningCubit,
      StructuredCaptioningState,
      StructuredRunProgress
    >(
      selector: (StructuredCaptioningState s) => (
        inProgress: s.status == StructuredCaptioningStatus.inProgress,
        processedImages: s.processedImages,
        totalImages: s.totalImages,
        isCancelling: s.isCancelling,
        stepLabel: s.stepLabel,
        error: s.error,
      ),
      builder: (BuildContext context, StructuredRunProgress progress) =>
          CaptionControls(
            structuredProgress: progress,
            onRunStructured:
                ({
                  required LlmConfig llm,
                  required CaptionOptions option,
                  StructuredBatchOverrides? overrides,
                  bool debugMode = false,
                  bool disableSam = false,
                  bool vlmEmitsXyxy = true,
                  bool multiStage = false,
                  bool scopeToFiltered = false,
                }) => context
                    .read<StructuredCaptioningCubit>()
                    .runStructuredCaptioner(
                      llm: llm,
                      option: option,
                      overrides: overrides,
                      debugMode: debugMode,
                      disableSam: disableSam,
                      vlmEmitsXyxy: vlmEmitsXyxy,
                      multiStage: multiStage,
                      scopeToFiltered: scopeToFiltered,
                    ),
            onCancelStructured: () => context
                .read<StructuredCaptioningCubit>()
                .cancelStructuredCaptioning(),
            settingsButton: const SettingsButton(),
          ),
    );
  }
}
