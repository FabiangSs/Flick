import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import '../data/repositories/song_repository.dart';

/// Provider for the SongRepository.
final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository();
});

/// Sort options for the song list.
enum SongSortOption { albumArtist, title, artist, dateAdded, fileType, folder }

/// A group of songs within the same folder.
class FolderGroup {
  final String name;
  final String key;
  final String? folderUri;
  final List<Song> songs;

  const FolderGroup({
    required this.name,
    required this.key,
    this.folderUri,
    required this.songs,
  });
}

/// Filter options for file types.
enum SongFileTypeFilter { all, flac, mp3, wav, aac, ogg, alac }

extension SongFileTypeFilterExtension on SongFileTypeFilter {
  String get displayName {
    switch (this) {
      case SongFileTypeFilter.all:
        return 'All Formats';
      case SongFileTypeFilter.flac:
        return 'FLAC';
      case SongFileTypeFilter.mp3:
        return 'MP3';
      case SongFileTypeFilter.wav:
        return 'WAV';
      case SongFileTypeFilter.aac:
        return 'AAC';
      case SongFileTypeFilter.ogg:
        return 'OGG';
      case SongFileTypeFilter.alac:
        return 'ALAC';
    }
  }

  bool matches(String fileType) {
    if (this == SongFileTypeFilter.all) return true;

    // Normalize file type for comparison (remove dots, convert to uppercase)
    final normalized = fileType.replaceAll('.', '').toUpperCase().trim();
    final filterName = displayName.toUpperCase();

    // Direct match
    if (normalized == filterName) return true;

    // Handle common variations
    switch (this) {
      case SongFileTypeFilter.mp3:
        return normalized == 'MP3' || normalized == 'MPEG';
      case SongFileTypeFilter.aac:
        return normalized == 'AAC' ||
            normalized == 'M4A' ||
            normalized == 'MP4';
      case SongFileTypeFilter.ogg:
        return normalized == 'OGG' ||
            normalized == 'OGX' ||
            normalized == 'OPUS' ||
            normalized == 'VORBIS' ||
            normalized == 'OGA';
      case SongFileTypeFilter.alac:
        return normalized == 'ALAC' || normalized == 'M4A';
      case SongFileTypeFilter.wav:
        return normalized == 'WAV' || normalized == 'WAVE';
      case SongFileTypeFilter.flac:
        return normalized == 'FLAC';
      case SongFileTypeFilter.all:
        return true;
    }
  }
}

/// State for the songs list with sorting.
class SongsState {
  final List<Song> songs;
  final SongSortOption sortOption;
  final SongFileTypeFilter fileTypeFilter;

  const SongsState({
    this.songs = const [],
    this.sortOption = SongSortOption.albumArtist,
    this.fileTypeFilter = SongFileTypeFilter.all,
  });

  SongsState copyWith({
    List<Song>? songs,
    SongSortOption? sortOption,
    SongFileTypeFilter? fileTypeFilter,
  }) {
    return SongsState(
      songs: songs ?? this.songs,
      sortOption: sortOption ?? this.sortOption,
      fileTypeFilter: fileTypeFilter ?? this.fileTypeFilter,
    );
  }

  /// Get sorted and filtered songs based on current options.
  List<Song> get sortedSongs {
    var result = List<Song>.from(songs);

    if (fileTypeFilter != SongFileTypeFilter.all) {
      result = result
          .where((song) => fileTypeFilter.matches(song.fileType))
          .toList();
    }

    switch (sortOption) {
      case SongSortOption.albumArtist:
        result.sort((a, b) {
          final artistA = a.albumArtist ?? a.artist;
          final artistB = b.albumArtist ?? b.artist;
          final artistCompare = artistA.compareTo(artistB);
          if (artistCompare != 0) return artistCompare;
          // Secondary sort by album, then disc/track number, then title.
          final albumCompare = (a.album ?? '').compareTo(b.album ?? '');
          if (albumCompare != 0) return albumCompare;

          final discA = (a.discNumber != null && a.discNumber! > 0)
              ? a.discNumber!
              : 1;
          final discB = (b.discNumber != null && b.discNumber! > 0)
              ? b.discNumber!
              : 1;
          final discCompare = discA.compareTo(discB);
          if (discCompare != 0) return discCompare;

          final trackA = (a.trackNumber != null && a.trackNumber! > 0)
              ? a.trackNumber
              : null;
          final trackB = (b.trackNumber != null && b.trackNumber! > 0)
              ? b.trackNumber
              : null;
          final hasTrackA = trackA != null;
          final hasTrackB = trackB != null;
          if (hasTrackA && hasTrackB) {
            final trackCompare = trackA.compareTo(trackB);
            if (trackCompare != 0) return trackCompare;
          } else if (hasTrackA != hasTrackB) {
            return hasTrackA ? -1 : 1;
          }

          return a.title.compareTo(b.title);
        });
      case SongSortOption.title:
        result.sort((a, b) => a.title.compareTo(b.title));
      case SongSortOption.artist:
        result.sort((a, b) => a.artist.compareTo(b.artist));
      case SongSortOption.dateAdded:
        result.sort((a, b) {
          final dateA = a.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
      case SongSortOption.fileType:
        result.sort((a, b) => a.fileType.compareTo(b.fileType));
      case SongSortOption.folder:
        result.sort((a, b) {
          final folderA = extractRelativeSubfolder(a.folderUri, a.filePath);
          final folderB = extractRelativeSubfolder(b.folderUri, b.filePath);
          final folderCompare = folderA.compareTo(folderB);
          if (folderCompare != 0) return folderCompare;
          return a.title.compareTo(b.title);
        });
    }
    return result;
  }

  static String extractRelativeSubfolder(String? folderUri, String? filePath) {
    if (filePath == null || filePath.isEmpty) return '';

    String rootId = '';
    if (folderUri != null && folderUri.isNotEmpty) {
      final uri = Uri.tryParse(folderUri);
      if (uri != null && uri.scheme == 'content') {
        final segments = uri.pathSegments;
        final treeIndex = segments.indexOf('tree');
        if (treeIndex >= 0 && treeIndex + 1 < segments.length) {
          rootId = Uri.decodeComponent(segments[treeIndex + 1])
              .replaceAll('\\', '/')
              .replaceAll(RegExp(r'/+$'), '');
        }
      } else {
        rootId = folderUri.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
      }
    }

    String fileDocPath = '';
    final fileUri = Uri.tryParse(filePath);
    if (fileUri != null && fileUri.scheme == 'content') {
      final segments = fileUri.pathSegments;
      final docIndex = segments.indexOf('document');
      if (docIndex >= 0 && docIndex + 1 < segments.length) {
        fileDocPath = Uri.decodeComponent(segments[docIndex + 1])
            .replaceAll('\\', '/')
            .replaceAll(RegExp(r'/+$'), '');
      }
    } else {
      fileDocPath = filePath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    }

    if (fileDocPath.isEmpty) return '';

    if (rootId.isNotEmpty && fileDocPath.startsWith(rootId)) {
      var relative = fileDocPath.substring(rootId.length);
      if (relative.startsWith('/')) relative = relative.substring(1);
      final lastSlash = relative.lastIndexOf('/');
      if (lastSlash > 0) {
        return relative.substring(0, lastSlash);
      }
      return '';
    }

    // When rootId is in Android's "storage:path" format (e.g. "primary:Music")
    // and fileDocPath is a filesystem path (e.g. "/storage/emulated/0/Music/..."),
    // resolve the tree ID to a filesystem prefix and try matching again.
    if (rootId.isNotEmpty && fileDocPath.startsWith('/')) {
      final fsRoot = _treeIdToFilesystemPath(rootId);
      if (fsRoot != null && fileDocPath.startsWith(fsRoot)) {
        var relative = fileDocPath.substring(fsRoot.length);
        if (relative.startsWith('/')) relative = relative.substring(1);
        final lastSlash = relative.lastIndexOf('/');
        if (lastSlash > 0) {
          return relative.substring(0, lastSlash);
        }
        return '';
      }
    }

    final lastSlash = fileDocPath.lastIndexOf('/');
    if (lastSlash > 0) {
      return fileDocPath.substring(0, lastSlash);
    }
    return '';
  }

  /// Convert an Android SAF tree ID (e.g. "primary:Music", "1A2B-3C4D:FLAC")
  /// to a filesystem path prefix (e.g. "/storage/emulated/0/Music",
  /// "/storage/1A2B-3C4D/FLAC").
  static String? _treeIdToFilesystemPath(String treeId) {
    final colonIdx = treeId.indexOf(':');
    if (colonIdx < 0) return null;

    final storage = treeId.substring(0, colonIdx);
    final subPath = treeId.substring(colonIdx + 1);

    String storageRoot;
    if (storage.toLowerCase() == 'primary') {
      storageRoot = '/storage/emulated/0';
    } else {
      // External SD card or USB — volume ID is the directory name
      storageRoot = '/storage/$storage';
    }

    if (subPath.isEmpty) return storageRoot;
    return '$storageRoot/$subPath';
  }

  static String folderDisplayName(String? folderUri, String? filePath) {
    final subfolder = extractRelativeSubfolder(folderUri, filePath);
    if (subfolder.isNotEmpty) {
      final parts = subfolder.split('/').where((p) => p.isNotEmpty).toList();
      return parts.isNotEmpty ? parts.last : subfolder;
    }
    if (folderUri != null && folderUri.isNotEmpty) {
      final uri = Uri.tryParse(folderUri);
      if (uri != null && uri.scheme == 'content') {
        final segments = uri.pathSegments;
        final treeIndex = segments.indexOf('tree');
        if (treeIndex >= 0 && treeIndex + 1 < segments.length) {
          final decoded = Uri.decodeComponent(segments[treeIndex + 1]);
          final normalized = decoded.replaceAll('\\', '/').replaceAll(RegExp(r'/+'), '/');
          final parts = normalized.split('/');
          final nonEmpty = parts.where((p) => p.isNotEmpty).toList();
          if (nonEmpty.isNotEmpty) return nonEmpty.last;
        }
      }
      final normalized = folderUri.replaceAll('\\', '/').replaceAll(RegExp(r'/+'), '/');
      final parts = normalized.split('/');
      final nonEmpty = parts.where((p) => p.isNotEmpty).toList();
      return nonEmpty.isNotEmpty ? nonEmpty.last : normalized;
    }
    return 'Unknown';
  }

  List<FolderGroup> get folderGroups {
    if (sortOption != SongSortOption.folder) return [];

    var result = List<Song>.from(songs);

    if (fileTypeFilter != SongFileTypeFilter.all) {
      result = result
          .where((song) => fileTypeFilter.matches(song.fileType))
          .toList();
    }

    final groups = <String, FolderGroup>{};
    for (final song in result) {
      final subfolder = extractRelativeSubfolder(song.folderUri, song.filePath);
      final key = subfolder.isEmpty ? (song.folderUri ?? '__root__') : subfolder;
      final displayName = subfolder.isEmpty
          ? folderDisplayName(song.folderUri, song.filePath)
          : subfolder.split('/').where((p) => p.isNotEmpty).last;
      groups.putIfAbsent(
        key,
        () => FolderGroup(
          name: displayName,
          key: key,
          folderUri: song.folderUri,
          songs: [],
        ),
      );
      groups[key]!.songs.add(song);
    }

    final sorted = groups.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }
}

/// AsyncNotifier for managing the songs list.
/// Uses autoDispose to clean up when not being watched.
class SongsNotifier extends AsyncNotifier<SongsState> {
  static const _sortOptionKey = 'songs_sort_option';
  static const _fileTypeFilterKey = 'songs_file_type_filter';
  StreamSubscription<void>? _watchSubscription;
  SongSortOption _sortOption = SongSortOption.albumArtist;
  SongFileTypeFilter _fileTypeFilter = SongFileTypeFilter.all;

  @override
  Future<SongsState> build() async {
    final repository = ref.watch(songRepositoryProvider);

    _sortOption = await _loadSortOption();
    _fileTypeFilter = await _loadFileTypeFilter();

    _watchSubscription?.cancel();
    _watchSubscription = repository.watchSongs().listen((_) {
      ref.invalidateSelf();
    });

    ref.onDispose(() {
      _watchSubscription?.cancel();
    });

    final songs = await repository.getAllSongs();
    return SongsState(
      songs: songs,
      sortOption: _sortOption,
      fileTypeFilter: _fileTypeFilter,
    );
  }

  void setSortOption(SongSortOption option) {
    _sortOption = option;
    _saveSortOption(option);
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(sortOption: option));
    }
  }

  void setFileTypeFilter(SongFileTypeFilter filter) {
    _fileTypeFilter = filter;
    _saveFileTypeFilter(filter);
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(fileTypeFilter: filter));
    }
  }

  Future<SongSortOption> _loadSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_sortOptionKey);
    if (value == null) return SongSortOption.albumArtist;
    return SongSortOption.values.firstWhere(
      (opt) => opt.name == value,
      orElse: () => SongSortOption.albumArtist,
    );
  }

  Future<SongFileTypeFilter> _loadFileTypeFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_fileTypeFilterKey);
    if (value == null) return SongFileTypeFilter.all;
    return SongFileTypeFilter.values.firstWhere(
      (f) => f.name == value,
      orElse: () => SongFileTypeFilter.all,
    );
  }

  Future<void> _saveSortOption(SongSortOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortOptionKey, option.name);
  }

  Future<void> _saveFileTypeFilter(SongFileTypeFilter filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fileTypeFilterKey, filter.name);
  }

  /// Force refresh the songs list.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Main songs provider with async data loading.
final songsProvider =
    AsyncNotifierProvider.autoDispose<SongsNotifier, SongsState>(
      SongsNotifier.new,
    );

/// Convenience provider for just the sorted song list.
final sortedSongsProvider = Provider.autoDispose<AsyncValue<List<Song>>>((ref) {
  return ref.watch(songsProvider).whenData((state) => state.sortedSongs);
});

/// Song count provider.
final songCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(songsProvider).value?.songs.length ?? 0;
});

// ============================================================================
// Album and Artist grouping providers
// ============================================================================

/// Songs grouped by album.
final songsByAlbumProvider = FutureProvider.autoDispose<List<AlbumGroup>>((
  ref,
) async {
  final repository = ref.watch(songRepositoryProvider);
  return repository.getAlbumGroups();
});

/// Songs grouped by artist.
final songsByArtistProvider =
    FutureProvider.autoDispose<Map<String, List<Song>>>((ref) async {
      final repository = ref.watch(songRepositoryProvider);
      return repository.getSongsByArtist();
    });

// ============================================================================
// Search provider
// ============================================================================

/// Notifier for search query state.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Search query state provider.
final searchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );

/// Filtered songs based on search query.
final searchResultsProvider = FutureProvider.autoDispose<List<Song>>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];

  final repository = ref.watch(songRepositoryProvider);
  return repository.searchSongs(query);
});
