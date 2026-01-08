import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/image_list_cubit.dart';

class SortByWidget extends StatelessWidget {
  const SortByWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        return Row(
          children: <Widget>[
            const Text('Sort by:', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: DropdownButton<SortBy>(
                value: state.sortBy,
                isDense: true,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                dropdownColor: Colors.grey[850],
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
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
                    child: Text('Caption'),
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
                color: Colors.white,
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
