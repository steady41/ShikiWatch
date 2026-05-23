import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../utils/extensions/buildcontext.dart';
import '../../../domain/models/pages_extra.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/nothing_found.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/error_widget.dart';

import 'titles_search_controller.dart';

final isScrollToTopVisibleProvider = StateProvider.autoDispose<bool>((ref) {
  return false;
}, name: 'isScrollToTopVisibleProvider');

class TitlesSearchPage extends HookConsumerWidget {
  const TitlesSearchPage({
    super.key,
    this.studioName,
    this.studioId,
    this.genreId,
  });

  final String? studioName;
  final int? studioId;
  final int? genreId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = SearchFiltersNotifierArgs(studio: studioId, genre: genreId);

    final filters = ref.watch(filtersProvider(args));
    final notifier = ref.read(filtersProvider(args).notifier);

    final searchTerm = useState('');
    final focusNode = useFocusNode();
    final scrollController = useScrollController();
    final cancelTokenRef = useRef<CancelToken?>(null);
    final searchController = useTextEditingController();
    final pagingController = useMemoized(
      () => PagingController<int, TitleSearchItem>(firstPageKey: 1),
    );

    // scrollController listener
    useEffect(() {
      void listener() {
        final current = scrollController.offset;
        final isScrolling = current > 256;
        if (isScrolling != ref.read(isScrollToTopVisibleProvider)) {
          ref.read(isScrollToTopVisibleProvider.notifier).state = isScrolling;
        }
      }

      scrollController.addListener(listener);

      return () => scrollController.removeListener(listener);
    }, [scrollController]);

    // requestFocus
    useEffect(() {
      if (studioId == null && genreId == null) {
        Future.microtask(() {
          if (!context.mounted) return;

          focusNode.requestFocus();
        });
      }
      return null;
    }, const []);

    // cancel & dispose
    useEffect(() {
      return () {
        cancelTokenRef.value?.cancel();
        pagingController.dispose();
      };
    }, const []);

    // addPageRequestListener
    useEffect(() {
      pagingController.addPageRequestListener((pageKey) async {
        if (cancelTokenRef.value != null &&
            !cancelTokenRef.value!.isCancelled) {
          cancelTokenRef.value?.cancel();
        }

        cancelTokenRef.value = CancelToken();

        try {
          final currentFilters = ref.read(filtersProvider(args));
          final censored =
              ref.read(settingsProvider.select((v) => v.shikiAllowExpContent));

          final items = await ref.read(titlesSearchRepositoryProvider).fetch(
                filters: currentFilters,
                censored: censored,
                currentPage: pageKey,
                cancelToken: cancelTokenRef.value!,
              );

          if (!context.mounted) return;

          final isLastPage = items.length < TitlesSearchRepository.limit;
          if (isLastPage) {
            pagingController.appendLastPage(items);
          } else {
            pagingController.appendPage(items, pageKey + 1);
          }
        } catch (error) {
          if (!context.mounted) return;

          if (error is DioException && error.type == DioExceptionType.cancel) {
            return;
          }

          pagingController.error = error;
        }
      });
      return null;
    }, const []);

    // updateQuery
    useEffect(() {
      final timer = Timer(
        const Duration(milliseconds: 800),
        () {
          if ((ref.read(filtersProvider(args)).query != searchTerm.value &&
                  searchTerm.value.length > 2) ||
              (searchTerm.value.isEmpty &&
                  !ref.read(filtersProvider(args)).isInitial)) {
            ref
                .read(filtersProvider(args).notifier)
                .updateQuery(searchTerm.value);
          }
        },
      );

      return timer.cancel;
    }, [searchTerm.value]);

    void toTop({bool fast = true}) => scrollController.animateTo(
          0,
          curve: Curves.fastOutSlowIn,
          duration: Duration(milliseconds: fast ? 500 : 1000),
        );

    // void toTop() => scrollController.jumpTo(0);

    ref.listen(
      filtersProvider(args).select((state) => (
            state.query,
            state.type,
            // state.genre,
            // state.studio,
          )),
      (previous, next) {
        if (previous == null) return;

        cancelTokenRef.value?.cancel();
        pagingController.refresh();
        toTop();
      },
    );

    // final filterDebounceRef = useRef<Timer?>(null);

    // ref.listen(
    //   filtersProvider(args).select((state) => (
    //         state.order,
    //         state.minScore,
    //         state.buildApiString(state.kinds),
    //         state.buildApiString(state.statuses),
    //         state.buildApiString(state.myList),
    //       )),
    //   (previous, next) {
    //     if (previous == null) return;
    //     filterDebounceRef.value?.cancel();
    //     filterDebounceRef.value = Timer(const Duration(milliseconds: 1000), () {
    //       print('listen2 refresh pagingController');
    //       cancelTokenRef.value?.cancel();
    //       pagingController.refresh();
    //     });
    //   },
    // );

    final grid = SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: PagedSliverGrid<int, TitleSearchItem>(
        key: const PageStorageKey<String>('TitlesSearchPagePagedSliverCard'),
        addSemanticIndexes: false,
        addRepaintBoundaries: false,
        showNewPageErrorIndicatorAsGridChild: false,
        pagingController: pagingController,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140, //150
          childAspectRatio: 0.55,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        builderDelegate: PagedChildBuilderDelegate<TitleSearchItem>(
          animateTransitions: true,
          noItemsFoundIndicatorBuilder: (context) {
            return const NothingFound(
              title: 'Похоже тут пусто',
              subtitle: 'Поищи что-то другое',
            );
          },
          firstPageErrorIndicatorBuilder: (context) {
            return CustomErrorWidget(
              pagingController.error.toString(),
              () => pagingController.refresh(),
            );
          },
          newPageErrorIndicatorBuilder: (context) {
            return CustomErrorWidget(
              pagingController.error.toString(),
              () => pagingController.retryLastFailedRequest(),
            );
          },
          itemBuilder: (context, title, index) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return InkWell(
                  onTap: () {
                    final extra = TitleDetailsPageExtra(
                      id: title.id,
                      label:
                          (title.russian == '' ? title.name : title.russian) ??
                              '',
                    );

                    if (title.kind.isAnime) {
                      context.pushNamed(
                        'library_anime',
                        pathParameters: <String, String>{
                          'id': (title.id).toString(),
                        },
                        extra: extra,
                      );
                    } else {
                      context.pushNamed(
                        'library_manga',
                        pathParameters: <String, String>{
                          'id': (title.id).toString(),
                        },
                        extra: extra,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12.0),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight / 1.4,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12.0),
                              child: title.posterUrl == null
                                  ? ColoredBox(
                                      color: context
                                          .colorScheme.secondaryContainer,
                                      child: Icon(
                                        Icons.broken_image_rounded,
                                        color: context
                                            .colorScheme.onSecondaryContainer,
                                      ),
                                    )
                                  : CachedImage(
                                      title.posterUrl!,
                                    ),
                            ),
                          ),
                          // if (anime.userRate != null)
                          //   UserRateStatusIndicator(anime.userRate!.status),
                        ],
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.russian ?? title.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(
                              height: 2,
                            ),
                            Row(
                              children: [
                                Text(
                                  '${title.kind.rusName} • ${title.score}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .color,
                                  ),
                                ),
                                const Icon(
                                  Icons.star_rounded,
                                  size: 10,
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );

    const initial = SliverToBoxAdapter();

    return Scaffold(
      floatingActionButton: Consumer(
        builder: (context, ref, child) {
          final isFabVisible = ref.watch(isScrollToTopVisibleProvider);

          return AnimatedOpacity(
            opacity: isFabVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            child: child,
          );
        },
        child: FloatingActionButton(
          onPressed: () => toTop(fast: false),
          child: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          controller: scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              title: TextField(
                focusNode: focusNode,
                controller: searchController,
                onChanged: (value) => searchTerm.value = value,
                decoration: InputDecoration(
                  filled: false,
                  hintText: 'Поиск...',
                  border: InputBorder.none,
                  suffixIcon: searchTerm.value.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            searchController.clear();
                            // searchTerm.value = '';
                            ref
                                .read(filtersProvider(args).notifier)
                                .updateQuery('');
                          },
                          icon: const Icon(Icons.close),
                        )
                      : null,
                ),
              ),
              bottom: AppBar(
                automaticallyImplyLeading: false,
                primary: false,
                titleSpacing: 0,
                title: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 0,
                    children: [
                      const SizedBox(
                        width: 8.0,
                      ),
                      ...SearchContentType.values.map(
                        (type) => ChoiceChip(
                          label: Text(type.label),
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          selected: type == filters.type,
                          onSelected: (_) {
                            notifier.updateType(type);
                          },
                        ),
                      ),
                      ActionChip(
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width >= 700
                                ? 700
                                : double.infinity,
                          ),
                          useRootNavigator: true,
                          isScrollControlled: true,
                          useSafeArea: true,
                          showDragHandle: true,
                          backgroundColor: context.colorScheme.background,
                          elevation: 0,
                          builder: (context) => SafeArea(
                            bottom: false,
                            child: FilterBottomSheet(
                              args: args,
                              onReset: () {
                                cancelTokenRef.value?.cancel();
                                pagingController.refresh();
                                toTop();
                              },
                              onApply: () {
                                cancelTokenRef.value?.cancel();
                                pagingController.refresh();
                                toTop();
                              },
                            ),
                          ),
                        ),
                        avatar: Icon(
                          Icons.tune,
                          size: 16,
                          color: context.colorScheme.onSurface,
                        ),
                        label: const Text('Фильтры'),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      const SizedBox(
                        width: 8.0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            if (filters.hasInitialValues && studioName != null)
              SliverPinnedHeader(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colorScheme.surface,
                  ),
                  // padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text.rich(
                            TextSpan(
                              text: 'Аниме студии ',
                              children: [
                                TextSpan(
                                  text: studioName,
                                  style: TextStyle(
                                    color: context.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          notifier.reset();
                          pagingController.refresh();
                        },
                        child: const Text('сбросить'),
                      ),
                    ],
                  ),
                ),
              ),
            switch (filters.isInitial) {
              true => initial,
              _ => grid,
            },
            SliverPadding(
              padding: EdgeInsets.only(bottom: context.padding.bottom + 72),
            ),
          ],
        ),
      ),
    );
  }
}

class FilterBottomSheet extends HookConsumerWidget {
  const FilterBottomSheet({
    super.key,
    required this.args,
    required this.onReset,
    required this.onApply,
  });

  final SearchFiltersNotifierArgs args;
  final VoidCallback onReset;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(filtersProvider(args));
    final notifier = ref.read(filtersProvider(args).notifier);

    final Map<String, String> availableStatuses = switch (filters.type) {
      SearchContentType.anime => {
          'anons': 'Анонс',
          'ongoing': 'Онгоинг',
          'released': 'Вышло',
          'latest': 'Недавно вышедшее',
        },
      _ => {
          'anons': 'Анонс',
          'ongoing': 'Онгоинг',
          'released': 'Вышло',
          'paused': 'Приостановлено',
          'discontinued': 'Прекращенно',
        },
    };

    final Map<String, String> availableKinds = switch (filters.type) {
      SearchContentType.anime => {
          'tv': 'ТВ',
          'movie': 'Фильм',
          'ova': 'OVA',
          'ona': 'ONA',
          'special': 'Спешл'
        },
      SearchContentType.manga => {
          'manga': 'Манга',
          'manhwa': 'Манхва',
          'manhua': 'Маньхуа',
          'one_shot': 'Ваншот'
        },
      _ => {},
    };

    final Map<String, String> myList = switch (filters.type) {
      SearchContentType.anime => {
          'planned': 'В планах',
          'watching': 'Смотрю',
          'completed': 'Просмотрено',
          'rewatching': 'Пересматриваю',
          'on_hold': 'Отложено',
          'dropped': 'Брошено'
        },
      _ => {
          'planned': 'В планах',
          'watching': 'Читаю',
          'completed': 'Прочитано',
          'rewatching': 'Перечитываю',
          'on_hold': 'Отложено',
          'dropped': 'Брошено'
        },
    };

    const orders = {
      'ranked': 'Рейтингу',
      'popularity': 'Популярности',
      'aired_on': 'Дате выхода',
      'created_at_desc': 'Дате добавления',
    };

    const minimalScore = {
      0: 'Любая',
      1: '1',
      6: '6',
      8: '8',
      9: '9',
    };

    const seasons = {
      'winter': 'Зима',
      'spring': 'Весна',
      'summer': 'Лето',
      'fall': 'Осень',
    };

    final Map<String, String> availableOrigins = switch (filters.type) {
      SearchContentType.anime => {
          'original': 'Оригинал',
          'manga': 'Манга',
          'light_novel,novel': 'Ранобе',
          'web_manga': 'Веб-манга',
          'four_koma_manga': 'Енкома',
          // 'novel': 'Новелла',
          // 'web_novel': 'Веб-новелла',
          'visual_novel': 'Визуальная новелла',
          // 'light_novel': 'Ранобе',
          'game': 'Игра',
          // 'card_game': 'Карточная игра',
          // 'music': 'Музыка',
          // 'radio': 'Радио',
          // 'book': 'Книга',
          // 'picture_book': 'Книга с картинками',
          // 'mixed_media': 'Несколько',
          // 'other': 'Прочее',
          // 'unknown': 'Неизвестен',
        },
      _ => {},
    };

    return DraggableScrollableSheet(
      expand: false,
      snap: true,
      minChildSize: 0.25,
      initialChildSize: 0.75,
      snapSizes: const [0.25, 0.75, 1.0],
      builder: (context, scrollController) {
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverPinnedHeader(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration:
                    BoxDecoration(color: context.colorScheme.background),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        notifier.reset();
                        onReset.call();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Сбросить'),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: FilledButton.icon(
                        style: ButtonStyle(
                          shape: MaterialStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        onPressed: () {
                          onApply.call();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.done_all),
                        label: const Text('Применить'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            sectionHeadingSliver(context, label: 'Категория'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PillSelector(
                  items: SearchContentType.values
                      .map((type) => type.label)
                      .toList(),
                  onTap: (index) {
                    notifier.updateType(SearchContentType.values[index]);
                  },
                  selected: filters.type.index,
                ),
              ),
            ),
            sectionHeadingSliver(context, label: 'Сортировать по'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: orders.entries.map((e) {
                    final isSelected = filters.order == e.key;
                    return TriStateChip(
                      label: e.value,
                      state: isSelected
                          ? SearchFilterState.include
                          : SearchFilterState.none,
                      onTap: () => notifier.setOrder(e.key),
                    );
                  }).toList(),
                ),
              ),
            ),
            sectionHeadingSliver(context, label: 'Статус'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableStatuses.entries.map((e) {
                    final state =
                        filters.statuses[e.key] ?? SearchFilterState.none;
                    return TriStateChip(
                      label: e.value,
                      state: state,
                      onTap: () => notifier.toggleStatus(e.key),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (availableKinds.isNotEmpty) ...[
              sectionHeadingSliver(context, label: 'Формат'),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableKinds.entries.map((e) {
                      final state =
                          filters.kinds[e.key] ?? SearchFilterState.none;
                      return TriStateChip(
                        label: e.value,
                        state: state,
                        onTap: () => notifier.toggleKind(e.key),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            if (availableOrigins.isNotEmpty) ...[
              sectionHeadingSliver(context, label: 'Первоисточник'),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableOrigins.entries.map((e) {
                      final state =
                          filters.origins[e.key] ?? SearchFilterState.none;
                      return TriStateChip(
                        label: e.value,
                        state: state,
                        onTap: () => notifier.toggleOrigin(e.key),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            sectionHeadingSliver(context, label: 'В моём списке'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: myList.entries.map((e) {
                    final state =
                        filters.myList[e.key] ?? SearchFilterState.none;
                    return TriStateChip(
                      label: e.value,
                      state: state,
                      onTap: () => notifier.toggleMyList(e.key),
                      // onLongPress: () => notifier.toggleMyList2(
                      //   e.key,
                      //   exclude: true,
                      // ),
                    );
                  }).toList(),
                ),
              ),
            ),

            sectionHeadingSliver(context, label: 'Минимальная оценка'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: minimalScore.entries.map((e) {
                    final isSelected = filters.minScore == e.key;
                    return TriStateChip(
                      label: e.value,
                      state: isSelected
                          ? SearchFilterState.include
                          : SearchFilterState.none,
                      onTap: () => notifier.updateMinScore(e.key),
                    );
                  }).toList(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Card(
                margin: const EdgeInsets.all(16),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: context.theme.copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: sectionHeading(context, label: 'Сезон и год'),
                    children: [
                      if (filters.type == SearchContentType.anime) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Сезон',
                            style: TextStyle(
                              color: context.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Wrap(
                              spacing: 8,
                              children: seasons.entries.map((e) {
                                return TriStateChip(
                                  label: e.value,
                                  state: filters.seasons[e.key] ??
                                      SearchFilterState.none,
                                  onTap: () => notifier.toggleSeason(e.key),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Год',
                          style: TextStyle(
                            color: context.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(18, (index) {
                            final currentYear = DateTime.now().year;
                            final yearStr =
                                ((currentYear + 1) - index).toString();

                            return TriStateChip(
                              label: yearStr,
                              state: filters.seasons[yearStr] ??
                                  SearchFilterState.none,
                              onTap: () => notifier.toggleSeason(yearStr),
                            );
                          }).toList()
                            ..addAll(
                              [
                                TriStateChip(
                                  label: '2000-е',
                                  state: filters.seasons['2000_2009'] ??
                                      SearchFilterState.none,
                                  onTap: () =>
                                      notifier.toggleSeason('2000_2009'),
                                ),
                                TriStateChip(
                                  label: '1990-е',
                                  state: filters.seasons['1990_1999'] ??
                                      SearchFilterState.none,
                                  onTap: () =>
                                      notifier.toggleSeason('1990_1999'),
                                ),
                              ],
                            ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                    ],
                  ),
                ),
              ),
            ),
            // ----------------
            // SliverToBoxAdapter(
            //   child: Theme(
            //     data: context.theme.copyWith(dividerColor: Colors.transparent),
            //     child: ExpansionTile(
            //       // tilePadding: EdgeInsets.zero,
            //       // childrenPadding: EdgeInsets.zero,
            //       childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
            //       title: sectionHeading(
            //         context,
            //         label: 'Жанры',
            //       ),
            //       subtitle: Text(
            //         'Выбрано: 2',
            //         style: TextStyle(
            //           color: context.colorScheme.secondary,
            //         ),
            //       ),
            //       children: [
            //         Wrap(
            //           spacing: 8,
            //           runSpacing: 8,
            //           children: animeGenres.map(
            //             (e) {
            //               final isSelected = e.id == 6;

            //               return TriStateChip(
            //                 label: e.russian,
            //                 state: isSelected
            //                     ? SearchFilterState.include
            //                     : SearchFilterState.none,
            //                 onTap: () {},
            //               );
            //             },
            //           ).toList(),
            //         ),
            //         const SizedBox(height: 16.0),
            //       ],
            //     ),
            //   ),
            // ),
            SliverPadding(
              padding: EdgeInsets.only(top: 0, bottom: context.padding.bottom),
            ),
          ],
        );

        return SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: context.padding.bottom,
          ),
          child: Padding(
            // padding: EdgeInsets.only(
            //   left: 16,
            //   right: 16,
            //   bottom: context.padding.bottom,
            // ),
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // sectionHeading(
                //   context,
                //   label: 'Категория',
                // ),
                // const SizedBox(height: 8),
                // Row(
                //   children: [
                //     const Spacer(),
                //     SegmentedButton<SearchContentType>(
                //       segments: const [
                //         ButtonSegment(
                //           value: SearchContentType.anime,
                //           label: Text('Аниме'),
                //         ),
                //         ButtonSegment(
                //           value: SearchContentType.manga,
                //           label: Text('Манга'),
                //         ),
                //         ButtonSegment(
                //           value: SearchContentType.ranobe,
                //           label: Text('Ранобе'),
                //         ),
                //       ],
                //       selected: {filters.type},
                //       onSelectionChanged: (newSelection) =>
                //           notifier.updateType(newSelection.first),
                //     ),
                //     const Spacer(),
                //   ],
                // ),
                // const SizedBox(height: 16),
                sectionHeading(
                  context,
                  label: 'Статус',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableStatuses.entries.map((e) {
                    final state =
                        filters.statuses[e.key] ?? SearchFilterState.none;
                    return TriStateChip(
                      label: e.value,
                      state: state,
                      onTap: () => notifier.toggleStatus(e.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (availableKinds.isNotEmpty) ...[
                  sectionHeading(
                    context,
                    label: 'Формат',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableKinds.entries.map((e) {
                      final state =
                          filters.kinds[e.key] ?? SearchFilterState.none;
                      return TriStateChip(
                        label: e.value,
                        state: state,
                        onTap: () => notifier.toggleKind(e.key),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                sectionHeading(
                  context,
                  label: 'В моём списке',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: myList.entries.map((e) {
                    final state =
                        filters.myList[e.key] ?? SearchFilterState.none;
                    return TriStateChip(
                      label: e.value,
                      state: state,
                      onTap: () => notifier.toggleMyList(e.key),
                      // onLongPress: () => notifier.toggleMyList(
                      //   e.key,
                      //   exclude: true,
                      // ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                sectionHeading(
                  context,
                  label: 'Сортировать по',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: orders.entries.map((e) {
                    final isSelected = filters.order == e.key;
                    return TriStateChip(
                      label: e.value,
                      state: isSelected
                          ? SearchFilterState.include
                          : SearchFilterState.none,
                      onTap: () => notifier.setOrder(e.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Text(
                //     'Минимальная оценка: ${filters.minScore == 0 ? "Любая" : filters.minScore}',
                //     style: const TextStyle(
                //         fontSize: 18, fontWeight: FontWeight.bold)),
                // Slider(
                //   value: filters.minScore.toDouble(),
                //   min: 0,
                //   max: 9,
                //   divisions: 9,
                //   label: filters.minScore.toString(),
                //   onChanged: (value) => notifier.updateMinScore(value.toInt()),
                // ),
                // const SizedBox(height: 16),

                // minimalScore
                sectionHeading(
                  context,
                  label: 'Минимальная оценка',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: minimalScore.entries.map((e) {
                    final isSelected = filters.minScore == e.key;
                    return TriStateChip(
                      label: e.value,
                      state: isSelected
                          ? SearchFilterState.include
                          : SearchFilterState.none,
                      onTap: () => notifier.updateMinScore(e.key),
                    );
                  }).toList(),
                ),
                // const SizedBox(height: 16),
                const SizedBox(width: double.infinity),

                // Container(
                //   decoration: const BoxDecoration(
                //     color: Colors.red,
                //   ),
                //   child: Row(
                //     children: [
                //       FilledButton.tonalIcon(
                //         onPressed: () => notifier.reset(),
                //         icon: const Icon(Icons.refresh),
                //         label: const Text('Сбросить'),
                //       ),
                //       const SizedBox(width: 8.0),
                //       Expanded(
                //         child: FilledButton.icon(
                //           onPressed: () {},
                //           icon: const Icon(Icons.done_all),
                //           label: const Text('Применить'),
                //         ),
                //       ),
                //     ],
                //   ),
                // ),

                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          notifier.reset();
                          onReset.call();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Сбросить'),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            onApply.call();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.done_all),
                          label: const Text('Применить'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget sectionHeading(BuildContext context, {required String label}) => Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
      );

  Widget sectionHeadingSliver(BuildContext context, {required String label}) =>
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: context.colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );

  Widget sectionHeadingSliverOld(BuildContext context,
          {required String label}) =>
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      );
}

class PillSelector extends StatelessWidget {
  const PillSelector({
    super.key,
    this.selected,
    required this.items,
    required this.onTap,
  });

  final int? selected;
  final List<String> items;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        items.length,
        (index) {
          final color = index == selected
              ? context.colorScheme.secondaryContainer
              : context.colorScheme.onSurface.withOpacity(0.12);

          final textColor = index == selected
              ? context.colorScheme.onSecondaryContainer
              : context.colorScheme.onSurface;

          final borderRadius = index == selected ? 12.0 : 32.0;

          const padding = 3.0;

          final child = Text(
            items[index],
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          );

          return Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                (index == 0) ? 0 : padding,
                0,
                (index == items.length - 1) ? 0 : padding,
                0,
              ),
              child: Material(
                elevation: 1,
                color: color,
                clipBehavior: Clip.antiAlias,
                shadowColor: Colors.transparent,
                surfaceTintColor: context.colorScheme.surfaceTint,
                borderRadius: BorderRadius.circular(borderRadius),
                child: InkWell(
                  onTap: () => onTap(index),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TriStateChip extends StatelessWidget {
  const TriStateChip({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final SearchFilterState state;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    IconData? icon;

    switch (state) {
      case SearchFilterState.include:
        bgColor = context.colorScheme.secondaryContainer;
        textColor = context.colorScheme.onSecondaryContainer;
        icon = Icons.check;
        break;
      case SearchFilterState.exclude:
        bgColor = context.colorScheme.error.withOpacity(0.2);
        textColor = context.colorScheme.error;
        icon = Icons.close;
        break;
      case SearchFilterState.none:
      default:
        bgColor = context.colorScheme.onSurface.withOpacity(0.12);
        textColor = context.colorScheme.onSurface;
        icon = null;
        break;
    }

    final iconWidget = AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: Curves.fastOutSlowIn,
      alignment: Alignment.centerLeft,
      child: icon != null
          ? Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: Icon(
                icon,
                size: 16,
                color: textColor,
              ),
            )
          : const SizedBox.shrink(),
    );

    return Material(
      elevation: 1,
      color: bgColor,
      surfaceTintColor: context.colorScheme.surfaceTint,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          // padding: const EdgeInsets.all(40),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
