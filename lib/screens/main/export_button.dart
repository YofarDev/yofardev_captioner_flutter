import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/image_operations/logic/image_operations_cubit.dart';
import '../../core/widgets/app_button.dart';

class ExportButton extends StatelessWidget {
  const ExportButton({super.key});
  @override
  Widget build(BuildContext context) {
    return AppButton(
      onTap: () {
        context.read<ImageOperationsCubit>().exportAsArchive();
      },
      text: '💾  Export as Archive',
    );
  }
}
