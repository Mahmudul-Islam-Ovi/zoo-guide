// Mirpur National Zoo – Kid-friendly offline map & guide.
//
// Everything lives in this single file so it can be copy-pasted and run
// immediately. The file is split into clearly marked sections:
//
//   1. Constants & palette
//   2. Species "fun fact" database
//   3. Data models
//   4. GeoJSON parser
//   5. App & map page
//   6. Markers
//   7. Bottom sheet
//
// The map is fully offline: there is NO tile layer. The zoo is drawn from the
// GeoJSON file itself (boundary, lakes, paths and markers) on a playful
// cream-coloured "storybook" background.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, SystemSound, SystemSoundType;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'router.dart';
import 'simulation.dart';

// ---------------------------------------------------------------------------
// 1. CONSTANTS & PALETTE
// ---------------------------------------------------------------------------

const LatLng kZooCenter = LatLng(23.8115, 90.3475);
const LatLng kZooGate = LatLng(23.812549, 90.346991); // National Zoo Main Gate
const double kInitialZoom = 16.5;
const String kGeoJsonAsset = 'assets/map_data/zoo_data.geojson';

/// Zoom level at which animal names appear under the markers.
const double kLabelZoom = 17.8;

/// Two markers with the same species closer than this are treated as duplicates.
const double kDuplicateDistanceMeters = 60;

/// Virtual walking route inside Mirpur Zoo starting directly from Main Gate.
const List<LatLng> kSimulationRoute = [
  LatLng(23.812549, 90.346991), // Main Gate
  LatLng(23.8135, 90.3475),     // Central walkway junction
  LatLng(23.8143, 90.3472),     // Giraffe avenue
  LatLng(23.8152, 90.3471),     // Path to Tiger area
  LatLng(23.8158, 90.3473),     // Royal Bengal Tiger cage
  LatLng(23.8163, 90.3465),     // Indian Lion cage
  LatLng(23.8156, 90.3457),     // Big cats & carnivores
  LatLng(23.8147, 90.3453),     // Hippo & Rhino
  LatLng(23.8136, 90.3459),     // Chimpanzee & Monkeys
  LatLng(23.8128, 90.3472),     // South garden & lake
  LatLng(23.812549, 90.346991), // Return to Main Gate
];

class Palette {
  static const Color background = Color(0xFFFFF3D6); // cream
  static const Color paper = Color(0xFFFFFBF2);
  static const Color zooGround = Color(0xFFC6EB9E); // fresh grass
  static const Color zooBorder = Color(0xFF6CBF4B);
  static const Color water = Color(0xFF7DD3F7);
  static const Color waterBorder = Color(0xFF3FA9E0);
  static const Color pathFill = Color(0xFFFFD93D); // sunny yellow
  static const Color pathBorder = Color(0xFFE39B3B); // warm brown-orange
  static const Color road = Color(0xFFFFE7C2);
  static const Color roadBorder = Color(0xFFD9B98A);
  static const Color ink = Color(0xFF3B2A5A); // deep purple text
  static const Color primary = Color(0xFFFF7A00); // playful orange
  static const Color accent = Color(0xFF7C4DFF); // purple
  static const Color sky = Color(0xFF29B6F6);
  static const Color gpsBlue = Color(0xFF007AFF);
  static const Color gpsGlow = Color(0xFF00E5FF);
}

// ---------------------------------------------------------------------------
// 2. SPECIES DATABASE
// ---------------------------------------------------------------------------

/// Friendly information for one kind of animal. [keywords] are matched
/// (lower-case, "contains") against the name found in the GeoJSON, so the
/// order of [kSpecies] matters: more specific entries come first.
class SpeciesInfo {
  const SpeciesInfo({
    required this.keywords,
    required this.title,
    required this.emoji,
    required this.color,
    required this.fact,
  });

  final List<String> keywords;
  final String title;
  final String emoji;
  final Color color;
  final String fact;

  /// File name (without extension) used to look up an optional photo in
  /// `assets/images/animals/`, e.g. `royal_bengal_tiger`.
  String get slug => slugify(title);
}

String slugify(String input) => input
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

const List<SpeciesInfo> kSpecies = [
  SpeciesInfo(
    keywords: ['tiger'],
    title: 'Royal Bengal Tiger',
    emoji: '🐯',
    color: Color(0xFFFF9800),
    fact: "The Royal Bengal Tiger is Bangladesh's national animal! "
        'Its stripes are special – no two tigers have the same pattern, '
        'just like your fingerprints.',
  ),
  SpeciesInfo(
    keywords: ['lion'],
    title: 'Indian Lion',
    emoji: '🦁',
    color: Color(0xFFFFB300),
    fact: "A lion's roar is so loud it can be heard from up to 8 kilometres "
        'away. Lions can nap for up to 20 hours a day!',
  ),
  SpeciesInfo(
    keywords: ['leopard'],
    title: 'Leopard',
    emoji: '🐆',
    color: Color(0xFFFFA726),
    fact: 'Leopards are super strong climbers. They can even drag their '
        'dinner up a tree to keep it safe!',
  ),
  SpeciesInfo(
    keywords: ['giraffe'],
    title: 'Giraffe',
    emoji: '🦒',
    color: Color(0xFFFFCA28),
    fact: 'A giraffe has a very long neck, but only seven neck bones – the '
        'same number as you! Its purple-black tongue is about as long as '
        'your arm.',
  ),
  SpeciesInfo(
    keywords: ['hippo'],
    title: 'Hippopotamus',
    emoji: '🦛',
    color: Color(0xFF9FA8DA),
    fact: "'Hippopotamus' means 'river horse'. Hippos can hold their breath "
        'underwater for around five minutes!',
  ),
  SpeciesInfo(
    keywords: ['rhino'],
    title: 'Rhinoceros',
    emoji: '🦏',
    color: Color(0xFF90A4AE),
    fact: "A rhino's horn is made of keratin – the same stuff as your "
        'fingernails and hair!',
  ),
  SpeciesInfo(
    keywords: ['chimp'],
    title: 'Chimpanzee',
    emoji: '🐵',
    color: Color(0xFFBCAAA4),
    fact: 'Chimpanzees are very clever. They use sticks as tools to fish '
        'tasty termites out of their nests!',
  ),
  SpeciesInfo(
    keywords: ['baboon'],
    title: 'Baboons',
    emoji: '🐒',
    color: Color(0xFFD7A86E),
    fact: 'Baboons live in big families called troops and help each other '
        'by picking bugs out of each other’s fur.',
  ),
  SpeciesInfo(
    keywords: ['monkey'],
    title: 'Monkeys',
    emoji: '🐒',
    color: Color(0xFFD7A86E),
    fact: 'Monkeys talk to each other with funny faces and sounds. '
        'They are great jumpers and love to play!',
  ),
  SpeciesInfo(
    keywords: ['estuarine'],
    title: 'Estuarine Crocodile',
    emoji: '🐊',
    color: Color(0xFF66BB6A),
    fact: 'The estuarine (saltwater) crocodile is the biggest reptile in '
        'the world. It is even brave enough to swim out into the sea!',
  ),
  SpeciesInfo(
    keywords: ['marsh'],
    title: 'Marsh Crocodile',
    emoji: '🐊',
    color: Color(0xFF81C784),
    fact: 'Marsh crocodiles dig burrows in the mud to stay cool when the '
        'weather gets very hot.',
  ),
  SpeciesInfo(
    keywords: ['crocodile'],
    title: 'Crocodile',
    emoji: '🐊',
    color: Color(0xFF66BB6A),
    fact: 'Crocodiles have been around since the time of the dinosaurs! '
        'They can stay very still in the water for a long time.',
  ),
  SpeciesInfo(
    keywords: ['spotted'],
    title: 'Spotted Deer',
    emoji: '🦌',
    color: Color(0xFFFFAB91),
    fact: 'Spotted deer (called chital) keep their pretty white spots '
        'their whole life, not just when they are babies!',
  ),
  SpeciesInfo(
    keywords: ['samber', 'sambar'],
    title: 'Sambar Deer',
    emoji: '🦌',
    color: Color(0xFFBCAAA4),
    fact: 'Sambar are among the biggest deer in Asia. They love to rest '
        'near water to stay cool.',
  ),
  SpeciesInfo(
    keywords: ['deer'],
    title: 'Deer',
    emoji: '🦌',
    color: Color(0xFFFFAB91),
    fact: 'Deer have big ears and a super sense of smell, so they can '
        'sniff out danger from far away.',
  ),
  SpeciesInfo(
    keywords: ['nilgai'],
    title: 'Nilgai',
    emoji: '🐃',
    color: Color(0xFF81D4FA),
    fact: "'Nilgai' means 'blue cow'. It is the biggest antelope in Asia!",
  ),
  SpeciesInfo(
    keywords: ['donkey'],
    title: 'Donkey',
    emoji: '🫏',
    color: Color(0xFFB0BEC5),
    fact: 'Donkeys have huge ears that help them hear sounds from very '
        'far away. Hee-haw!',
  ),
  SpeciesInfo(
    keywords: ['bhutani', 'cow'],
    title: 'Bhutani Cow',
    emoji: '🐄',
    color: Color(0xFFA5D6A7),
    fact: 'Cows have best friends! They feel happier when they are '
        'together with their buddies.',
  ),
  SpeciesInfo(
    keywords: ['water buck', 'waterbuck'],
    title: 'Water Buck',
    emoji: '🐐',
    color: Color(0xFFCE93D8),
    fact: 'Waterbucks have a greasy coat and a white ring on their '
        'bottom that looks just like a target!',
  ),
  SpeciesInfo(
    keywords: ['vulture'],
    title: 'Vulture',
    emoji: '🦅',
    color: Color(0xFFA1887F),
    fact: "Vultures are nature's clean-up crew. They soar high in the sky "
        'and can spot food from far, far away.',
  ),
  SpeciesInfo(
    keywords: ['hornbill'],
    title: 'Oriental Pied Hornbill',
    emoji: '🐦',
    color: Color(0xFFFFD54F),
    fact: 'Hornbills have a giant bill with a bump on top! Mummy hornbill '
        'stays safe inside a tree hole while she looks after her eggs.',
  ),
  SpeciesInfo(
    keywords: ['black necked', 'black-necked'],
    title: 'Black-necked Stork',
    emoji: '🦢',
    color: Color(0xFF80CBC4),
    fact: 'This tall stork wades slowly through wetlands, looking for '
        'fish and frogs to snack on.',
  ),
  SpeciesInfo(
    keywords: ['adjutant'],
    title: 'Lesser Adjutant Stork',
    emoji: '🦢',
    color: Color(0xFF80CBC4),
    fact: 'The lesser adjutant stork has a bald head and a funny, '
        'stately walk – like a soldier marching!',
  ),
  SpeciesInfo(
    keywords: ['flamingo'],
    title: 'Greater Flamingo',
    emoji: '🦩',
    color: Color(0xFFF48FB1),
    fact: "Flamingos are pink because of the yummy food they eat! "
        'They love to stand on just one leg.',
  ),
  SpeciesInfo(
    keywords: ['peafowl', 'peacock'],
    title: 'Peafowl',
    emoji: '🦚',
    color: Color(0xFF4DD0E1),
    fact: 'Boy peafowl (peacocks) fan out their shiny tail feathers to '
        'show off. What a fancy dance!',
  ),
  SpeciesInfo(
    keywords: ['snake'],
    title: 'Snakes',
    emoji: '🐍',
    color: Color(0xFFAED581),
    fact: 'Snakes smell the air with their tongues, and they never '
        'blink – they have no eyelids!',
  ),
  SpeciesInfo(
    keywords: ['guinea', 'ginipig'],
    title: 'Guinea Pig',
    emoji: '🐹',
    color: Color(0xFFFFCC80),
    fact: "Guinea pigs aren't pigs and don't come from Guinea! They "
        "squeak 'wheek wheek' when they are excited.",
  ),
  SpeciesInfo(
    keywords: ['oryx', 'orix'],
    title: 'Oryx',
    emoji: '🦬',
    color: Color(0xFFE6EE9C),
    fact: 'The oryx has two long, straight horns and can live in hot, '
        'dry places with very little water.',
  ),
  SpeciesInfo(
    keywords: ['sea-lion', 'sea lion', 'sealion'],
    title: 'Sea Lion',
    emoji: '🦭',
    color: Color(0xFF81D4FA),
    fact: 'Sea lions are speedy swimmers and can walk on land using '
        'their flippers. They bark really loudly!',
  ),
  SpeciesInfo(
    keywords: ['bird'],
    title: 'Birds',
    emoji: '🦜',
    color: Color(0xFF4FC3F7),
    fact: 'Birds are the living cousins of dinosaurs! Every bird has '
        'feathers, and most of them can fly.',
  ),
  SpeciesInfo(
    keywords: ['wild beast'],
    title: 'Wild Beasts',
    emoji: '🐾',
    color: Color(0xFFFFB74D),
    fact: 'Wild animals find their own food and make their own homes. '
        'Be very quiet – maybe you can spot one!',
  ),
];

SpeciesInfo? matchSpecies(String name) {
  final n = name.toLowerCase();
  for (final s in kSpecies) {
    for (final k in s.keywords) {
      if (n.contains(k)) return s;
    }
  }
  return null;
}

const String kGenericFact = 'Every animal here has a special home. Look '
    'closely and see what it is doing – can you copy its sound?';

// ---------------------------------------------------------------------------
// 3. DATA MODELS
// ---------------------------------------------------------------------------

enum PlaceKind { animal, toilet, gate, mosque, payment, office }

class ZooPlace {
  const ZooPlace({
    required this.id,
    required this.kind,
    required this.name,
    required this.position,
    this.nameBn,
    this.species,
    this.openingHours,
    this.description,
  });

  final String id;
  final PlaceKind kind;
  final String name;
  final String? nameBn;
  final LatLng position;
  final SpeciesInfo? species;
  final String? openingHours;
  final String? description;

  bool get isAnimal => kind == PlaceKind.animal;

  String get emoji {
    if (species != null) return species!.emoji;
    switch (kind) {
      case PlaceKind.animal:
        return '🐾';
      case PlaceKind.toilet:
        return '🚻';
      case PlaceKind.gate:
        return '🎟️';
      case PlaceKind.mosque:
        return '🕌';
      case PlaceKind.payment:
        return '💳';
      case PlaceKind.office:
        return '🏢';
    }
  }

  Color get color {
    if (species != null) return species!.color;
    switch (kind) {
      case PlaceKind.animal:
        return const Color(0xFFFFB74D);
      case PlaceKind.toilet:
        return Palette.sky;
      case PlaceKind.gate:
        return Palette.primary;
      case PlaceKind.mosque:
        return const Color(0xFF26A69A);
      case PlaceKind.payment:
        return const Color(0xFF9CCC65);
      case PlaceKind.office:
        return Palette.accent;
    }
  }

  String get fact => species?.fact ?? description ?? kGenericFact;

  String get imageSlug => species?.slug ?? slugify(name);

  String get category {
    if (!isAnimal) return 'facility';
    final lower = '$name ${nameBn ?? ''} ${species?.title ?? ''}'.toLowerCase();
    if (lower.contains('tiger') ||
        lower.contains('lion') ||
        lower.contains('leopard') ||
        lower.contains('cheetah') ||
        lower.contains('বাঘ') ||
        lower.contains('সিংহ')) {
      return 'cats';
    }
    if (lower.contains('bird') ||
        lower.contains('flamingo') ||
        lower.contains('peacock') ||
        lower.contains('pelican') ||
        lower.contains('ostrich') ||
        lower.contains('emu') ||
        lower.contains('hornbill') ||
        lower.contains('পাখি') ||
        lower.contains('ময়ূর') ||
        lower.contains('হাঁস') ||
        lower.contains('ধনেশ')) {
      return 'birds';
    }
    if (lower.contains('deer') ||
        lower.contains('giraffe') ||
        lower.contains('elephant') ||
        lower.contains('zebra') ||
        lower.contains('rhino') ||
        lower.contains('hippo') ||
        lower.contains('হরিণ') ||
        lower.contains('হাতি') ||
        lower.contains('জিরাফ') ||
        lower.contains('জলহস্তী') ||
        lower.contains('গণ্ডার') ||
        lower.contains('জেব্রা')) {
      return 'herbivores';
    }
    if (lower.contains('monkey') ||
        lower.contains('chimp') ||
        lower.contains('baboon') ||
        lower.contains('langur') ||
        lower.contains('বানর') ||
        lower.contains('উল্লুক') ||
        lower.contains('শিম্পাঞ্জি')) {
      return 'primates';
    }
    return 'animals';
  }
}

String formatDistance(double meters) {
  if (meters < 1000) {
    return '${meters.round()} মি.';
  } else {
    return '${(meters / 1000).toStringAsFixed(1)} কিমি';
  }
}

String formatWalkingTime(double meters) {
  final minutes = (meters / 65).ceil();
  if (minutes <= 1) return '১ মিনিট হাঁটা';
  return '$minutes মিনিট হাঁটা';
}

class ZooPath {
  const ZooPath({required this.points, required this.isRoad});
  final List<LatLng> points;

  /// `true` for the big outside road, `false` for walking paths inside.
  final bool isRoad;
}

class ZooData {
  const ZooData({
    required this.paths,
    required this.places,
    required this.lakes,
    required this.boundary,
  });

  final List<ZooPath> paths;
  final List<ZooPlace> places;
  final List<List<LatLng>> lakes;
  final List<LatLng> boundary;

  List<ZooPlace> get animals => places.where((p) => p.isAnimal).toList();

  // -------------------------------------------------------------------------
  // 4. GEOJSON PARSER
  // -------------------------------------------------------------------------

  /// Parses the GeoJSON text. Handles Points, LineStrings and Polygons:
  ///  * LineStrings tagged `highway`  -> walking paths
  ///  * Points / polygons tagged as animal cages -> animal markers
  ///    (polygon cages get a marker at their centre)
  ///  * Toilets, gates, mosque, payment points, office -> facility markers
  ///  * Water polygons and the zoo boundary -> map decoration
  static ZooData parse(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    final features = (root['features'] as List).cast<Map<String, dynamic>>();

    final paths = <ZooPath>[];
    final rawPlaces = <ZooPlace>[];
    final lakes = <List<LatLng>>[];
    var boundary = <LatLng>[];

    for (final f in features) {
      final geom = f['geometry'] as Map<String, dynamic>?;
      if (geom == null) continue;
      final props =
          (f['properties'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final id = (f['id'] ?? props['id'] ?? '').toString();
      final type = geom['type'] as String?;
      final coords = geom['coordinates'];

      switch (type) {
        case 'Point':
          final place = _placeFromProps(id, props, _pt(coords));
          if (place != null) rawPlaces.add(place);
          break;

        case 'LineString':
          final pts = _line(coords);
          if (pts.length < 2) break;
          final highway = _s(props, 'highway');
          if (highway != null) {
            paths.add(ZooPath(points: pts, isRoad: highway == 'secondary'));
          } else {
            final place = _placeFromProps(id, props, _centroid(pts));
            if (place != null) rawPlaces.add(place);
          }
          break;

        case 'Polygon':
          final ring = _line((coords as List).first);
          if (ring.length < 3) break;
          if (_s(props, 'natural') == 'water') {
            lakes.add(ring);
          } else if (_s(props, 'tourism') == 'zoo' &&
              _s(props, 'zoo') == 'enclosure') {
            boundary = ring;
          } else {
            final place = _placeFromProps(id, props, _centroid(ring));
            if (place != null) rawPlaces.add(place);
          }
          break;
      }
    }

    return ZooData(
      paths: paths,
      places: _dedupe(rawPlaces),
      lakes: lakes,
      boundary: boundary,
    );
  }

  // --- helpers -------------------------------------------------------------

  static LatLng _pt(dynamic c) =>
      LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()); // [lng, lat]

  static List<LatLng> _line(dynamic c) =>
      (c as List).map<LatLng>((e) => _pt(e)).toList();

  static LatLng _centroid(List<LatLng> pts) {
    var list = pts;
    if (list.length > 1 && list.first == list.last) {
      list = list.sublist(0, list.length - 1);
    }
    var lat = 0.0, lng = 0.0;
    for (final p in list) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / list.length, lng / list.length);
  }

  static String? _s(Map<String, dynamic> props, String key) {
    final v = props[key]?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  static final RegExp _ascii = RegExp(r'^[\x00-\x7F]+$');

  static String _cleanName(String raw) => raw
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceFirst(
        RegExp(r'\s*(cages?|খাঁচা|খাচা|কাচা)$', caseSensitive: false),
        '',
      )
      .trim();

  static ZooPlace? _placeFromProps(
    String id,
    Map<String, dynamic> props,
    LatLng pos,
  ) {
    // --- facilities ---
    if (_s(props, 'amenity') == 'toilets') {
      return ZooPlace(
        id: id,
        kind: PlaceKind.toilet,
        name: 'Washrooms',
        position: pos,
        openingHours: _s(props, 'opening_hours'),
        description: 'Need a break? The washrooms are right here. '
            'Remember to wash your hands afterwards!',
      );
    }
    if (_s(props, 'entrance') == 'main') {
      return ZooPlace(
        id: id,
        kind: PlaceKind.gate,
        name: 'Main Gate',
        position: pos,
        description: 'Welcome to the zoo! This is where your adventure '
            'begins. Stay close to your grown-ups and have fun!',
      );
    }
    if (_s(props, 'amenity') == 'place_of_worship') {
      return ZooPlace(
        id: id,
        kind: PlaceKind.mosque,
        name: 'Zoo Mosque',
        position: pos,
        description: 'A quiet place inside the zoo for prayer and rest.',
      );
    }
    if (_s(props, 'amenity') == 'payment_terminal') {
      return ZooPlace(
        id: id,
        kind: PlaceKind.payment,
        name: 'Payment Point',
        position: pos,
        description: 'Grown-ups can pay here for tickets and services.',
      );
    }
    final rawName = _s(props, 'name');
    if (rawName != null &&
        rawName.toLowerCase().contains('office') &&
        _s(props, 'tourism') == 'zoo') {
      return ZooPlace(
        id: id,
        kind: PlaceKind.office,
        name: "Director's Office",
        position: pos,
        description: 'This is where the zoo managers work to keep all the '
            'animals happy and healthy.',
      );
    }

    // --- animals ---
    final isAnimal = _s(props, 'attraction') == 'animal' ||
        _s(props, 'animal cage') == 'cage';
    if (!isAnimal) return null;

    final nameEn = _s(props, 'name:en');
    final nameBase = _s(props, 'name');
    String? english = nameEn;
    String? bengali = _s(props, 'name:bn');
    if (nameBase != null) {
      if (_ascii.hasMatch(nameBase)) {
        english ??= nameBase;
      } else {
        bengali ??= nameBase;
      }
    }
    if (english == null && bengali == null) return null; // unnamed cage

    final cleaned = _cleanName(english ?? bengali!);
    final species = matchSpecies(cleaned);
    return ZooPlace(
      id: id,
      kind: PlaceKind.animal,
      name: species?.title ?? cleaned,
      nameBn: bengali,
      position: pos,
      species: species,
    );
  }

  /// OpenStreetMap often maps one cage twice (a polygon and a point).
  /// Keep only one marker per species within [kDuplicateDistanceMeters].
  static List<ZooPlace> _dedupe(List<ZooPlace> input) {
    const distance = Distance();
    final result = <ZooPlace>[];
    for (final p in input) {
      final isDuplicate = result.any((q) =>
          q.kind == p.kind &&
          q.name.toLowerCase() == p.name.toLowerCase() &&
          distance.as(LengthUnit.Meter, q.position, p.position) <
              kDuplicateDistanceMeters);
      if (!isDuplicate) {
        result.add(p);
      } else if (p.nameBn != null) {
        // Prefer the copy that carries the Bengali name.
        final i = result.indexWhere((q) =>
            q.kind == p.kind &&
            q.name.toLowerCase() == p.name.toLowerCase() &&
            q.nameBn == null &&
            distance.as(LengthUnit.Meter, q.position, p.position) <
                kDuplicateDistanceMeters);
        if (i >= 0) result[i] = p;
      }
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// 5. APP & MAP PAGE
// ---------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZooGuideApp());
}

class ZooGuideApp extends StatelessWidget {
  const ZooGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.primary,
      secondary: Palette.accent,
      tertiary: Palette.sky,
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Zoo Adventure',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: Palette.background,
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const ZooMapPage(),
    );
  }
}

class ZooMapPage extends StatefulWidget {
  const ZooMapPage({super.key});

  @override
  State<ZooMapPage> createState() => _ZooMapPageState();
}

class _ZooMapPageState extends State<ZooMapPage> {
  final MapController _mapController = MapController();
  late final Future<ZooData> _dataFuture = _loadData();

  bool _showLabels = kInitialZoom >= kLabelZoom;
  bool _showFacilities = true;

  // Live Location & Tracking state
  LatLng? _userLocation;
  double? _userHeading;
  bool _isTracking = false;
  bool _isSimulating = false;
  bool _followUser = false;
  ZooPlace? _navigatingTo;
  StreamSubscription<Position>? _positionSub;

  // Road Routing & Smooth Simulation Engine
  ZooData? _cachedData;
  final ZooGraphRouter _router = ZooGraphRouter();
  final SmoothSimulationEngine _simulationEngine = SmoothSimulationEngine();
  List<LatLng> _navigationRoute = [];
  double? _routeRemainingMeters;

  // Search & Filter state
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _simulationEngine.onLocationUpdate = (position, heading, remainingDist) {
      if (!mounted) return;
      setState(() {
        _userLocation = position;
        _userHeading = heading;
        _routeRemainingMeters = remainingDist;
      });
      if (_followUser) {
        _mapController.move(position, _mapController.camera.zoom);
      }
    };

    _simulationEngine.onDestinationReached = () {
      if (!mounted) return;
      if (_navigatingTo != null) {
        final dest = _navigatingTo!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 আপনি সফলভাবে ${dest.emoji} ${dest.name}-এ পৌঁছে গেছেন!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      setState(() {
        _isSimulating = false;
        _isTracking = false;
        _navigatingTo = null;
        _navigationRoute = [];
        _routeRemainingMeters = null;
      });
    };
  }

  Future<ZooData> _loadData() async {
    final text = await rootBundle.loadString(kGeoJsonAsset);
    final data = ZooData.parse(text);
    _cachedData = data;
    _router.buildGraph(data.paths.map((p) => p.points).toList());
    return data;
  }

  void _zoomBy(double delta) {
    final cam = _mapController.camera;
    _mapController.move(cam.center, cam.zoom + delta);
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    final show = camera.zoom >= kLabelZoom;
    if (show != _showLabels) setState(() => _showLabels = show);
    if (hasGesture && _followUser) {
      setState(() => _followUser = false);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _simulationEngine.stop();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // --- Location & Simulation Methods ---

  Future<void> _toggleLiveGps() async {
    if (_isTracking && !_isSimulating) {
      if (!_followUser && _userLocation != null) {
        setState(() => _followUser = true);
        _mapController.move(_userLocation!, 17.5);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 ক্যামেরা আপনার অবস্থানে কেন্দ্র করা হয়েছে (Auto-Follow অন)'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      _stopTracking();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🛰️ লাইভ GPS ট্র্যাকিং বন্ধ করা হয়েছে')),
      );
      return;
    }

    _stopTracking();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ ডিভাইসের GPS বন্ধ আছে। অন করুন অথবা সিমুলেশন চালান।'),
            action: SnackBarAction(
              label: 'সিমুলেশন মোড',
              onPressed: _startSimulation,
            ),
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⚠️ লোকেশন পারমিশন দেওয়া হয়নি।'),
              action: SnackBarAction(
                label: 'সিমুলেশন টেস্ট',
                onPressed: _startSimulation,
              ),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ লোকেশন পারমিশন ব্লক করা আছে।'),
            action: SnackBarAction(
              label: 'সিমুলেশন টেস্ট',
              onPressed: _startSimulation,
            ),
          ),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final userLatLng = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _userLocation = userLatLng;
        _userHeading = pos.heading;
        _isTracking = true;
        _isSimulating = false;
        _followUser = true;
      });

      _mapController.move(userLatLng, 17.5);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛰️ লাইভ GPS চালু হয়েছে! আপনার অবস্থান ট্র্যাকিং হচ্ছে।'),
          backgroundColor: Palette.gpsBlue,
        ),
      );

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).listen((p) {
        if (!mounted) return;
        setState(() {
          _userLocation = LatLng(p.latitude, p.longitude);
          _userHeading = p.heading;
        });
        if (_followUser) {
          _mapController.move(_userLocation!, _mapController.camera.zoom);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GPS সমস্যা: $e'),
          action: SnackBarAction(
            label: 'সিমুলেশন মোড',
            onPressed: _startSimulation,
          ),
        ),
      );
    }
  }

  void _startSimulation() {
    _stopTracking();

    // Simulation starts from the Zoo Main Gate
    final gatePos = _cachedData?.places
            .where((p) => p.kind == PlaceKind.gate)
            .firstOrNull
            ?.position ??
        kZooGate;
    final start = gatePos;
    List<LatLng> route;

    if (_navigatingTo != null) {
      route = _router.findPath(start, _navigatingTo!.position);
      _navigationRoute = route;
    } else {
      // Clean tour loop without looping back-and-forth
      const tourWaypoints = [
        LatLng(23.812549, 90.346991), // Main gate
        LatLng(23.8135, 90.3475),     // Central junction
        LatLng(23.8158, 90.3473),     // Tiger area
        LatLng(23.8156, 90.3457),     // Carnivores
        LatLng(23.8136, 90.3459),     // Monkeys
        LatLng(23.812549, 90.346991), // Back to Main gate
      ];
      final scenicPoints = <LatLng>[];
      for (int i = 0; i < tourWaypoints.length - 1; i++) {
        final segment = _router.findPath(tourWaypoints[i], tourWaypoints[i + 1]);
        if (scenicPoints.isEmpty) {
          scenicPoints.addAll(segment);
        } else if (segment.isNotEmpty) {
          scenicPoints.addAll(segment.skip(1));
        }
      }
      route = scenicPoints.length >= 2 ? scenicPoints : tourWaypoints;
      _navigationRoute = []; // Blue line is NOT shown during tour simulation
    }

    if (route.length < 2) return;

    final initialHeading = SmoothSimulationEngine.calculateBearing(route[0], route[1]);

    setState(() {
      _isTracking = true;
      _isSimulating = true;
      _userLocation = start;
      _userHeading = initialHeading;
      _followUser = true;
    });

    _mapController.move(start, 17.5);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚶‍♂️ মেইন গেট থেকে ভার্চুয়াল চিড়িয়াখানা ভ্রমণ সিমুলেশন চালু হয়েছে!'),
        backgroundColor: Palette.primary,
        duration: Duration(seconds: 2),
      ),
    );

    _simulationEngine.speedMultiplier = 8.5; // Fast and smooth simulation
    _simulationEngine.startRoute(route, startPos: start, loop: _navigatingTo == null);
  }

  void _stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _simulationEngine.stop();

    final gatePos = _cachedData?.places
            .where((p) => p.kind == PlaceKind.gate)
            .firstOrNull
            ?.position ??
        kZooGate;

    setState(() {
      _isTracking = false;
      _isSimulating = false;
      _followUser = false;
      _navigatingTo = null;
      _navigationRoute = [];
      _routeRemainingMeters = null;
      // When simulation is turned off, the point automatically moves back to Main Gate!
      _userLocation = gatePos;
      _userHeading = 0.0;
    });

    _mapController.move(gatePos, _mapController.camera.zoom);
  }

  void _startNavigation(ZooPlace place) {
    final gatePos = _cachedData?.places
            .where((p) => p.kind == PlaceKind.gate)
            .firstOrNull
            ?.position ??
        kZooGate;
    // Start from wherever the point currently is!
    final start = _userLocation ?? gatePos;
    final roadPath = _router.findPath(start, place.position);

    // Stop previous movement without resetting location
    _simulationEngine.stop();

    final initialHeading = roadPath.length >= 2
        ? SmoothSimulationEngine.calculateBearing(roadPath[0], roadPath[1])
        : (_userHeading ?? 0.0);

    setState(() {
      _navigatingTo = place;
      _navigationRoute = roadPath;
      _isTracking = true;
      _isSimulating = true;
      _userLocation = start;
      _userHeading = initialHeading;
      _followUser = true;
    });

    _mapController.move(start, 17.5);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🧭 ${place.emoji} ${place.name}-এ যাওয়ার রাস্তা ধরে সিমুলেশন শুরু হয়েছে!'),
        backgroundColor: Palette.accent,
        duration: const Duration(seconds: 3),
      ),
    );

    _simulationEngine.speedMultiplier = 8.5; // Fast and smooth simulation
    _simulationEngine.startRoute(roadPath, startPos: start, loop: false);
  }

  void _stopNavigation() {
    _stopTracking();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<ZooData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingView();
          }
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error.toString());
          }
          return _buildMap(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildMap(ZooData data) {
    // Filter places based on Category and Search
    final places = data.places.where((p) {
      if (!_showFacilities && !p.isAnimal) return false;

      // Category filter
      if (_selectedCategory == 'cats' && p.category != 'cats') return false;
      if (_selectedCategory == 'birds' && p.category != 'birds') return false;
      if (_selectedCategory == 'herbivores' && p.category != 'herbivores') return false;
      if (_selectedCategory == 'primates' && p.category != 'primates') return false;
      if (_selectedCategory == 'animals' && !p.isAnimal) return false;
      if (_selectedCategory == 'facility' && p.isAnimal) return false;

      // Search filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = p.name.toLowerCase().contains(q) ||
            (p.nameBn?.contains(q) ?? false) ||
            (p.species?.keywords.any((k) => k.contains(q)) ?? false);
        if (!match) return false;
      }
      return true;
    }).toList(growable: false);

    // Active navigation distance calculation (uses exact road network distance)
    double? navDistance = _routeRemainingMeters;
    if (navDistance == null && _navigatingTo != null && _userLocation != null) {
      navDistance = const Distance().as(
        LengthUnit.Meter,
        _userLocation!,
        _navigatingTo!.position,
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: kZooCenter,
            initialZoom: kInitialZoom,
            minZoom: 14.5,
            maxZoom: 20,
            backgroundColor: Palette.background,
            onPositionChanged: _onMapMoved,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            // Zoo grounds + lakes
            PolygonLayer(
              polygons: [
                if (data.boundary.isNotEmpty)
                  Polygon(
                    points: data.boundary,
                    color: Palette.zooGround,
                    borderColor: Palette.zooBorder,
                    borderStrokeWidth: 4,
                  ),
                for (final lake in data.lakes)
                  Polygon(
                    points: lake,
                    color: Palette.water,
                    borderColor: Palette.waterBorder,
                    borderStrokeWidth: 3,
                  ),
              ],
            ),
            // Roads & Paths
            PolylineLayer(
              polylines: [
                for (final path in data.paths.where((p) => p.isRoad))
                  Polyline(
                    points: path.points,
                    strokeWidth: 14,
                    color: Palette.road,
                    borderColor: Palette.roadBorder,
                    borderStrokeWidth: 2,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                for (final path in data.paths.where((p) => !p.isRoad))
                  Polyline(
                    points: path.points,
                    strokeWidth: 9,
                    color: Palette.pathFill,
                    borderColor: Palette.pathBorder,
                    borderStrokeWidth: 2.5,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                // Active Navigation Route Line (ONLY when guiding to a selected place)
                if (_navigatingTo != null && _navigationRoute.length >= 2) ...[
                  Polyline(
                    points: _navigationRoute,
                    strokeWidth: 8,
                    color: Colors.white.withOpacity(0.9),
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                  Polyline(
                    points: _navigationRoute,
                    strokeWidth: 5,
                    color: Palette.accent,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ],
            ),
            // Markers
            MarkerLayer(
              markers: [
                // Animal & Facility Markers
                for (final place in places)
                  Marker(
                    point: place.position,
                    width: _showLabels ? 112 : 50,
                    height: _showLabels ? 78 : 50,
                    child: PlaceMarker(
                      place: place,
                      showLabel: _showLabels,
                      isTarget: _navigatingTo?.id == place.id,
                      onTap: () => showPlaceSheet(
                        context,
                        place,
                        userLocation: _userLocation,
                        onGuideMe: () => _startNavigation(place),
                      ),
                    ),
                  ),
                // Live User Location Marker
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 70,
                    height: 70,
                    child: UserLocationMarker(
                      heading: _userHeading,
                      isSimulating: _isSimulating,
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Top Header: Title, Live Status & Search
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopHeaderBar(
                    animalCount: data.animals.length,
                    isTracking: _isTracking,
                    isSimulating: _isSimulating,
                    onSearchTap: () => setState(() => _isSearchOpen = !_isSearchOpen),
                  ),
                  if (_isSearchOpen) ...[
                    const SizedBox(height: 8),
                    _SearchBarWidget(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      onClose: () => setState(() {
                        _isSearchOpen = false;
                        _searchQuery = '';
                        _searchController.clear();
                      }),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterPill(
                          label: '🌟 সকল',
                          selected: _selectedCategory == 'all',
                          onTap: () => setState(() => _selectedCategory = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: '🐯 বাঘ ও সিংহ',
                          selected: _selectedCategory == 'cats',
                          onTap: () => setState(() => _selectedCategory = 'cats'),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: '🦒 হরিণ ও অন্যান্য',
                          selected: _selectedCategory == 'herbivores',
                          onTap: () => setState(() => _selectedCategory = 'herbivores'),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: '🦜 পাখি',
                          selected: _selectedCategory == 'birds',
                          onTap: () => setState(() => _selectedCategory = 'birds'),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: '🐒 বানর',
                          selected: _selectedCategory == 'primates',
                          onTap: () => setState(() => _selectedCategory = 'primates'),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: '🚻 সুবিধা',
                          selected: _showFacilities,
                          onTap: () => setState(() => _showFacilities = !_showFacilities),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Active Navigation HUD (When guiding to a target)
        if (_navigatingTo != null && navDistance != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: _NavigationHud(
                place: _navigatingTo!,
                distance: navDistance,
                onStop: _stopNavigation,
              ),
            ),
          ),

        // Floating Control Buttons (Right Side)
        Positioned(
          right: 16,
          bottom: (_navigatingTo != null) ? 115 : 24,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live GPS Button
                _RoundButton(
                  icon: _isTracking && !_isSimulating
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  tooltip: _isTracking && !_isSimulating
                      ? 'GPS সক্রিয় (বন্ধ করতে চাপুন)'
                      : 'লাইভ GPS ট্র্যাকিং চালু করুন',
                  color: _isTracking && !_isSimulating ? Palette.gpsBlue : Colors.white,
                  iconColor: _isTracking && !_isSimulating ? Colors.white : Palette.gpsBlue,
                  onPressed: _toggleLiveGps,
                ),
                const SizedBox(height: 10),

                // Tour Simulation Button
                _RoundButton(
                  icon: _isSimulating
                      ? Icons.directions_walk_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: _isSimulating
                      ? 'সিমুলেশন চলছে (বন্ধ করতে চাপুন)'
                      : 'চিড়িয়াখানা ভার্চুয়াল ভ্রমণ সিমুলেশন',
                  color: _isSimulating ? Palette.primary : Colors.white,
                  iconColor: _isSimulating ? Colors.white : Palette.primary,
                  onPressed: _isSimulating ? _stopTracking : _startSimulation,
                ),
                const SizedBox(height: 10),

                // Zoom in
                _RoundButton(
                  icon: Icons.add_rounded,
                  tooltip: 'জুম ইন (+)',
                  onPressed: () => _zoomBy(1),
                ),
                const SizedBox(height: 10),

                // Zoom out
                _RoundButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'জুম আউট (-)',
                  onPressed: () => _zoomBy(-1),
                ),
                const SizedBox(height: 10),

                // Center Zoo Home
                _RoundButton(
                  icon: Icons.home_rounded,
                  tooltip: 'চিড়িয়াখানা কেন্দ্র',
                  color: Palette.accent,
                  iconColor: Colors.white,
                  onPressed: () => _mapController.move(kZooCenter, kInitialZoom),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 6. HEADER, HUD & BUTTONS
// ---------------------------------------------------------------------------

class _TopHeaderBar extends StatelessWidget {
  const _TopHeaderBar({
    required this.animalCount,
    required this.isTracking,
    required this.isSimulating,
    required this.onSearchTap,
  });

  final int animalCount;
  final bool isTracking;
  final bool isSimulating;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Palette.ink.withOpacity(0.15), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/logo.png',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Palette.primary, Color(0xFFFFB300)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text('🐯', style: TextStyle(fontSize: 24)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Zoo Adventure',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                  ),
                ),
                Row(
                  children: [
                    if (isTracking) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSimulating ? Palette.primary : Palette.gpsBlue,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isSimulating ? 'সিমুলেশন মোড 🚶‍♂️' : 'লাইভ GPS ট্র্যাকিং 🛰️',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSimulating ? Palette.primary : Palette.gpsBlue,
                        ),
                      ),
                    ] else
                      Text(
                        'মিরপুর জাতীয় চিড়িয়াখানা • $animalCount প্রাণী',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Palette.ink.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSearchTap,
            icon: const Icon(Icons.search_rounded, color: Palette.ink, size: 26),
            tooltip: 'প্রাণী খুঁজুন',
          ),
        ],
      ),
    );
  }
}

class _SearchBarWidget extends StatelessWidget {
  const _SearchBarWidget({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.primary, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.ink),
        decoration: InputDecoration(
          hintText: 'খুঁজুন (যেমন: বাঘ, হরিণ, Tiger, সিংহ)...',
          border: InputBorder.none,
          icon: const Icon(Icons.search, color: Palette.primary),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close_rounded, color: Palette.ink),
            onPressed: onClose,
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Palette.ink : Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: selected ? 3 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Palette.ink : Palette.ink.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : Palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationHud extends StatelessWidget {
  const _NavigationHud({
    required this.place,
    required this.distance,
    required this.onStop,
  });

  final ZooPlace place;
  final double distance;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Palette.paper,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Palette.accent, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: place.color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(place.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                  ),
                ),
                Text(
                  'দূরত্ব: ${formatDistance(distance)} • ${formatWalkingTime(distance)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Palette.accent,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onStop,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('বন্ধ ✕', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = Colors.white,
    this.iconColor = Palette.ink,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 5,
      shape: const CircleBorder(
        side: BorderSide(color: Palette.ink, width: 2),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 50,
            height: 50,
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🐘', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          CircularProgressIndicator(color: Palette.primary),
          SizedBox(height: 16),
          Text(
            'চিড়িয়াখানা লোড হচ্ছে…',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Palette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🙈', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            const Text(
              'ম্যাপ লোড করা যায়নি',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Palette.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.ink),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. MARKERS & USER LOCATION PULSE
// ---------------------------------------------------------------------------

class UserLocationMarker extends StatefulWidget {
  const UserLocationMarker({
    super.key,
    required this.heading,
    required this.isSimulating,
  });

  final double? heading;
  final bool isSimulating;

  @override
  State<UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSimulating ? Palette.primary : Palette.gpsBlue;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final progress = _anim.value;
        final waveRadius = 18.0 + (progress * 26.0);
        final waveOpacity = (1.0 - progress).clamp(0.0, 1.0) * 0.45;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Radar pulse ring
            Container(
              width: waveRadius * 2,
              height: waveRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(waveOpacity),
                border: Border.all(
                  color: color.withOpacity(waveOpacity * 1.5),
                  width: 1.5,
                ),
              ),
            ),
            // Heading arrow if available
            if (widget.heading != null)
              Transform.rotate(
                angle: widget.heading! * (math.pi / 180.0),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: Icon(
                    Icons.navigation_rounded,
                    color: color,
                    size: 16,
                  ),
                ),
              ),
            // Core user pin
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PlaceMarker extends StatelessWidget {
  const PlaceMarker({
    super.key,
    required this.place,
    required this.showLabel,
    required this.onTap,
    this.isTarget = false,
  });

  final ZooPlace place;
  final bool showLabel;
  final VoidCallback onTap;
  final bool isTarget;

  @override
  Widget build(BuildContext context) {
    final bubbleSize = place.isAnimal ? 46.0 : 40.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: isTarget ? scale * 1.25 : scale, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: bubbleSize,
              height: bubbleSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: place.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isTarget ? Colors.yellowAccent : Colors.white,
                  width: isTarget ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isTarget ? Palette.accent.withOpacity(0.6) : const Color(0x55000000),
                    blurRadius: isTarget ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                place.emoji,
                style: TextStyle(fontSize: place.isAnimal ? 24 : 20),
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: place.color, width: 1.5),
                ),
                child: Text(
                  place.nameBn ?? place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Palette.ink,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 8. BOTTOM SHEET
// ---------------------------------------------------------------------------

void showPlaceSheet(
  BuildContext context,
  ZooPlace place, {
  LatLng? userLocation,
  VoidCallback? onGuideMe,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black38,
    builder: (_) => PlaceSheet(
      place: place,
      userLocation: userLocation,
      onGuideMe: onGuideMe,
    ),
  );
}

class PlaceSheet extends StatefulWidget {
  const PlaceSheet({
    super.key,
    required this.place,
    this.userLocation,
    this.onGuideMe,
  });

  final ZooPlace place;
  final LatLng? userLocation;
  final VoidCallback? onGuideMe;

  @override
  State<PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<PlaceSheet> {
  bool _playing = false;

  void _toggleAudio() {
    SystemSound.play(SystemSoundType.click);
    setState(() => _playing = !_playing);
    if (_playing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('${widget.place.emoji} ${widget.place.name}-এর ডাক শুনুন!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final color = place.color;

    // Calculate distance if user location is available
    double? distance;
    if (widget.userLocation != null) {
      distance = const Distance().as(
        LengthUnit.Meter,
        widget.userLocation!,
        place.position,
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Palette.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Palette.ink.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Placeholder image (emoji) / Real image
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  height: 190,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.55),
                        color,
                      ],
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        right: -10,
                        top: -10,
                        child: Text(
                          '✨',
                          style: TextStyle(
                            fontSize: 70,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          place.emoji,
                          style: const TextStyle(fontSize: 96),
                        ),
                      ),
                      Image.asset(
                        'assets/images/animals/${place.imageSlug}.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Name
              Text(
                place.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Palette.ink,
                ),
              ),
              if (place.nameBn != null) ...[
                const SizedBox(height: 2),
                Text(
                  place.nameBn!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Palette.ink.withOpacity(0.7),
                  ),
                ),
              ],

              // Distance Badge if GPS / Location is available
              if (distance != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Palette.gpsBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Palette.gpsBlue.withOpacity(0.4), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.near_me_rounded, color: Palette.gpsBlue, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'দূরত্ব: ${formatDistance(distance)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Palette.ink,
                              ),
                            ),
                            Text(
                              '${formatWalkingTime(distance)} (চিড়িয়াখানার ভেতর)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Palette.ink.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onGuideMe != null)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onGuideMe!();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Palette.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.directions_walk_rounded, size: 18),
                          label: const Text('যাও 🧭', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                ),
              ],

              if (place.openingHours != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Chip(
                    avatar: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(place.openingHours!),
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Fun Fact / Information Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: color, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Text(
                          place.isAnimal ? 'মজার তথ্য (Fun Fact)!' : 'দরকারী তথ্য!',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Palette.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      place.fact,
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: Palette.ink,
                      ),
                    ),
                  ],
                ),
              ),

              // Audio Button (animals only)
              if (place.isAnimal) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _toggleAudio,
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  icon: Icon(
                    _playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.volume_up_rounded,
                    size: 28,
                  ),
                  label: Text(_playing ? 'ডাক বাজছে…' : 'Play Animal Sound 🔊'),
                ),
              ],

              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'ম্যাপে ফিরে যান 🗺️',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Palette.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

