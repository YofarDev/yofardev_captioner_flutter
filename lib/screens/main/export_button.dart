import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/images/images_cubit.dart';
import '../widgets/app_button.dart';

class ExportButton extends StatelessWidget {
  const ExportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppButton(
      onTap: () {
        context.read<ImagesCubit>().exportAsArchive();
      },
      text: '💾  Export as Archive',
    );
  }
}
