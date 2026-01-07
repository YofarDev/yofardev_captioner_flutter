import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../image_list/logic/image_list_cubit.dart';

class AspectRatioDialog extends StatelessWidget {
  const AspectRatioDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> aspectRatios = context
        .read<ImageListCubit>()
        .getAspectRatioCounts();
    final int totalCount = aspectRatios.values.fold(
      0,
      (int sum, int count) => sum + count,
    );

    final List<_RatioItem> items = aspectRatios.entries
        .map(
          (MapEntry<String, int> e) =>
              _RatioItem(ratio: e.key, count: e.value, total: totalCount),
        )
        .toList();

    // Group items
    final List<_RatioItem> landscape = <_RatioItem>[];
    final List<_RatioItem> portrait = <_RatioItem>[];
    final List<_RatioItem> square = <_RatioItem>[];
    final List<_RatioItem> others = <_RatioItem>[];

    for (final _RatioItem item in items) {
      if (item.isLandscape) {
        landscape.add(item);
      } else if (item.isPortrait) {
        portrait.add(item);
      } else if (item.isSquare) {
        square.add(item);
      } else {
        others.add(item);
      }
    }

    // Sort by count descending within groups
    void sortGroup(List<_RatioItem> group) {
      group.sort((_RatioItem a, _RatioItem b) => b.count.compareTo(a.count));
    }

    sortGroup(landscape);
    sortGroup(portrait);
    sortGroup(square);
    sortGroup(others);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          const Text('Aspect Ratio Distribution'),
          Text(
            'Total: $totalCount',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (landscape.isNotEmpty)
                _buildSection(context, 'Landscape', Icons.landscape, landscape),
              if (portrait.isNotEmpty)
                _buildSection(context, 'Portrait', Icons.portrait, portrait),
              if (square.isNotEmpty)
                _buildSection(context, 'Square', Icons.crop_square, square),
              if (others.isNotEmpty)
                _buildSection(context, 'Others', Icons.help_outline, others),
            ],
          ),
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

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<_RatioItem> items,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: items
                .map((_RatioItem item) => _buildItemCard(context, item))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, _RatioItem item) {
    // 2 columns on 600 width ~ 250ish width per card
    return SizedBox(
      width: 260,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(item.ratio, style: const TextStyle()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return Text(
                      '.' * (constraints.maxWidth ~/ 4),
                      style: TextStyle(
                        color: Theme.of(context).dividerColor,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.count}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              Text(
                "(${item.percentageString})",
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatioItem {
  final String ratio;
  final int count;
  final int total;

  _RatioItem({required this.ratio, required this.count, required this.total});

  double get percentage => total == 0 ? 0 : count / total;
  String get percentageString => '${(percentage * 100).toStringAsFixed(1)}%';

  bool get isSquare {
    final List<String> parts = ratio.split(':');
    if (parts.length != 2) return false;
    final int? w = int.tryParse(parts[0]);
    final int? h = int.tryParse(parts[1]);
    return w != null && h != null && w == h;
  }

  bool get isLandscape {
    final List<String> parts = ratio.split(':');
    if (parts.length != 2) return false;
    final int? w = int.tryParse(parts[0]);
    final int? h = int.tryParse(parts[1]);
    return w != null && h != null && w > h;
  }

  bool get isPortrait {
    final List<String> parts = ratio.split(':');
    if (parts.length != 2) return false;
    final int? w = int.tryParse(parts[0]);
    final int? h = int.tryParse(parts[1]);
    return w != null && h != null && h > w;
  }
}
