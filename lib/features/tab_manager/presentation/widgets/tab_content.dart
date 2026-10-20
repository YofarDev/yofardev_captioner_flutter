import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../../caption_search/logic/caption_search_cubit.dart';
import '../../../captioning/data/repositories/captioning_repository.dart';
import '../../../captioning/logic/batch_apply/batch_json_apply_cubit.dart';
import '../../../captioning/logic/captioning_cubit.dart';
import '../../../image_list/domain/services/caption_session_service.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../image_list/presentation/pages/images_list_view.dart';
import '../../../image_operations/image_operations.dart';
import '../../../main_area/presentation/pages/main_area_view.dart';
import '../../../structured_captioning/logic/structured_captioning_cubit.dart';
import '../../logic/tab_manager_cubit.dart';

class TabContent extends StatefulWidget {
  const TabContent({super.key, required this.tabId});

  final String tabId;

  @override
  State<TabContent> createState() => TabContentState();
}

class TabContentState extends State<TabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final CaptionSessionService _session;
  late final ImageListCubit _imageListCubit;
  late final CaptioningCubit _captioningCubit;
  late final StructuredCaptioningCubit _structuredCaptioningCubit;
  late final ImageOperationsCubit _imageOperationsCubit;
  late final CaptionSearchCubit _captionSearchCubit;
  late final BatchJsonApplyCubit _batchJsonApplyCubit;

  @override
  void initState() {
    super.initState();
    // The session already exists — the tab manager created it synchronously
    // when the tab was added, so there is nothing to wait for here.
    _session = context.read<TabManagerCubit>().sessionFor(widget.tabId);
    // Repos come from the locator so the DI graph is real even where the
    // cubit instances are tab-scoped (full factory conversion waits for
    // Phase 2.4's consumer migration).
    _imageListCubit = ImageListCubit(session: _session);
    _captioningCubit = CaptioningCubit(
      _session,
      captioningRepository: locator<CaptioningRepository>(),
    );
    _structuredCaptioningCubit = StructuredCaptioningCubit(_session);
    _imageOperationsCubit = ImageOperationsCubit(_session);
    _captionSearchCubit = CaptionSearchCubit(session: _session);
    _batchJsonApplyCubit = BatchJsonApplyCubit(_session);
  }

  @override
  void dispose() {
    _captionSearchCubit.close();
    _batchJsonApplyCubit.close();
    _imageOperationsCubit.close();
    _structuredCaptioningCubit.close();
    _captioningCubit.close();
    _imageListCubit.close();
    super.dispose();
  }

  /// Expose the ImageListCubit for external access.
  ImageListCubit get imageListCubit => _imageListCubit;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<ImageListCubit>.value(value: _imageListCubit),
        BlocProvider<CaptioningCubit>.value(value: _captioningCubit),
        BlocProvider<StructuredCaptioningCubit>.value(
          value: _structuredCaptioningCubit,
        ),
        BlocProvider<ImageOperationsCubit>.value(value: _imageOperationsCubit),
        BlocProvider<CaptionSearchCubit>.value(value: _captionSearchCubit),
        BlocProvider<BatchJsonApplyCubit>.value(value: _batchJsonApplyCubit),
      ],
      child: Row(
        children: <Widget>[
          Container(
            // Recessed library column — sits below the shell so the caption
            // editor stays the brightest (focal) surface.
            color: panelDark,
            height: double.infinity,
            width: 240,
            child: const ImagesListView(),
          ),
          const Expanded(
            child: ColoredBox(color: shellBackground, child: MainAreaView()),
          ),
        ],
      ),
    );
  }
}
