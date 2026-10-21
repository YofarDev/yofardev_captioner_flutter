import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../../../../core/di/service_locator.dart';
import '../../../caption_search/caption_search.dart';
import '../../../captioning/captioning.dart';
import '../../../image_list/image_list.dart';
import '../../../image_operations/image_operations.dart';
import '../../../structured_captioning/structured_captioning.dart';
import '../bloc/tab_manager_cubit.dart';

class TabContent extends StatefulWidget {
  const TabContent({super.key, required this.tabId, required this.child});

  final String tabId;

  /// The tab workspace body. Provided by the composition root (home_page)
  /// so tab_manager does not import sibling feature views; it is built
  /// *below* this widget's MultiBlocProvider, so the session cubits are
  /// visible to it.
  final Widget child;

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
    _imageListCubit = locator<ImageListCubit>(param1: _session);
    _captioningCubit = locator<CaptioningCubit>(param1: _session);
    _structuredCaptioningCubit = locator<StructuredCaptioningCubit>(
      param1: _session,
    );
    _imageOperationsCubit = locator<ImageOperationsCubit>(param1: _session);
    _captionSearchCubit = locator<CaptionSearchCubit>(param1: _session);
    _batchJsonApplyCubit = locator<BatchJsonApplyCubit>(param1: _session);
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
      child: widget.child,
    );
  }
}
