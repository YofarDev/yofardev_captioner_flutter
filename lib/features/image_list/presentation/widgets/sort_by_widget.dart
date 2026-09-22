import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../logic/image_list_cubit.dart';

class SortByWidget extends StatelessWidget {
  const SortByWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        return Row(
          children: <Widget>[
            const Text('Sort by:', style: TextStyle(fontSize: 11, color: textMuted)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: panelRaised,
                borderRadius: BorderRadius.circular(radiusSm),
                border: Border.all(color: hairline),
              ),
              child: DropdownButton<SortBy>(
                value: state.sortBy,
                isDense: true,
                style: const TextStyle(
                  fontSize: 12,
                  color: textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                dropdownColor: panelRaised,
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: textSecondary,
                  size: 20,
                ),
                underline: const SizedBox.shrink(),
                items: const <DropdownMenuItem<SortBy>>[
                  DropdownMenuItem<SortBy>(
                    value: SortBy.name,
                    child: Text('Name'),
                  ),
                  DropdownMenuItem<SortBy>(
                    value: SortBy.size,
                    child: Text('Size'),
                  ),
                  DropdownMenuItem<SortBy>(
                    value: SortBy.caption,
                    child: Text('Word count'),
                  ),
                ],
                onChanged: (SortBy? value) {
                  if (value != null) {
                    context.read<ImageListCubit>().onSortChanged(
                      value,
                      state.sortAscending,
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              child: Icon(
                color: textSecondary,
                size: 16,
                state.sortAscending ? Icons.arrow_downward : Icons.arrow_upward,
              ),
              onTap: () {
                context.read<ImageListCubit>().onSortChanged(
                  state.sortBy,
                  !state.sortAscending,
                );
              },
            ),
          ],
        );
      },
    );
  }
}
