import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../image_operations/logic/image_operations_cubit.dart';

class ExportButton extends StatelessWidget {
  const ExportButton({super.key});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Export images and captions as zip file',
      child: AppButton(
        onTap: () {
          context.read<ImageOperationsCubit>().exportAsArchive();
        },
        text: 'Export as Archive',
        iconAssetPath: 'assets/icons/archive.png',
      ),
    );
  }
}
