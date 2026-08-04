# flutter_pdfview monorepo

Native PDF viewing for Flutter — PDFKit on iOS, [AndroidPdfViewer][apv] on Android.

**Using the plugin? You want [`packages/flutter_pdfview`](packages/flutter_pdfview) —
its README is the user-facing documentation, and it is what is published to
[pub.dev][pub].** This file only describes the repository layout.

## Packages

| Package | Published as | Purpose |
| --- | --- | --- |
| [`packages/flutter_pdfview`](packages/flutter_pdfview) | [`flutter_pdfview`][pub] | The app-facing plugin, plus the Android (Kotlin) and iOS (Swift) implementations. |

The repository is a [Dart pub workspace][workspace] driven by [Melos][melos], so
platform implementations can be split into their own packages later without
another repository move.

## Working on it

```bash
dart pub global activate melos   # once
melos bootstrap                  # resolve every package against the root lockfile

melos run analyze
melos run test                   # Dart unit tests
melos run test:android           # Robolectric/JUnit suite for the Android module
melos run format
```

Running the example app:

```bash
cd packages/flutter_pdfview/example
flutter run
```

Dependencies resolve from the single lockfile at the repository root; member
packages do not carry their own. Run `melos bootstrap` after changing any
`pubspec.yaml`.

## Contributing

Issues and pull requests: <https://github.com/endigo/flutter_pdfview/issues>.
The project is [looking for maintainers][maintainers].

[apv]: https://github.com/marain87/AndroidPdfViewer
[pub]: https://pub.dev/packages/flutter_pdfview
[workspace]: https://dart.dev/tools/pub/workspaces
[melos]: https://melos.invertase.dev
[maintainers]: https://github.com/endigo/flutter_pdfview/issues/270
