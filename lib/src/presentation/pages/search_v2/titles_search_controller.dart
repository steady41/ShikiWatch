import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';

import '../../../domain/enums/shiki_gql.dart';
import '../../../domain/models/graphql_user_rate.dart';
import '../../../services/secure_storage/secure_storage_service.dart';
import '../../../services/http/http_service_provider.dart';
import '../../../data/repositories/http_service.dart';

enum SearchContentType {
  anime,
  manga,
  ranobe;

  String get label {
    return switch (this) {
      SearchContentType.anime => 'Аниме',
      SearchContentType.manga => 'Манга',
      SearchContentType.ranobe => 'Ранобе',
    };
  }
}

enum SearchFilterState { none, include, exclude }

class SearchFilters extends Equatable {
  final String query;
  final SearchContentType type;
  final bool isInitial;
  final bool hasInitialValues;
  final String order;
  final int minScore;
  final Map<String, SearchFilterState> kinds;
  final Map<String, SearchFilterState> statuses;
  final Map<String, SearchFilterState> myList;
  final Map<String, SearchFilterState> origins;
  final Map<String, SearchFilterState> seasons;
  final int studio;
  final int genre;

  const SearchFilters({
    this.query = '',
    this.type = SearchContentType.anime,
    this.isInitial = true,
    this.hasInitialValues = false,
    this.order = 'ranked',
    this.minScore = 0,
    this.kinds = const {},
    this.statuses = const {},
    this.myList = const {},
    this.origins = const {},
    this.seasons = const {},
    this.studio = 0,
    this.genre = 0,
  });

  @override
  List<Object> get props => [
        query,
        type,
        isInitial,
        hasInitialValues,
        order,
        minScore,
        kinds,
        statuses,
        myList,
        origins,
        seasons,
        studio,
        genre,
      ];

  SearchFilters copyWith({
    String? query,
    SearchContentType? type,
    bool? hasInitialValues,
    String? order,
    int? minScore,
    Map<String, SearchFilterState>? kinds,
    Map<String, SearchFilterState>? statuses,
    Map<String, SearchFilterState>? myList,
    Map<String, SearchFilterState>? origins,
    Map<String, SearchFilterState>? seasons,
    int? studio,
    int? genre,
  }) {
    return SearchFilters(
      query: query ?? this.query,
      type: type ?? this.type,
      order: order ?? this.order,
      isInitial: false,
      hasInitialValues: hasInitialValues ?? this.hasInitialValues,
      minScore: minScore ?? this.minScore,
      kinds: kinds ?? this.kinds,
      statuses: statuses ?? this.statuses,
      myList: myList ?? this.myList,
      origins: origins ?? this.origins,
      seasons: seasons ?? this.seasons,
      studio: studio ?? this.studio,
      genre: genre ?? this.genre,
    );
  }

  String buildApiString(Map<String, SearchFilterState> map) {
    List<String> parts = [];
    map.forEach((key, state) {
      if (state == SearchFilterState.include) parts.add(key);
      if (state == SearchFilterState.exclude) parts.add('!$key');
    });
    return parts.join(',');
  }

  String buildSeasonApiString() {
    final List<String> selectedYears = [];
    final List<String> excludedYears = [];
    final List<String> selectedSeasons = [];
    final List<String> excludedSeasons = [];

    seasons.forEach((key, state) {
      final isSeason = ['winter', 'spring', 'summer', 'fall'].contains(key);
      if (state == SearchFilterState.include) {
        isSeason ? selectedSeasons.add(key) : selectedYears.add(key);
      } else if (state == SearchFilterState.exclude) {
        isSeason ? excludedSeasons.add(key) : excludedYears.add(key);
      }
    });

    if (selectedSeasons.isEmpty && excludedSeasons.isEmpty) {
      return [
        ...selectedYears,
        ...excludedYears.map((y) => '!$y'),
      ].join(',');
    }

    final targetYears = selectedYears.isNotEmpty
        ? selectedYears
        : [DateTime.now().year.toString()];

    final List<String> result = [];

    result.addAll(excludedYears.map((y) => '!$y'));

    if (selectedSeasons.isNotEmpty) {
      for (final year in targetYears) {
        if (year.contains('_')) {
          result.add(year);
        } else {
          for (final season in selectedSeasons) {
            result.add('${season}_$year');
          }
        }
      }
    } else {
      result.addAll(targetYears);
    }

    for (final year in targetYears) {
      if (!year.contains('_')) {
        for (final season in excludedSeasons) {
          result.add('!${season}_$year');
        }
      }
    }

    return result.join(',');
  }
}

class SearchFiltersNotifierArgs extends Equatable {
  final int? studio;
  final int? genre;

  const SearchFiltersNotifierArgs({this.studio, this.genre});

  @override
  List<Object?> get props => [studio, genre];
}

class SearchFiltersNotifier extends StateNotifier<SearchFilters> {
  SearchFiltersNotifier(super.initialState);

  void updateQuery(String query) => state = state.copyWith(query: query);

  void updateType(SearchContentType type) {
    if (state.type == type) return;
    state = state.copyWith(
      type: type,
      kinds: {},
      statuses: {},
      origins: {},
      seasons: {},
      studio: 0,
      genre: 0,
      hasInitialValues: false,
    );
  }

  void setOrder(String newOrder) {
    if (state.order == newOrder) return;
    state = state.copyWith(order: newOrder);
  }

  // void updateMinScore(int score) => state = state.copyWith(minScore: score);
  void updateMinScore(int score) {
    if (state.minScore == score) return;
    state = state.copyWith(minScore: score);
  }

  void toggleStatus(String status) {
    final newValue = Map<String, SearchFilterState>.from(state.statuses);
    newValue[status] = _nextState(newValue[status]);
    state = state.copyWith(statuses: newValue);
  }

  void toggleKind(String kind) {
    final newValue = Map<String, SearchFilterState>.from(state.kinds);
    newValue[kind] = _nextState(newValue[kind]);
    state = state.copyWith(kinds: newValue);
  }

  void toggleMyList(String list) {
    final newValue = Map<String, SearchFilterState>.from(state.myList);
    newValue[list] = _nextState(newValue[list]);
    state = state.copyWith(myList: newValue);
  }

  // void toggleMyList2(String list, {bool exclude = false}) {
  //   final newValue = Map<String, SearchFilterState>.from(state.myList);
  //   newValue[list] = _nextStateManual(newValue[list], exclude);
  //   state = state.copyWith(myList: newValue);
  // }

  void toggleOrigin(
    String origin, {
    bool reset = false,
  }) {
    if (reset) {
      state = state.copyWith(origins: {});

      return;
    }

    final newValue = Map<String, SearchFilterState>.from(state.origins);
    newValue[origin] = _nextState(newValue[origin]);
    newValue.removeWhere((key, value) => value == SearchFilterState.none);
    state = state.copyWith(origins: newValue);
  }

  void toggleSeason(String seasonStr) {
    final newValue = Map<String, SearchFilterState>.from(state.seasons);
    newValue[seasonStr] = _nextState(newValue[seasonStr]);
    newValue.removeWhere((key, value) => value == SearchFilterState.none);
    state = state.copyWith(seasons: newValue);
  }

  void reset() {
    state = const SearchFilters().copyWith(
      query: state.query,
      type: state.type,
    );
  }

  SearchFilterState _nextState(SearchFilterState? current) {
    if (current == null || current == SearchFilterState.none) {
      return SearchFilterState.include;
    }

    if (current == SearchFilterState.include) {
      return SearchFilterState.exclude;
    }

    return SearchFilterState.none;
  }

  // SearchFilterState _nextStateManual(SearchFilterState? current, bool exclude) {
  //   if (current == SearchFilterState.include && exclude) {
  //     return SearchFilterState.exclude;
  //   }

  //   if (current == SearchFilterState.exclude && exclude) {
  //     return SearchFilterState.include;
  //   }

  //   if (current == null || current == SearchFilterState.none) {
  //     return exclude ? SearchFilterState.exclude : SearchFilterState.include;
  //   }

  //   return SearchFilterState.none;
  // }
}

final filtersProvider = StateNotifierProvider.autoDispose
    .family<SearchFiltersNotifier, SearchFilters, SearchFiltersNotifierArgs>(
        (ref, args) {
  final initialState = SearchFilters(
    studio: args.studio ?? 0,
    genre: args.genre ?? 0,
    isInitial: args.studio == null && args.genre == null,
    hasInitialValues: args.studio != null || args.genre != null,
  );

  return SearchFiltersNotifier(initialState);
});

//------------------------------------------------------------------------

class TitleSearchItem {
  final int id;
  final String name;
  final String? russian;
  final double score;

  final String? posterUrl;

  final TitleKind kind;
  final GraphqlUserRate? userRate;

  TitleSearchItem({
    required this.id,
    required this.name,
    required this.russian,
    required this.score,
    required this.posterUrl,
    required this.kind,
    required this.userRate,
  });

  factory TitleSearchItem.fromJson(Map<String, dynamic> json) {
    return TitleSearchItem(
      id: int.parse(json["id"]),
      name: json['name'],
      russian: json['russian'],
      score: json['score'] ?? 0.0,
      posterUrl: json['poster']?['mainUrl'], // mainAltUrl
      kind: TitleKind.fromValue(json['kind'] ?? 'unknown'),
      userRate: json["userRate"] == null
          ? null
          : GraphqlUserRate.fromJson(json["userRate"]),
    );
  }
}

final titlesSearchRepositoryProvider = Provider.autoDispose((ref) {
  final client = ref.watch(httpServiceProvider);

  return TitlesSearchRepository(
    client: client,
  );
}, name: 'titlesSearchRepositoryProvider');

class TitlesSearchRepository {
  static const int limit = 30;

  final HttpService client;

  TitlesSearchRepository({
    required this.client,
  });

  Future<List<TitleSearchItem>> fetch({
    required SearchFilters filters,
    required bool censored,
    required int currentPage,
    required CancelToken cancelToken,
  }) async {
    String rootField = 'animes';

    String kindStr = filters.buildApiString(filters.kinds);
    String statusStr = filters.buildApiString(filters.statuses);
    String myListStr = filters.buildApiString(filters.myList);
    String originStr = filters.buildApiString(filters.origins);
    String seasonStr = filters.buildSeasonApiString();

    String kindArgumentType = 'AnimeKindString';
    String statusArgumentType = 'AnimeStatusString';

    String studioArgument = 'studio';

    /// Anime: 12 33 34
    /// Manga: 602 65 75
    List<int> genresExclude = [];

    List<int> genresInclude = [];

    if (filters.genre != 0) {
      genresInclude.add(filters.genre);
    }

    String originQueryPart = '\$origin: OriginString,';
    String originQueryPart2 = 'origin: \$origin,';

    switch (filters.type) {
      case SearchContentType.anime:
        rootField = 'animes';
        genresExclude.addAll([12, 33, 34]);
        break;
      case SearchContentType.manga:
        rootField = 'mangas';
        if (kindStr.isEmpty) kindStr = 'manga,manhwa,manhua,one_shot,doujin';
        kindArgumentType = 'MangaKindString';
        statusArgumentType = 'MangaStatusString';
        studioArgument = 'publisher';
        originQueryPart = '';
        originQueryPart2 = '';
        genresExclude.addAll([602, 65, 75]);
        break;
      case SearchContentType.ranobe:
        rootField = 'mangas';
        kindStr = 'light_novel,novel';
        kindArgumentType = 'MangaKindString';
        statusArgumentType = 'MangaStatusString';
        studioArgument = 'publisher';
        originQueryPart = '';
        originQueryPart2 = '';
        genresExclude.addAll([602, 65, 75]);
        break;
    }

    final String genres = [
      ...genresExclude.map((e) => '!$e'),
      ...genresInclude.map((e) => '$e')
    ].join(',');

    final query = '''
    query(\$search: String, \$score: Int, $originQueryPart \$kind: $kindArgumentType, \$status: $statusArgumentType, \$season: SeasonString, \$mylist: MylistString, \$studio: String, \$genre: String, \$censored: Boolean, \$page: PositiveInt) {
      $rootField(order: ${filters.order}, $originQueryPart2 search: \$search, score: \$score, kind: \$kind, status: \$status, season: \$season, mylist: \$mylist, page: \$page, $studioArgument: \$studio, genre: \$genre, censored: \$censored, limit: 30) {
        id
        name
        russian
        score
        poster { mainUrl }
        kind
        userRate {
          id
          status
          episodes
          score
        }
      }
    }
  ''';

    final Map<String, dynamic> response = await client.post(
      'graphql',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${SecureStorageService.instance.token}',
        },
      ),
      data: json.encode(
        {
          'query': query,
          'variables': {
            if (originStr.isNotEmpty) 'origin': originStr,
            if (filters.query.isNotEmpty) 'search': filters.query,
            if (filters.minScore > 0) 'score': filters.minScore,
            if (kindStr.isNotEmpty) 'kind': kindStr,
            if (statusStr.isNotEmpty) 'status': statusStr,
            if (seasonStr.isNotEmpty) 'season': seasonStr,
            if (myListStr.isNotEmpty) 'mylist': myListStr,
            if (filters.studio != 0) 'studio': filters.studio.toString(),
            'genre': genres,
            'censored': !censored,
            'page': currentPage,
          }
        },
      ),
      cancelToken: cancelToken,
    );

    if (response['errors'] != null) {
      final error = (response['errors'] as List<dynamic>).first['message'];

      throw Exception(
        'GraphQL Error: $error',
      );
    }

    final List data = response['data'][rootField] ?? [];

    return data.map((e) => TitleSearchItem.fromJson(e)).toList();
  }
}
