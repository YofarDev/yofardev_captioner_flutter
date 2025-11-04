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
  double _quality = 90;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Convert All Images'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: _format,
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'jpg', child: Text('JPG')),
              DropdownMenuItem(value: 'png', child: Text('PNG')),
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
          if (_format == 'jpg')
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
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            context.read<ImagesCubit>().convertAllImages(
              format: _format,
              quality: _quality.round(),
            );
            Navigator.of(context).pop();
          },
          child: const Text('Convert'),
        ),
      ],
    );
  }
}
