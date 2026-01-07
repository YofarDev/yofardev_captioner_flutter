import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../image_list/logic/image_list_cubit.dart';
import '../../../core/widgets/app_button.dart';

class SearchAndReplaceWidget extends StatefulWidget {
  const SearchAndReplaceWidget({super.key});
  @override
  State<SearchAndReplaceWidget> createState() => _SearchAndReplaceWidgetState();
}

class _SearchAndReplaceWidgetState extends State<SearchAndReplaceWidget> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: "🔎  Search and Replace",
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return BlocProvider<ImageListCubit>.value(
              value: BlocProvider.of<ImageListCubit>(this.context),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return AlertDialog(
                    title: const Text('🔎  Search and Replace'),
                    content: BlocBuilder<ImageListCubit, ImageListState>(
                      builder: (BuildContext context, ImageListState state) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search',
                              ),
                            ),
                            TextField(
                              controller: _replaceController,
                              decoration: const InputDecoration(
                                hintText: 'Replace',
                              ),
                            ),
                            if (state.occurrencesCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      '${state.occurrencesCount} occurrences found in:',
                                    ),
                                    Text(
                                      state.occurrenceFileNames.join(', '),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          context.read<ImageListCubit>().countOccurrences('');
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text('Preview'),
                        onPressed: () {
                          context.read<ImageListCubit>().countOccurrences(
                            _searchController.text,
                          );
                        },
                      ),
                      TextButton(
                        child: const Text('Replace'),
                        onPressed: () {
                          context.read<ImageListCubit>().searchAndReplace(
                            _searchController.text,
                            _replaceController.text,
                          );
                          context.read<ImageListCubit>().countOccurrences('');
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
