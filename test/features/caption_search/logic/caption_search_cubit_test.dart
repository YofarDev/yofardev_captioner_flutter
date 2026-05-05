import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/features/caption_search/logic/caption_search_cubit.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';

import 'caption_search_cubit_test.mocks.dart';

@GenerateMocks(<Type>[ImageListCubit])
void main() {
  group('CaptionSearchCubit', () {
    late CaptionSearchCubit cubit;
    late MockImageListCubit mockImageListCubit;

    setUp(() {
      mockImageListCubit = MockImageListCubit();
      when(mockImageListCubit.state).thenReturn(const ImageListState());
      cubit = CaptionSearchCubit(imageListCubit: mockImageListCubit);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state has defaults', () {
      expect(cubit.state.isExpanded, false);
      expect(cubit.state.showReplaceMode, false);
      expect(cubit.state.searchQuery, '');
      expect(cubit.state.replaceText, '');
      expect(cubit.state.isCaseSensitive, false);
    });

    group('toggleExpanded', () {
      test('expands when collapsed', () {
        cubit.toggleExpanded();

        expect(cubit.state.isExpanded, true);
      });

      test('collapses and clears state when expanded', () {
        cubit.toggleExpanded(); // expand
        cubit.updateSearchQuery('test');
        cubit.toggleReplaceMode();
        cubit.updateReplaceText('new');

        cubit.toggleExpanded(); // collapse

        expect(cubit.state.isExpanded, false);
        expect(cubit.state.searchQuery, '');
        expect(cubit.state.showReplaceMode, false);
        expect(cubit.state.replaceText, '');
        verify(mockImageListCubit.clearSearch()).called(1);
      });
    });

    group('updateSearchQuery', () {
      test('updates query and delegates to ImageListCubit', () {
        cubit.toggleExpanded();
        cubit.updateSearchQuery('kitten');

        expect(cubit.state.searchQuery, 'kitten');
        verify(mockImageListCubit.updateSearchQuery('kitten')).called(1);
      });
    });

    group('toggleCaseSensitive', () {
      test('toggles and syncs from ImageListCubit state', () {
        when(
          mockImageListCubit.state,
        ).thenReturn(const ImageListState(caseSensitive: true));
        when(mockImageListCubit.toggleCaseSensitive()).thenReturn(null);

        cubit.toggleCaseSensitive();

        verify(mockImageListCubit.toggleCaseSensitive()).called(1);
        expect(cubit.state.isCaseSensitive, true);
      });
    });

    group('clearSearch', () {
      test('clears query and delegates', () {
        cubit.toggleExpanded();
        cubit.updateSearchQuery('test');

        cubit.clearSearch();

        expect(cubit.state.searchQuery, '');
        verify(mockImageListCubit.clearSearch()).called(1);
      });
    });

    group('toggleReplaceMode', () {
      test('enables replace mode', () {
        cubit.toggleReplaceMode();

        expect(cubit.state.showReplaceMode, true);
      });

      test('disables replace mode and clears replace text', () {
        cubit.toggleReplaceMode(); // enable
        cubit.updateReplaceText('new text');

        cubit.toggleReplaceMode(); // disable

        expect(cubit.state.showReplaceMode, false);
        expect(cubit.state.replaceText, '');
      });
    });

    group('updateReplaceText', () {
      test('updates replace text', () {
        cubit.updateReplaceText('replacement');

        expect(cubit.state.replaceText, 'replacement');
      });
    });

    group('executeReplace', () {
      test('does nothing when searchQuery is empty', () async {
        await cubit.executeReplace();

        verifyNever(mockImageListCubit.searchAndReplace(any, any));
      });

      test('replaces, clears search, and collapses', () async {
        cubit.toggleExpanded();
        cubit.updateSearchQuery('old');
        cubit.updateReplaceText('new');
        when(
          mockImageListCubit.state,
        ).thenReturn(const ImageListState(searchQuery: 'old'));

        await cubit.executeReplace();

        verify(mockImageListCubit.searchAndReplace('old', 'new')).called(1);
        verify(mockImageListCubit.clearSearch()).called(1);
        expect(cubit.state.isExpanded, false);
        expect(cubit.state.searchQuery, '');
      });
    });

    group('getters', () {
      test('resultCount returns filtered images length', () {
        final List<AppImage> images = <AppImage>[
          AppImage(
            id: '1',
            image: File('/a.jpg'),
            captions: const <String, CaptionEntry>{},
          ),
          AppImage(
            id: '2',
            image: File('/b.jpg'),
            captions: const <String, CaptionEntry>{},
          ),
        ];
        when(mockImageListCubit.filteredImages).thenReturn(images);

        expect(cubit.resultCount, 2);
      });

      test('totalCount returns images length from state', () {
        final List<AppImage> images = <AppImage>[
          AppImage(
            id: '1',
            image: File('/a.jpg'),
            captions: const <String, CaptionEntry>{},
          ),
          AppImage(
            id: '2',
            image: File('/b.jpg'),
            captions: const <String, CaptionEntry>{},
          ),
          AppImage(
            id: '3',
            image: File('/c.jpg'),
            captions: const <String, CaptionEntry>{},
          ),
        ];
        when(
          mockImageListCubit.state,
        ).thenReturn(ImageListState(images: images));

        expect(cubit.totalCount, 3);
      });

      test('canExecuteReplace is true when replaceText is not empty', () {
        cubit.updateReplaceText('text');

        expect(cubit.canExecuteReplace, true);
      });

      test('canExecuteReplace is false when replaceText is empty', () {
        expect(cubit.canExecuteReplace, false);
      });

      test('hasActiveSearch reflects ImageListCubit searchQuery', () {
        when(
          mockImageListCubit.state,
        ).thenReturn(const ImageListState(searchQuery: 'active'));

        expect(cubit.hasActiveSearch, true);
      });

      test('isCaseSensitive reflects state', () {
        expect(cubit.isCaseSensitive, false);
      });
    });

    group('initial state syncs caseSensitive from ImageListCubit', () {
      test('reads caseSensitive from ImageListCubit on construction', () {
        when(
          mockImageListCubit.state,
        ).thenReturn(const ImageListState(caseSensitive: true));

        final CaptionSearchCubit syncCubit = CaptionSearchCubit(
          imageListCubit: mockImageListCubit,
        );

        expect(syncCubit.state.isCaseSensitive, true);
        syncCubit.close();
      });
    });
  });
}
