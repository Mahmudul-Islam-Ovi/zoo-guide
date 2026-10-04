# 🦁 Mirpur Zoo Adventure – Offline Kid-Friendly Zoo Map

A colourful, fully **offline** interactive map and guide for the Bangladesh National Zoo (Mirpur), built with Flutter.

- Map engine: [`flutter_map`](https://pub.dev/packages/flutter_map) + [`latlong2`](https://pub.dev/packages/latlong2) (no Google Maps, no API keys, no internet)
- Data: your cleaned `zoo_data.geojson` (paths, cages, amenities, lakes)
- Kid-friendly UI: bright yellow paths, emoji animal markers, rounded bottom sheets with fun facts

---

## ✨ Features

| Feature | Details |
| --- | --- |
| Initial view | Centred on **23.8115, 90.3475**, zoom **16.5** |
| 🛰️ Live GPS Tracking | Real-time device location tracking with animated radar pulse and heading indicator |
| 🚶‍♂️ Virtual Tour Simulation | Test walking through the zoo anywhere from home along a 14-stop scenic path |
| 🧭 Live Route Guidance | Direct navigation line from user's live position to any selected animal or facility |
| 📏 Distance & Walk Time | Shows real-time distance in meters/km and estimated walking minutes |
| 🔍 Instant Search | Search animals in Bengali & English (বাঘ, সিংহ, হরিণ, Tiger, Lion) with quick jump |
| 🏷️ Category Filter Pills | Quick filters for Big Cats (🐯), Herbivores (🦒), Birds (🦜), Primates (🐒), and Facilities (🚻) |
| Paths | `LineString` footways/service roads drawn as sunny-yellow polylines with a warm brown outline; outside road in soft peach |
| Markers | Interactive animated badges for animals and facilities (washrooms, main gate, mosque, etc.) |
| Bottom sheet | Animal photo/emoji, English + Bengali names, fun facts, live distance, Guide Me button, and sound effects |
| Controls | GPS Locate Me, Virtual Simulation Tour, Zoom +/−, and Home Reset buttons |

---

## 📋 Prerequisites

- **Flutter 3.27 or newer** (Dart 3.3+). Check with `flutter --version`
- An Android/iOS device, an emulator, or Chrome (`flutter run -d chrome`)

---

## 🚀 Quick start

This zip contains the Dart code and assets (`lib/`, `assets/`, `pubspec.yaml`, `test/`). It does **not** include the generated `android/` / `ios/` platform folders, so create those first:

```bash
# 1. Unzip, then create a fresh Flutter project with the same name
flutter create mirpur_zoo_guide
cd mirpur_zoo_guide

# 2. Copy the files from this zip over the fresh project
#    (replace pubspec.yaml, lib/, test/, analysis_options.yaml; add assets/)
#    Example on macOS/Linux, if the unzipped folder is ../mirpur_zoo_guide_src:
cp -r ../mirpur_zoo_guide_src/lib ../mirpur_zoo_guide_src/test ../mirpur_zoo_guide_src/assets .
cp ../mirpur_zoo_guide_src/pubspec.yaml ../mirpur_zoo_guide_src/analysis_options.yaml .

# 3. Install packages
flutter pub get

# 4. Run
flutter run
```

On Windows, just drag the `lib`, `test`, `assets` folders and the two `.yaml` files from the unzipped folder into the new project and accept "Replace".

### Alternative: add platform folders in-place

```bash
cd mirpur_zoo_guide        # the unzipped folder
flutter create --project-name mirpur_zoo_guide .
flutter pub get
flutter run
```

If `flutter create` replaced `lib/main.dart` with the default counter app, copy `main.dart` from the zip again.

---

## 📁 Project structure

```
mirpur_zoo_guide/
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
├── assets/
│   ├── map_data/
│   │   └── zoo_data.geojson        ← your map data
│   └── images/
│       └── animals/                ← optional animal photos (see below)
├── lib/
│   └── main.dart                   ← the whole app (7 clearly marked sections)
└── test/
    └── parser_test.dart            ← unit test for the GeoJSON parser
```

`lib/main.dart` sections: **1.** constants & palette · **2.** species fun-fact database · **3.** data models · **4.** GeoJSON parser · **5.** app & map page · **6.** markers · **7.** bottom sheet.

---

## 🖼️ Adding real animal photos

The bottom sheet shows a big emoji as a placeholder. To use a real picture, add a file named after the animal's **slug** into `assets/images/animals/`:

```
assets/images/animals/royal_bengal_tiger.png
assets/images/animals/giraffe.png
assets/images/animals/greater_flamingo.png
```

The slug is the animal title in lowercase with non-letters replaced by `_` (e.g. "Oriental Pied Hornbill" → `oriental_pied_hornbill.png`). If the file exists it automatically covers the emoji; if not, the emoji stays. The folder is already declared in `pubspec.yaml`.

> Use `.png`. To use `.jpg`, change the extension in `PlaceSheet` (search for `animals/${place.imageSlug}.png`).

---

## 🧠 Editing fun facts

All animal names, emojis, colours and fun facts live in the `kSpecies` list near the top of `lib/main.dart`. Each entry has:

```dart
SpeciesInfo(
  keywords: ['tiger'],            // matched against the name in the GeoJSON
  title: 'Royal Bengal Tiger',    // name shown to kids
  emoji: '🐯',
  color: Color(0xFFFF9800),
  fact: 'Your fun fact here…',
),
```

Order matters – specific entries (e.g. `estuarine`) go before general ones (`crocodile`). Animals that match no entry still get a marker and a generic fact.

---

## 🔊 Adding audio later

The **Play Audio** button only toggles its icon for now. When you have sound files:

1. Add a package such as `audioplayers` and put sounds in `assets/audio/`.
2. Add an `audioFile` field to `SpeciesInfo`.
3. Fill in `_toggleAudio()` in `_PlaceSheetState` (there's a `TODO` marker).

---

## 🗺️ How offline mode works

There is **no tile layer**. Everything you see is drawn from `zoo_data.geojson`: the zoo grounds, lakes, paths and markers sit on a cream "storybook" background. That means:

- No internet, API keys or tile downloads are needed.
- The Android release build needs no `INTERNET` permission.

If you later want real street/satellite imagery offline, look at `flutter_map_tile_caching` or an MBTiles package and add a `TileLayer` as the first child of `FlutterMap`.

---

## 📍 How the GeoJSON is interpreted

Your file also contains polygons (cages, lakes, buildings), not just points and lines, so the parser handles them like this:

| GeoJSON feature | Becomes |
| --- | --- |
| `LineString` with `highway` tag | Yellow path (`highway=secondary` → peach road) |
| `Point` with `attraction=animal` | Animal marker |
| Polygon/closed `LineString` cage with a name | Animal marker at the cage's centre |
| `amenity=toilets`, main `entrance`, mosque, payment terminal, "Directors Office" | Facility markers |
| `natural=water` polygons | Blue lakes |
| `tourism=zoo` + `zoo=enclosure` polygon | Green zoo grounds |
| Buildings, grass, fishing spot, unnamed cages | Ignored |

**Duplicates:** OpenStreetMap often maps one cage twice (a polygon and a point, e.g. the Donkey cage). The parser keeps one marker per species within 60 m.

**Unnamed cages** (a few polygons have no name at all) are skipped because a kid-friendly guide can't label them. Name them in your GeoJSON (`name` or `name:en`) and they'll appear automatically.

**Tweaks:** change `kDuplicateDistanceMeters`, `kLabelZoom`, the `Palette` colours, or the stroke widths in `_buildMap()`.

---

## ✅ Run the tests

```bash
flutter test
```

---

## 🛠️ Troubleshooting

| Problem | Fix |
| --- | --- |
| `Unable to load asset: assets/map_data/zoo_data.geojson` | Make sure the file is in that exact folder and `flutter pub get` was run; do a full restart (not hot reload) after changing assets |
| `The method 'withValues' isn't defined` | Your Flutter is older than 3.27 – run `flutter upgrade` |
| `flutter_map` API errors | `pubspec.yaml` pins `flutter_map ^7.0.2`. Version 8+ may have API changes |
| Bengali text looks like boxes on an emulator | Use a device/emulator image with Bengali font support |
| Markers overlap a lot | Zoom in – labels and spacing improve; or adjust marker size in `PlaceMarker` |

---

Happy exploring! 🐯🦒🐊
