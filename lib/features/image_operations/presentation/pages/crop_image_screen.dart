import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/crop_image.dart';

class CropImageScreen extends StatefulWidget {
  final Uint8List image;

  const CropImageScreen({super.key, required this.image});

  @override
  State<CropImageScreen> createState() => _CropImageScreenState();
}

class _CropImageScreenState extends State<CropImageScreen> {
  final CropController _cropController = CropController();
  Uint8List? _croppedData;
  bool _isCropping = false;
  String _selectedAspectRatio = "1:1";
  Rect? _rect;

  double _parseAspectRatio(String ratio) {
    final List<String> parts = ratio.split(':');
    if (parts.length == 2) {
      final double? width = double.tryParse(parts[0]);
      final double? height = double.tryParse(parts[1]);
      if (width != null && height != null && height != 0) {
        return width / height;
      }
    }
    return 1.0;
  }

  Size _parseAspectRatioSize(String ratio) {
    final List<String> parts = ratio.split(':');
    if (parts.length == 2) {
      final double? width = double.tryParse(parts[0]);
      final double? height = double.tryParse(parts[1]);
      if (width != null && height != null && height != 0) {
        return Size(width, height);
      }
    }
    return const Size(1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Image'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isCropping
                ? null
                : () {
                    if (_rect != null) {
                      _cropController.cropRect = Rect.fromLTRB(
                        math.max(0, _rect!.left),
                        math.max(0, _rect!.top),
                        _rect!.right,
                        _rect!.bottom,
                      );
                    }
                    setState(() {
                      _isCropping = true;
                    });
                    _cropController.crop();
                  },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Column(
            children: <Widget>[
              Expanded(
                child: Crop(
                  onMoved: (Rect rect, _) {
                    _rect = rect;
                  },
                  baseColor: Colors.black,
                  aspectRatio: _parseAspectRatio(_selectedAspectRatio),
                  image: widget.image,
                  controller: _cropController,
                  onCropped: (CropResult cropResult) {
                    if (cropResult is CropFailure) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(cropResult.cause.toString())),
                      );
                      return;
                    }
                    setState(() {
                      _croppedData = (cropResult as CropSuccess).croppedImage;
                      _isCropping = false;
                    });
                    Navigator.pop(
                      context,
                      CropImage(
                        bytes: _croppedData,
                        targetAspectRatio: _parseAspectRatioSize(
                          _selectedAspectRatio,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),

                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  alignment: WrapAlignment.center,
                  children: AppConstants.aspectRatioStrings.map((String ratio) {
                    return ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedAspectRatio = ratio;
                          _cropController.aspectRatio = _parseAspectRatio(
                            ratio,
                          );
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedAspectRatio == ratio
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(ratio),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          if (_isCropping)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
