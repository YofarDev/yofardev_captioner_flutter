import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/images_list/image_list_cubit.dart';

class AspectRatioDialog extends StatelessWidget {
  const AspectRatioDialog({super.key});
  @override
  Widget build(BuildContext context) {
    final Map<String, int> aspectRatios = context
        .read<ImageListCubit>()
        .getAspectRatioCounts();
    return AlertDialog(
      title: const Text('Aspect Ratio Counts'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: ListView.builder(
          itemCount: aspectRatios.length,
          itemBuilder: (BuildContext context, int index) {
            final String key = aspectRatios.keys.elementAt(index);
            final int value = aspectRatios[key]!;
            return ListTile(title: Text(key), trailing: Text(value.toString()));
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
