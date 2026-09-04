# ShikiStart
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/steady41/ShikiWatch)](https://github.com/steady41/ShikiWatch/releases/latest/) [![GitHub all releases](https://img.shields.io/github/downloads/steady41/ShikiWatch/total?label=All%20Downloads)](https://github.com/steady41/ShikiWatch/releases/latest/)

Unofficial [Shikimori](https://shikimori.one/) client with online anime watching.

> The app is under active development.

## Features

- 📚 Library tracking — anime, manga and ranobe lists synced with your Shikimori profile
- 🔍 Explore — seasonal charts, top rated titles, calendar and advanced search with filters
- ▶️ Built-in player — episode navigation, quality selection, playback speed, subtitles
- 🕘 Local watch history with import/export backup
- 👤 Profiles — user pages, friends, clubs and watch history
- 🎨 Material You — dynamic colors, OLED mode, light/dark themes
- 🖥️ Cross-platform — Android, Windows and Linux builds
- 🔔 In-app update checker and release notes

## Screenshots

### Android

| Library | Anime info | Search filters | Explore |
| :--: | :--: | :--: | :--: |
| <img src="screenshots/scr-andr-library.png?raw=true" width="200"/> | <img src="screenshots/scr-andr-anime_info.png?raw=true" width="200"/> | <img src="screenshots/scr-andr-search-filters.png?raw=true" width="200"/> | <img src="screenshots/scr-andr-exp_page.png?raw=true" width="200"/> |

| Player | Profile | Local history |
| :--: | :--: | :--: |
| <img src="screenshots/scr-andr-player.jpg?raw=true" width="200"/> | <img src="screenshots/scr-andr-user_profile.jpg?raw=true" width="200"/> | <img src="screenshots/scr-andr-local_history.png?raw=true" width="200"/> |

More screenshots in the [screenshots](https://github.com/steady41/ShikiWatch/tree/master/screenshots) folder.

### Windows

Soon.

## Getting started

1. Download the latest build from the [Releases](https://github.com/steady41/ShikiWatch/releases) page.
2. Launch the app and sign in with your **Shikimori** account.
3. Enjoy **online streaming** and handy access to your **favorite anime**.

## Build from source

Requirements: [Flutter](https://docs.flutter.dev/get-started/install) 3.16+.

```bash
# 1. Provide API keys (Shikimori, Kodik, etc.)
cp secrets.example.json secrets.json

# 2. Install dependencies and generate code
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 3. Run (dev flavor)
flutter run --flavor dev --dart-define-from-file secrets.json

# 4. Build a release APK
flutter build apk --flavor prod --split-per-abi --dart-define-from-file secrets.json
```

Desktop builds:

```bash
flutter build windows --dart-define-from-file secrets.json
flutter build linux --dart-define-from-file secrets.json
```

## Tech stack

Flutter · Riverpod · GoRouter · MediaKit · Isar · Dio

## Contributing

Issues and pull requests are welcome.

## License

[MIT](LICENSE)

## Disclaimer

This is a fan-made, unofficial client. It is not affiliated with or endorsed by Shikimori. All anime data and artwork belong to their respective owners.
