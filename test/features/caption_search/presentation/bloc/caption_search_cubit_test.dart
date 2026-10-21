import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/features/caption_search/presentation/bloc/caption_search_cubit.dart';
import 'package:yofardev_captioner/features/caption_session/caption_session.dart';

import 'caption_search_cubit_test.mocks.dart';

@GenerateMocks(<Type>[CaptionSessionService])
void main() {
  group('CaptionSearchCubit', () {
    late CaptionSearchCubit cubit;
    late MockCaptionSessionService mockSession;

    setUp(() {
      mockSession = MockCaptionSessionService();
      when(mockSession.state).thenReturn(const ImageListState());
      cubit = CaptionSearchCubit(session: mockSession);
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
        verify(mockSession.clearSearch()).called(1);
      });
    });

    group('updateSearchQuery', () {
      test('updates query and delegates to CaptionSessionService', () {
        cubit.toggleExpanded();
        cubit.updateSearchQuery('kitten');

        expect(cubit.state.searchQuery, 'kitten');
        verify(mockSession.updateSearchQuery('kitten')).called(1);
      });
    });

    group('toggleCaseSensitive', () {
      test('toggles and syncs from session state', () {
        when(
          mockSession.state,
        ).thenReturn(const ImageListState(caseSensitive: true));
        when(mockSession.toggleCaseSensitive()).thenReturn(null);

        cubit.toggleCaseSensitive();

        verify(mockSession.toggleCaseSensitive()).called(1);
        expect(cubit.state.isCaseSensitive, true);
      });
    });

    group('clearSearch', () {
      test('clears query and delegates', () {
        cubit.toggleExpanded();
        cubit.updateSearchQuery('test');

        cubit.clearSearch();

        expect(cubit.state.searchQuery, '');
        verify(mockSession.clearSearch()).called(1);
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

        verifyNever(mockSession.searchAndReplace(any, any));
      });

      test('replaces, clears search, and collapses', () async {
        cubit.toggleExpanded();
        cubit.updateSearchQuery('old');
        cubit.updateReplaceText('new');
        when(
          mockSession.state,
        ).thenReturn(const ImageListState(searchQuery: 'old'));

        await cubit.executeReplace();

        verify(mockSession.searchAndReplace('old', 'new')).called(1);
        verify(mockSession.clearSearch()).called(1);
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
        when(mockSession.current).thenReturn(
          CaptionSessionSnapshot(
            state: const ImageListState(),
            filteredImages: images,
            displayedImages: images,
            currentDisplayedImage: null,
          ),
        );

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
        when(mockSession.state).thenReturn(ImageListState(images: images));

        expect(cubit.totalCount, 3);
      });

      test('canExecuteReplace is true when replaceText is not empty', () {
        cubit.updateReplaceText('text');

        expect(cubit.canExecuteReplace, true);
      });

      test('canExecuteReplace is false when replaceText is empty', () {
        expect(cubit.canExecuteReplace, false);
      });

      test('hasActiveSearch reflects session searchQuery', () {
        when(
          mockSession.state,
        ).thenReturn(const ImageListState(searchQuery: 'active'));

        expect(cubit.hasActiveSearch, true);
      });

      test('isCaseSensitive reflects state', () {
        expect(cubit.isCaseSensitive, false);
      });
    });

    group('initial state syncs caseSensitive from session', () {
      test('reads caseSensitive from session on construction', () {
        when(
          mockSession.state,
        ).thenReturn(const ImageListState(caseSensitive: true));

        final CaptionSearchCubit syncCubit = CaptionSearchCubit(
          session: mockSession,
        );

        expect(syncCubit.state.isCaseSensitive, true);
        syncCubit.close();
      });
    });
  });
}
