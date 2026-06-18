import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Dialog showing all available structured caption filter expressions.
///
/// Opened from the `?` button in [CaptionSearchBar].
class FilterHelpDialog extends StatelessWidget {
  const FilterHelpDialog({super.key});

  /// Shows the dialog using [showDialog].
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => const FilterHelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: darkGrey,
      title: const Text(
        'Caption Filters',
        style: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: 16,
          color: Colors.white,
        ),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 520,
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Colors.white70,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Type filter expressions with : delimiters to query structured captions. '
                  'Combine with regular text for AND filtering.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 13,
                    color: lightPink,
                  ),
                ),
                const SizedBox(height: 8),
                _buildFilterTable(),
                const SizedBox(height: 16),
                const Text(
                  'Examples',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 13,
                    color: lightPink,
                  ),
                ),
                const SizedBox(height: 8),
                _buildExample(':has:text:', 'Images with text layers'),
                _buildExample(
                  'sunset :medium:photograph:',
                  'Photographs mentioning "sunset"',
                ),
                _buildExample(
                  ':elements:>3: :has:bbox:',
                  '3+ elements with bounding boxes',
                ),
                _buildExample(
                  ':dupbbox:',
                  'Likely duplicate detections (overlapping bboxes)',
                ),
                _buildExample(
                  ':bg:forest: :element:cat:',
                  'Forest background with a cat element',
                ),
                _buildExample(':nocaption:', 'Uncaptioned images'),
                const SizedBox(height: 8),
                Text(
                  'Structured filters only match Ideogram JSON captions. '
                  'Use :plain: to find non-JSON captions.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: lightPink)),
        ),
      ],
    );
  }

  Widget _buildFilterTable() {
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FixedColumnWidth(170),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: <TableRow>[
        _filterRow(':has:text:', 'Has at least one text element'),
        _filterRow(':has:obj:', 'Has at least one object element'),
        _filterRow(':has:bbox:', 'Has elements with bounding boxes'),
        _filterRow(':dupbbox:', 'Has overlapping bboxes (IoU >= 0.7)'),
        _filterRow(':dupbbox:N:', 'Overlapping bboxes with IoU >= N (0-1)'),
        _filterRow(':elements:N:', 'Exactly N elements'),
        _filterRow(':elements:>N:', 'More than N elements'),
        _filterRow(':elements:>=N:', 'N or more elements'),
        _filterRow(':medium:value:', 'Medium equals value'),
        _filterRow(':desc:text:', 'Description contains text'),
        _filterRow(':style:text:', 'Any style field contains text'),
        _filterRow(':bg:text:', 'Background contains text'),
        _filterRow(':element:text:', 'Element desc/text contains text'),
        _filterRow(':color:#HEX:', 'Color palette contains hex color'),
        _filterRow(':structured:', 'Is Ideogram JSON'),
        _filterRow(':plain:', 'Is plain text (not JSON)'),
        _filterRow(':nocaption:', 'No caption'),
      ],
    );
  }

  TableRow _filterRow(String syntax, String description) {
    return TableRow(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            syntax,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
          child: Text(
            description,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExample(String query, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
          children: <TextSpan>[
            TextSpan(
              text: query,
              style: const TextStyle(
                color: lightPink,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: ' — $description',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
