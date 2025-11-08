import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/images/images_cubit.dart';

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
    return BlocConsumer<ImagesCubit, ImagesState>(
      listener: (BuildContext context, ImagesState state) {},
      builder: (BuildContext context, ImagesState state) {
        return AlertDialog(
          title: const Text('Convert All Images'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!state.isConverting)
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
              if (!state.isConverting &&
                  (_format == 'jpg' || _format == 'webp'))
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
              if (state.isConverting)
                const Column(
                  children: <Widget>[
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Converting...'),
                  ],
                ),
            ],
          ),
          actions: <Widget>[
            if (!state.isConverting)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            if (!state.isConverting)
              ElevatedButton(
                onPressed: () {
                  context.read<ImagesCubit>().convertAllImages(
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
