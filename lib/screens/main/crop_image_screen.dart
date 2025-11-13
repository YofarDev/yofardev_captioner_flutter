import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../res/app_constants.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Image'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              setState(() {
                _isCropping = true;
              });
              _cropController.crop();
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Crop(
              aspectRatio: 1.0,
              image: widget.image,
              controller: _cropController,
              onCropped: (Uint8List croppedData) {
                setState(() {
                  _croppedData = croppedData;
                  _isCropping = false;
                });
                Navigator.pop(context, _croppedData);
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
                      _cropController.aspectRatio = _parseAspectRatio(ratio);
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
          if (_isCropping) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
