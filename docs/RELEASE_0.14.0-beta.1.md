# Flick 0.14.0-beta.1

0.14.0-beta.1 is focused on speed and control. Library scanning is now up to 34x faster, the navigation bar is fully configurable, and you get new UI toggles, undo actions, and dynamic album theming.

## Overview
This beta brings three big changes:
1. A complete rewrite of the library scanner using MediaStore
2. First-pass customization for home and navigation
3. Foundation work for crossfade and album color theming

Loop mode now defaults to "all", preferences persist between sessions, and a lot of small UI friction has been removed.

## Highlights

- **34x faster scanning**: Hybrid MediaStore scanner with fingerprint caching and background metadata extraction
- **Customize your home**: Toggle Quick Access, Smart Mixes, Recent Artists, Recent Tracks, Playlists, and Browse More
- **Configurable nav bar**: Reorder buttons, show or hide labels, dedicated settings screen
- **Album color theming**: Dynamic colors extracted from album art with multiple modes
- **Undo everywhere**: Queue and favorites removals can be undone from the snackbar
- **New seek bar**: LineSeekBar with drag, tap, and fine scrubbing

## What's New

### Library & Performance
- Replaced folder-based scanning with MediaStore-based hybrid scanner
- Added fingerprint cache service to avoid re-reading unchanged files
- Background metadata extraction so UI stays responsive
- MediaStore observer service watches for new media automatically
- Debounced queue change notifications to cut redundant rebuilds

### UI Customization
- **Home screen toggles**: Settings > UI Customization
- **Bottom bar settings**: New screen to configure layout and labels
- **ProgressBarStyle**: Choose seek bar appearance
- **Equalizer**: Now a scroll-aware mini graph preview
- Updated launcher icons across mipmap densities

### Playback & Queue
- Default loop mode changed from `off` to `all`
- `addToQueue` returns the inserted index for precise undo
- Undo support added to queue and favorites snackbars
- Snackbar duration reduced from 3s to 2s
- Removed duplicate entries in Recently Played

### Search & Navigation
- New debounced Search screen
- Tap outside search bar or tap a nav item to dismiss keyboard
- Sort and file-type filter now persist via SharedPreferences
- Conditional back buttons for cleaner navigation
- SortFilterBottomSheet for songs

### Audio Foundation
- Crossfade engine added with curve selection, duration control, and gapless playback
- USB audio device detection with connection notifications
- Playback desync detection with automatic sync notification
- **Note**: Crossfade UI is intentionally hidden in this beta

### Theming
- AlbumColorProvider extracts palette from album art
- Configurable theming modes applied across player UI

## Improvements & Polish
- Replaced AlertDialog with GlassDialog for clear history flow
- Playlist creation moved from FAB to popup menu for consistency
- SliderSetting widget standardizes slider-based preferences
- General performance optimizations in player provider

## Breaking Changes
- **Android minSdk 26 required**. Update `android/app/build.gradle.kts` or builds will fail.

## Known Issues
- Crossfade works in code but has no settings UI in this build
- MediaStore fast scanning is Android-only; other platforms fall back to legacy scanner

## Files Changed

| Area | Key Paths |
| --- | --- |
| Settings | `settings_screen.dart`, `ui_customization_settings_screen.dart`, `audio_settings_screen.dart`, `bottom_bar_settings_screen.dart`, `equalizer_screen.dart` |
| Player | `full_player_screen.dart`, `line_seek_bar.dart` |
| Songs | `songs_screen.dart`, `sort_filter_bottom_sheet.dart` |
| Navigation | `flick_nav_bar.dart` |
| Providers | `app_preferences_provider.dart`, `player_provider.dart`, `nav_bar_config_provider.dart`, `album_color_provider.dart` |
| Services | `library_scanner_service.dart`, `fingerprint_cache_service.dart`, `mediastore_observer_service.dart`, `app_preferences_service.dart` |
| Data / Rust | `song_entity.dart`, `song_repository.dart`, `rust/api/scanner.dart`, `rust/src/audio/crossfader.rs` |
| Android | `android/app/build.gradle.kts` |

## Upgrading
1. Set `minSdk = 26` in `android/app/build.gradle.kts`
2. Clear app data once after install if migrating from pre-0.13 to rebuild the fingerprint cache
3. Re-apply home screen toggles in Settings > UI Customization
