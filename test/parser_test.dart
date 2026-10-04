import 'package:flutter_test/flutter_test.dart';
import 'package:mirpur_zoo_guide/main.dart';

const _sample = '''
{
  "type": "FeatureCollection",
  "features": [
    {"type":"Feature","id":"node/1",
     "geometry":{"type":"Point","coordinates":[90.3473,23.8158]},
     "properties":{"attraction":"animal","name":"Royal Bengal Tiger Cage","name:bn":"বাঘের খাচা"}},
    {"type":"Feature","id":"node/2",
     "geometry":{"type":"Point","coordinates":[90.3469,23.8120]},
     "properties":{"amenity":"toilets"}},
    {"type":"Feature","id":"way/3",
     "geometry":{"type":"LineString","coordinates":[[90.34,23.81],[90.341,23.811]]},
     "properties":{"highway":"service"}},
    {"type":"Feature","id":"way/4",
     "geometry":{"type":"Polygon","coordinates":[[[90.3420,23.8130],[90.3421,23.8130],[90.3421,23.8131],[90.3420,23.8131],[90.3420,23.8130]]]},
     "properties":{"attraction":"animal","name:en":"Giraffe Cage"}},
    {"type":"Feature","id":"node/5",
     "geometry":{"type":"Point","coordinates":[90.34205,23.81305]},
     "properties":{"attraction":"animal","name":"Giraffe Cage"}}
  ]
}
''';

void main() {
  test('parses paths, animals and facilities, and removes duplicates', () {
    final data = ZooData.parse(_sample);

    expect(data.paths.length, 1);
    expect(data.paths.first.isRoad, isFalse);

    // Tiger + one giraffe (polygon and point are duplicates) + toilets.
    expect(data.animals.length, 2);
    expect(data.places.length, 3);

    final tiger = data.animals.firstWhere((p) => p.name == 'Royal Bengal Tiger');
    expect(tiger.nameBn, isNotNull);
    expect(tiger.position.latitude, closeTo(23.8158, 1e-6));
    expect(tiger.position.longitude, closeTo(90.3473, 1e-6));
  });
}
