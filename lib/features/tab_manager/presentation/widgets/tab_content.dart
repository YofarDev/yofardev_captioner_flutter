import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../caption_search/logic/caption_search_cubit.dart';
import '../../../captioning/logic/batch_apply/batch_json_apply_cubit.dart';
import '../../../captioning/logic/captioning_cubit.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../image_list/presentation/pages/images_list_view.dart';
import '../../../image_operations/logic/image_operations_cubit.dart';
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

  late final ImageListCubit _imageListCubit;
  late final CaptioningCubit _captioningCubit;
  late final StructuredCaptioningCubit _structuredCaptioningCubit;
  late final ImageOperationsCubit _imageOperationsCubit;
  late final CaptionSearchCubit _captionSearchCubit;
  late final BatchJsonApplyCubit _batchJsonApplyCubit;
  TabManagerCubit? _tabManagerCubit;

  @override
  void initState() {
    super.initState();
    _imageListCubit = ImageListCubit();
    _captioningCubit = CaptioningCubit(_imageListCubit);
    _structuredCaptioningCubit = StructuredCaptioningCubit(_imageListCubit);
    _imageOperationsCubit = ImageOperationsCubit(_imageListCubit);
    _captionSearchCubit = CaptionSearchCubit(imageListCubit: _imageListCubit);
    _batchJsonApplyCubit = BatchJsonApplyCubit(_imageListCubit);
    // Register with TabManagerCubit after first frame (context available)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tabManagerCubit = context.read<TabManagerCubit>();
      _tabManagerCubit!.registerTabCubit(widget.tabId, _imageListCubit);
    });
  }

  @override
  void dispose() {
    _tabManagerCubit?.unregisterTabCubit(widget.tabId);
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
            color: lightGrey,
            height: double.infinity,
            width: 240,
            child: const ImagesListView(),
          ),
          const Expanded(
            child: ColoredBox(color: darkGrey, child: MainAreaView()),
          ),
        ],
      ),
    );
  }
}
