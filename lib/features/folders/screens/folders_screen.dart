import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/music_folder_service.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/display_mode_wrapper.dart';

/// Groups songs by immediate subfolder relative to [prefix] within [folderUri].
({List<FolderGroup> subfolders, List<Song> songs}) groupByImmediateFolder({
  required List<Song> allSongs,
  required String folderUri,
  String prefix = '',
}) {
  final subfolderMap = <String, FolderGroup>{};
  final directSongs = <Song>[];

  for (final song in allSongs) {
    if (song.folderUri != folderUri) continue;

    final relPath =
        SongsState.extractRelativeSubfolder(song.folderUri, song.filePath);

    if (prefix.isNotEmpty) {
      if (relPath != prefix && !relPath.startsWith('$prefix/')) continue;
    }

    if (relPath == prefix) {
      directSongs.add(song);
    } else {
      final remainder =
          prefix.isEmpty ? relPath : relPath.substring(prefix.length + 1);
      final slashIdx = remainder.indexOf('/');
      final immediateFolder =
          slashIdx == -1 ? remainder : remainder.substring(0, slashIdx);
      final fullKey =
          prefix.isEmpty ? immediateFolder : '$prefix/$immediateFolder';
      subfolderMap.putIfAbsent(
        fullKey,
        () => FolderGroup(
          name: immediateFolder,
          key: fullKey,
          folderUri: song.folderUri,
          songs: [],
        ),
      );
      subfolderMap[fullKey]!.songs.add(song);
    }
  }

  final sortedFolders = subfolderMap.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  directSongs.sort((a, b) => a.title.compareTo(b.title));

  return (subfolders: sortedFolders, songs: directSongs);
}

/// Top-level folders screen showing root music folders as a grid.
class FoldersScreen extends ConsumerStatefulWidget {
  const FoldersScreen({super.key});

  @override
  ConsumerState<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends ConsumerState<FoldersScreen> {
  final MusicFolderService _folderService = MusicFolderService();
  List<MusicFolder> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFolders();
    });
  }

  Future<void> _loadFolders() async {
    final folders = await _folderService.getSavedFolders();
    if (mounted) {
      setState(() {
        _folders = folders;
        _isLoading = false;
      });
    }
  }

  void _openRootFolder(MusicFolder folder) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FolderBrowserScreen(
              folderUri: folder.uri,
              displayName: folder.displayName,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (AppConstants.animationNormal == Duration.zero) return child;
          const begin = Offset(0.12, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: AppConstants.animationNormal,
        opaque: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DisplayModeWrapper(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.textSecondary,
                        ),
                      )
                    : _folders.isEmpty
                        ? _buildEmptyState()
                        : _buildRootFoldersGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: IconButton(
                icon: Icon(
                  LucideIcons.arrowLeft,
                  color: context.adaptiveTextPrimary,
                  size: context.responsiveIcon(AppConstants.iconSizeMd),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppConstants.spacingMd),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Folders',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.adaptiveTextPrimary,
                      ),
                ),
                Text(
                  '${_folders.length} music folders',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.folderOpen,
            size: context.responsiveIcon(AppConstants.containerSizeLg),
            color: context.adaptiveTextTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Text(
            'No Folders Added',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            'Add music folders in Settings',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRootFoldersGrid() {
    final songsAsync = ref.watch(songsProvider);
    final allSongs = songsAsync.value?.songs ?? const [];

    // Build folder group-like objects for root folders with song data
    final rootGroups = <_RootFolderEntry>[];
    for (final folder in _folders) {
      final folderSongs =
          allSongs.where((s) => s.folderUri == folder.uri).toList();
      rootGroups.add(_RootFolderEntry(folder: folder, songs: folderSongs));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        0,
        AppConstants.spacingLg,
        AppConstants.navBarHeight + 120,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.gridColumns(compact: 2, phone: 2, tablet: 3),
        childAspectRatio: 0.78,
        crossAxisSpacing: AppConstants.spacingMd,
        mainAxisSpacing: AppConstants.spacingLg,
      ),
      itemCount: rootGroups.length,
      itemBuilder: (context, index) {
        final entry = rootGroups[index];
        return _RootFolderCard(
          entry: entry,
          onTap: () => _openRootFolder(entry.folder),
        );
      },
    );
  }
}

class _RootFolderEntry {
  final MusicFolder folder;
  final List<Song> songs;

  const _RootFolderEntry({required this.folder, required this.songs});
}

/// Interactive folder card for root music folders.
class _RootFolderCard extends StatefulWidget {
  final _RootFolderEntry entry;
  final VoidCallback onTap;

  const _RootFolderCard({required this.entry, required this.onTap});

  @override
  State<_RootFolderCard> createState() => _RootFolderCardState();
}

class _RootFolderCardState extends State<_RootFolderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _tiltAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.animationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _tiltAnimation = Tween<double>(begin: 0.0, end: 0.02)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_ArtEntry> _getUniqueArtworks() {
    final seen = <String>{};
    final result = <_ArtEntry>[];
    for (final song in widget.entry.songs) {
      final art = song.albumArt;
      if (art != null && art.isNotEmpty && seen.add(art)) {
        result.add(_ArtEntry(art, song.filePath));
      }
      if (result.length >= 4) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final artworks = _getUniqueArtworks();
    final padded = List<_ArtEntry>.from(artworks);
    while (padded.length < 4) {
      padded.add(const _ArtEntry(null, null));
    }

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
              _scaleAnimation.value,
              _scaleAnimation.value,
              1.0,
            )..rotateZ(_tiltAnimation.value),
            child: child,
          );
        },
        child: RepaintBoundary(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.all(
                            Radius.circular(AppConstants.radiusLg),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(
                            Radius.circular(AppConstants.radiusLg),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildArtGrid(context, padded),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.1),
                                        Colors.black.withValues(alpha: 0.45),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: AppConstants.spacingSm,
                                bottom: AppConstants.spacingSm,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppConstants.spacingSm,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Text(
                                    '${widget.entry.songs.length} tracks',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.spacingSm,
                        AppConstants.spacingMd,
                        AppConstants.spacingSm,
                        AppConstants.spacingSm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.entry.folder.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: context.adaptiveTextPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.entry.songs.length} songs',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: context.adaptiveTextSecondary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtGrid(
      BuildContext context, List<_ArtEntry> artworks) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cardWidth = context.scaleSize(AppConstants.cardWidthMd);
    final targetWidth = (cardWidth * devicePixelRatio).round();
    final cellSize = targetWidth ~/ 2;

    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: artworks.map((entry) {
        if (entry.art != null && entry.art!.isNotEmpty) {
          return ClipRRect(
            borderRadius:
                BorderRadius.all(Radius.circular(AppConstants.radiusSm)),
            child: CachedImageWidget(
              imagePath: entry.art,
              audioSourcePath: entry.source,
              fit: BoxFit.cover,
              useThumbnail: true,
              thumbnailWidth: cellSize,
              thumbnailHeight: cellSize,
              placeholder: _buildGridPlaceholder(context),
              errorWidget: _buildGridPlaceholder(context),
            ),
          );
        }
        return _buildGridPlaceholder(context);
      }).toList(),
    );
  }

  Widget _buildGridPlaceholder(BuildContext context) {
    return ClipRRect(
      borderRadius:
          BorderRadius.all(Radius.circular(AppConstants.radiusSm)),
      child: Container(
        color: AppColors.surfaceLight,
        child: const Icon(
          LucideIcons.music,
          color: AppColors.textTertiary,
          size: 18,
        ),
      ),
    );
  }
}

/// Recursive folder browser showing subfolders and songs at the current level.
class FolderBrowserScreen extends ConsumerStatefulWidget {
  final String folderUri;
  final String displayName;
  final String prefix;

  const FolderBrowserScreen({
    super.key,
    required this.folderUri,
    required this.displayName,
    this.prefix = '',
  });

  @override
  ConsumerState<FolderBrowserScreen> createState() =>
      _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends ConsumerState<FolderBrowserScreen> {
  List<Song> _allSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSongs();
    });
  }

  Future<void> _loadSongs() async {
    final repository = ref.read(songRepositoryProvider);
    final songs = await repository.getSongsByFolder(widget.folderUri);
    if (mounted) {
      setState(() {
        _allSongs = songs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, 0),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final (:subfolders, :songs) = groupByImmediateFolder(
      allSongs: _allSongs,
      folderUri: widget.folderUri,
      prefix: widget.prefix,
    );

    final totalCount = subfolders.fold<int>(
          0,
          (sum, g) => sum + g.songs.length,
        ) +
        songs.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, totalCount),
            Expanded(
              child: subfolders.isEmpty && songs.isEmpty
                  ? _buildEmptyState(context)
                  : _buildContent(context, subfolders, songs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    final title =
        widget.prefix.isEmpty ? widget.displayName : widget.prefix.split('/').last;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: IconButton(
              icon: Icon(
                LucideIcons.arrowLeft,
                color: context.adaptiveTextPrimary,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.folder,
                      size: 18,
                      color: context.adaptiveTextSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.adaptiveTextPrimary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$count items',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: IconButton(
              icon: Icon(
                LucideIcons.shuffle,
                color: context.adaptiveTextPrimary,
                size: 20,
              ),
              onPressed: () => _shuffleAll(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<FolderGroup> subfolders,
    List<Song> songs,
  ) {
    return ListView(
      padding: EdgeInsets.only(bottom: AppConstants.navBarHeight + 120),
      children: [
        if (subfolders.isNotEmpty) ...[
          _buildSubfolderGrid(context, subfolders),
          if (songs.isNotEmpty)
            const SizedBox(height: AppConstants.spacingMd),
        ],
        for (final song in songs)
          Padding(
            key: ValueKey(song.id),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg,
              vertical: AppConstants.spacingXxs,
            ),
            child: _SongTile(
              song: song,
              onTap: () => _playSong(song, songs, subfolders),
            ),
          ),
      ],
    );
  }

  Widget _buildSubfolderGrid(
      BuildContext context, List<FolderGroup> subfolders) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingSm,
        AppConstants.spacingLg,
        0,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.gridColumns(compact: 2, phone: 2, tablet: 3),
        childAspectRatio: 0.78,
        crossAxisSpacing: AppConstants.spacingMd,
        mainAxisSpacing: AppConstants.spacingLg,
      ),
      itemCount: subfolders.length,
      itemBuilder: (context, index) {
        final folder = subfolders[index];
        return _SubfolderCard(
          folder: folder,
          onTap: () => _openSubfolder(context, folder),
        );
      },
    );
  }

  void _openSubfolder(BuildContext context, FolderGroup folder) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FolderBrowserScreen(
              folderUri: widget.folderUri,
              displayName: widget.displayName,
              prefix: folder.key,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (AppConstants.animationNormal == Duration.zero) return child;
          const begin = Offset(0.12, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: AppConstants.animationNormal,
        opaque: true,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.folderOpen,
            size: 56,
            color: context.adaptiveTextTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            'No Songs Found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            'This folder appears to be empty',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _playSong(
    Song song,
    List<Song> directSongs,
    List<FolderGroup> subfolders,
  ) async {
    final playlist = _buildPlaylist(directSongs, subfolders);
    await ref.read(playerProvider.notifier).play(song, playlist: playlist);
    if (mounted) {
      await NavigationHelper.navigateToFullPlayer(
        context,
        heroTag: 'folder_song_${song.id}',
      );
    }
  }

  List<Song> _buildPlaylist(
      List<Song> directSongs, List<FolderGroup> subfolders) {
    final result = <Song>[];
    for (final folder in subfolders) {
      result.addAll(folder.songs);
    }
    result.addAll(directSongs);
    return result;
  }

  Future<void> _shuffleAll(BuildContext context) async {
    final (:subfolders, :songs) = groupByImmediateFolder(
      allSongs: _allSongs,
      folderUri: widget.folderUri,
      prefix: widget.prefix,
    );
    final playlist = _buildPlaylist(songs, subfolders);
    if (playlist.isEmpty) return;
    final shuffled = List<Song>.from(playlist)..shuffle(Random());
    await ref.read(playerProvider.notifier).play(
          shuffled.first,
          playlist: shuffled,
        );
    if (mounted) {
      await NavigationHelper.navigateToFullPlayer(
        context,
        heroTag: 'folder_shuffle_${widget.prefix}',
      );
    }
  }
}

/// Interactive folder card for subfolders in the browser.
class _SubfolderCard extends StatefulWidget {
  final FolderGroup folder;
  final VoidCallback onTap;

  const _SubfolderCard({required this.folder, required this.onTap});

  @override
  State<_SubfolderCard> createState() => _SubfolderCardState();
}

class _SubfolderCardState extends State<_SubfolderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _tiltAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.animationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _tiltAnimation = Tween<double>(begin: 0.0, end: 0.02)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_ArtEntry> _getUniqueArtworks() {
    final seen = <String>{};
    final result = <_ArtEntry>[];
    for (final song in widget.folder.songs) {
      final art = song.albumArt;
      if (art != null && art.isNotEmpty && seen.add(art)) {
        result.add(_ArtEntry(art, song.filePath));
      }
      if (result.length >= 4) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final artworks = _getUniqueArtworks();
    final padded = List<_ArtEntry>.from(artworks);
    while (padded.length < 4) {
      padded.add(const _ArtEntry(null, null));
    }

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
              _scaleAnimation.value,
              _scaleAnimation.value,
              1.0,
            )..rotateZ(_tiltAnimation.value),
            child: child,
          );
        },
        child: RepaintBoundary(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.all(
                            Radius.circular(AppConstants.radiusLg),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(
                            Radius.circular(AppConstants.radiusLg),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildArtGrid(context, padded),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.1),
                                        Colors.black.withValues(alpha: 0.45),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: AppConstants.spacingSm,
                                bottom: AppConstants.spacingSm,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppConstants.spacingSm,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Text(
                                    '${widget.folder.songs.length} tracks',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.spacingSm,
                        AppConstants.spacingMd,
                        AppConstants.spacingSm,
                        AppConstants.spacingSm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.folder.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: context.adaptiveTextPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.folder.songs.length} songs',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: context.adaptiveTextSecondary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtGrid(BuildContext context, List<_ArtEntry> artworks) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cardWidth = context.scaleSize(AppConstants.cardWidthMd);
    final targetWidth = (cardWidth * devicePixelRatio).round();
    final cellSize = targetWidth ~/ 2;

    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: artworks.map((entry) {
        if (entry.art != null && entry.art!.isNotEmpty) {
          return ClipRRect(
            borderRadius:
                BorderRadius.all(Radius.circular(AppConstants.radiusSm)),
            child: CachedImageWidget(
              imagePath: entry.art,
              audioSourcePath: entry.source,
              fit: BoxFit.cover,
              useThumbnail: true,
              thumbnailWidth: cellSize,
              thumbnailHeight: cellSize,
              placeholder: _buildGridPlaceholder(context),
              errorWidget: _buildGridPlaceholder(context),
            ),
          );
        }
        return _buildGridPlaceholder(context);
      }).toList(),
    );
  }

  Widget _buildGridPlaceholder(BuildContext context) {
    return ClipRRect(
      borderRadius:
          BorderRadius.all(Radius.circular(AppConstants.radiusSm)),
      child: Container(
        color: AppColors.surfaceLight,
        child: const Icon(
          LucideIcons.music,
          color: AppColors.textTertiary,
          size: 18,
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _SongTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingSm,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: CachedImageWidget(
                    imagePath: song.albumArt,
                    audioSourcePath: song.filePath,
                    fit: BoxFit.cover,
                    useThumbnail: true,
                    thumbnailWidth: 92,
                    thumbnailHeight: 92,
                    placeholder: const ColoredBox(
                      color: AppColors.surface,
                      child: Icon(
                        LucideIcons.music,
                        color: AppColors.textTertiary,
                        size: 18,
                      ),
                    ),
                    errorWidget: const ColoredBox(
                      color: AppColors.surface,
                      child: Icon(
                        LucideIcons.music,
                        color: AppColors.textTertiary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: context.adaptiveTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${song.artist} • ${song.fileType.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.adaptiveTextSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Text(
                song.formattedDuration,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adaptiveTextTertiary,
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

class _ArtEntry {
  final String? art;
  final String? source;

  const _ArtEntry(this.art, this.source);
}
