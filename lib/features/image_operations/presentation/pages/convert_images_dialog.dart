import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/image_operations_cubit.dart';

class ConvertImagesDialog extends StatefulWidget {
  const ConvertImagesDialog({super.key});
  @override
  State<ConvertImagesDialog> createState() => _ConvertImagesDialogState();
}

class _ConvertImagesDialogState extends State<ConvertImagesDialog> {
  String _format = 'jpg';
  double _quality = 100;
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ImageOperationsCubit, ImageOperationsState>(
      listener: (BuildContext context, ImageOperationsState state) {
        if (state.status == ImageOperationsStatus.success) {
          Navigator.of(context).pop();
        }
      },
      builder: (BuildContext context, ImageOperationsState state) {
        final bool isConverting =
            state.status == ImageOperationsStatus.inProgress;
        return AlertDialog(
          title: const Text('Convert All Images'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!isConverting)
                DropdownButtonFormField<String>(
                  initialValue: _format,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(value: 'jpg', child: Text('JPG')),
                    DropdownMenuItem<String>(value: 'png', child: Text('PNG')),
                    DropdownMenuItem<String>(
                      value: 'webp',
                      child: Text('WebP'),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() {
                        _format = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Format'),
                ),
              if (!isConverting && (_format == 'jpg' || _format == 'webp'))
                Column(
                  children: <Widget>[
                    const SizedBox(height: 16),
                    Text('Quality: ${_quality.round()}'),
                    Slider(
                      value: _quality,
                      min: 1,
                      max: 100,
                      divisions: 99,
                      label: _quality.round().toString(),
                      onChanged: (double value) {
                        setState(() {
                          _quality = value;
                        });
                      },
                    ),
                  ],
                ),
              if (isConverting)
                Column(
                  children: <Widget>[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Converting... ${(state.progress * 100).toStringAsFixed(0)}%',
                    ),
                  ],
                ),
            ],
          ),
          actions: <Widget>[
            if (!isConverting)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            if (!isConverting)
              ElevatedButton(
                onPressed: () {
                  context.read<ImageOperationsCubit>().convertAllImages(
                    format: _format,
                    quality: _quality.round(),
                  );
                },
                child: const Text('Convert'),
              ),
          ],
        );
      },
    );
  }
}
