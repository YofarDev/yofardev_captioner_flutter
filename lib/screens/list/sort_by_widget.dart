import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/images_cubit.dart';

class SortByWidget extends StatelessWidget {
  const SortByWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImagesCubit, ImagesState>(
      builder: (BuildContext context, ImagesState state) {
        return Row(
          children: <Widget>[
            const Text('Sort by:', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            DropdownButton<SortBy>(
              value: state.sortBy,
              style: const TextStyle(fontSize: 12),
              dropdownColor: Colors.black87,
              items: const <DropdownMenuItem<SortBy>>[
                DropdownMenuItem<SortBy>(
                  value: SortBy.name,
                  child: Text('Name'),
                ),
                DropdownMenuItem<SortBy>(
                  value: SortBy.size,
                  child: Text('Size'),
                ),
              ],
              onChanged: (SortBy? value) {
                if (value != null) {
                  context.read<ImagesCubit>().onSortChanged(
                    value,
                    state.sortAscending,
                  );
                }
              },
            ),
            IconButton(
              icon: Icon(
                color: Colors.white,
                size: 16,
                state.sortAscending ? Icons.arrow_downward : Icons.arrow_upward,
              ),
              onPressed: () {
                context.read<ImagesCubit>().onSortChanged(
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
