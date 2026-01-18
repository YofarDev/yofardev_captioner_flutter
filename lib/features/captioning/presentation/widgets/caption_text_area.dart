import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/notification_overlay.dart';
import '../../../image_list/data/models/app_image.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../logic/captioning_cubit.dart';

class CaptionTextArea extends StatefulWidget {
  const CaptionTextArea({super.key});

  @override
  State<CaptionTextArea> createState() => _CaptionTextAreaState();
}

class _CaptionTextAreaState extends State<CaptionTextArea> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ImageListCubit, ImageListState>(
      listener: (BuildContext context, ImageListState state) {
        if (state.images.isNotEmpty) {
          final String currentCaption =
              state.images[state.currentIndex].caption;
          if (_controller.text != currentCaption) {
            _controller.text = currentCaption;
          }
        }
      },
      child: BlocBuilder<ImageListCubit, ImageListState>(
        builder: (BuildContext context, ImageListState state) {
          if (state.images.isEmpty) {
            return const SizedBox.shrink();
          }
          final AppImage currentImage = state.images[state.currentIndex];
          return BlocBuilder<CaptioningCubit, CaptioningState>(
            builder: (BuildContext context, CaptioningState captioningState) {
              final String currentImagePath = currentImage.image.path;
              final bool isThisImageBeingCaptioned =
                  captioningState.currentlyCaptioningImage == currentImagePath;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Stack(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: lightGrey,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isThisImageBeingCaptioned
                                    ? Colors.blueAccent.withAlpha(40)
                                    : Colors.white.withAlpha(40),
                              ),
                              boxShadow: _isFocused
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: Colors.white.withAlpha(30),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : <BoxShadow>[],
                            ),
                            child: TextField(
                              focusNode: _focusNode,
                              readOnly: isThisImageBeingCaptioned,
                              controller: _controller,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.white,
                              ),
                              onChanged: (String value) {
                                if (_debounce?.isActive ?? false) {
                                  _debounce!.cancel();
                                }
                                _debounce = Timer(
                                  const Duration(milliseconds: 300),
                                  () {
                                    context
                                        .read<ImageListCubit>()
                                        .updateCaption(caption: value);
                                  },
                                );
                              },
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(50),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "${currentImage.caption.split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).length} words",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Tooltip(
                              message: currentImage.caption.trim().isEmpty
                                  ? 'No caption to copy'
                                  : 'Copy caption to clipboard',
                              child: InkWell(
                                onTap: currentImage.caption.trim().isEmpty
                                    ? null
                                    : () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: currentImage.caption,
                                          ),
                                        );
                                        NotificationOverlay.show(
                                          context,
                                          message:
                                              'Caption copied to clipboard',
                                        );
                                      },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: currentImage.caption.trim().isEmpty
                                        ? Colors.white.withAlpha(20)
                                        : Colors.white.withAlpha(40),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.copy,
                                    size: 16,
                                    color: currentImage.caption.trim().isEmpty
                                        ? Colors.white.withAlpha(50)
                                        : Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
