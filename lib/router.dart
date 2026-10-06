import 'package:latlong2/latlong.dart';

class ZooGraphRouter {
  final List<LatLng> _nodes = [];
  final Map<int, List<_Edge>> _adjacency = {};
  final Distance _distance = const Distance();

  bool get isReady => _nodes.isNotEmpty;
  int get nodeCount => _nodes.length;

  /// Builds a navigable road graph from the given polyline paths.
  /// Points closer than [mergeDistanceMeters] are merged into the same graph junction node.
  void buildGraph(List<List<LatLng>> paths, {double mergeDistanceMeters = 5.0}) {
    _nodes.clear();
    _adjacency.clear();

    int getOrCreateNode(LatLng point) {
      for (int i = 0; i < _nodes.length; i++) {
        if (_distance.as(LengthUnit.Meter, _nodes[i], point) <= mergeDistanceMeters) {
          return i;
        }
      }
      final newId = _nodes.length;
      _nodes.add(point);
      _adjacency[newId] = [];
      return newId;
    }

    for (final path in paths) {
      for (int i = 0; i < path.length - 1; i++) {
        final u = getOrCreateNode(path[i]);
        final v = getOrCreateNode(path[i + 1]);
        if (u != v) {
          final d = _distance.as(LengthUnit.Meter, _nodes[u], _nodes[v]);
          _adjacency[u]!.add(_Edge(targetNode: v, distance: d));
          _adjacency[v]!.add(_Edge(targetNode: u, distance: d));
        }
      }
    }
  }

  int _findNearestNode(LatLng point) {
    if (_nodes.isEmpty) return -1;
    int bestNode = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < _nodes.length; i++) {
      final d = _distance.as(LengthUnit.Meter, _nodes[i], point);
      if (d < bestDist) {
        bestDist = d;
        bestNode = i;
      }
    }
    return bestNode;
  }

  /// Calculates the shortest walkable path along the zoo footpaths
  /// from [start] to [destination] using Dijkstra algorithm.
  List<LatLng> findPath(LatLng start, LatLng destination) {
    if (_nodes.isEmpty) {
      return [start, destination];
    }

    final startNode = _findNearestNode(start);
    final destNode = _findNearestNode(destination);

    if (startNode == -1 || destNode == -1 || startNode == destNode) {
      return [start, destination];
    }

    final distMap = <int, double>{};
    final prevMap = <int, int?>{};
    final unvisited = <int>{};

    for (int i = 0; i < _nodes.length; i++) {
      distMap[i] = double.infinity;
      unvisited.add(i);
    }
    distMap[startNode] = 0;

    while (unvisited.isNotEmpty) {
      int? current;
      double lowest = double.infinity;
      for (final n in unvisited) {
        final d = distMap[n]!;
        if (d < lowest) {
          lowest = d;
          current = n;
        }
      }

      if (current == null || lowest == double.infinity) break;
      if (current == destNode) break;

      unvisited.remove(current);

      for (final edge in _adjacency[current] ?? const []) {
        if (!unvisited.contains(edge.targetNode)) continue;
        final alt = lowest + edge.distance;
        if (alt < distMap[edge.targetNode]!) {
          distMap[edge.targetNode] = alt;
          prevMap[edge.targetNode] = current;
        }
      }
    }

    if (distMap[destNode] == double.infinity) {
      return [start, destination];
    }

    final path = <LatLng>[];
    int? curr = destNode;
    while (curr != null) {
      path.add(_nodes[curr]);
      if (curr == startNode) break;
      curr = prevMap[curr];
    }

    final reversed = path.reversed.toList();

    // Prevent turning backwards if start is already closer to the next node
    if (reversed.length >= 2) {
      final distToFirst = _distance.as(LengthUnit.Meter, start, reversed[0]);
      final distToSecond = _distance.as(LengthUnit.Meter, start, reversed[1]);
      final distBetweenNodes = _distance.as(LengthUnit.Meter, reversed[0], reversed[1]);
      if (distToSecond < distBetweenNodes || distToFirst < 2.0) {
        reversed.removeAt(0);
      }
    }

    final result = <LatLng>[start];
    result.addAll(reversed);
    result.add(destination);

    return _cleanRoute(result);
  }

  List<LatLng> _cleanRoute(List<LatLng> raw) {
    if (raw.length <= 2) return raw;
    final cleaned = <LatLng>[raw.first];
    for (int i = 1; i < raw.length; i++) {
      if (_distance.as(LengthUnit.Meter, cleaned.last, raw[i]) > 1.2) {
        cleaned.add(raw[i]);
      }
    }
    return cleaned;
  }
}

class _Edge {
  final int targetNode;
  final double distance;
  const _Edge({required this.targetNode, required this.distance});
}
