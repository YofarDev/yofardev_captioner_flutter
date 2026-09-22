import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/widgets/rive_animations.dart';
import '../../../caption_search/presentation/widgets/caption_search_bar.dart';
import '../../../captioning/presentation/widgets/caption_text_area.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../image_operations/presentation/widgets/controls_view.dart';
import '../../../image_operations/presentation/widgets/controls_widgets.dart';
import '../../../tab_manager/logic/tab_manager_cubit.dart';
import 'current_image_view.dart';

class MainAreaView extends StatelessWidget {
  const MainAreaView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        if (state.images.isEmpty) {
          return const _EmptyView();
        }
        return Stack(
          children: <Widget>[
            const Column(
              children: <Widget>[
                CurrentImageView(),
                Expanded(child: CaptionTextArea()),
                ControlsView(),
                SizedBox(height: 16),
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
  String? _lastFolderPath;

  @override
  void initState() {
    super.initState();
    CacheService.loadFolderPath().then((String? path) {
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
