import 'dart:async';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Smooth Walking Simulation Engine.
/// Replaces abrupt jumps with smooth, step-by-step human walking movement (25 FPS)
/// along any given route with realistic walking speed and smooth compass heading.
class SmoothSimulationEngine {
  Timer? _ticker;
  List<LatLng> _route = [];
  int _currentIndex = 0;
  LatLng? _currentPosition;
  double _currentHeading = 0.0;
  bool _loop = false;
  bool _isPaused = false;

  /// Real-world human walking speed: ~1.4 meters/second (~5 km/h).
  final double baseSpeedMps;

  /// Speed multiplier (1.0 = real walking, 2.0 = brisk walk, 3.0 = jogging/fast preview).
  double speedMultiplier = 1.5;

  /// 40 ms per tick = 25 frames per second for ultra-smooth rendering.
  static const int tickMs = 40;

  final Distance _distance = const Distance();

  // Callbacks
  void Function(LatLng position, double heading, double remainingDistanceMeters)? onLocationUpdate;
  void Function()? onDestinationReached;

  SmoothSimulationEngine({this.baseSpeedMps = 1.4});

  bool get isRunning => _ticker != null && !_isPaused;
  bool get isPaused => _isPaused;
  LatLng? get currentPosition => _currentPosition;
  double get currentHeading => _currentHeading;

  /// Starts or restarts simulation along a designated route.
  void startRoute(
    List<LatLng> route, {
    LatLng? startPos,
    bool loop = false,
  }) {
    stop();
    if (route.length < 2) return;

    _route = List.from(route);
    _loop = loop;
    _currentIndex = 0;
    _currentPosition = startPos ?? _route.first;
    _isPaused = false;

    // Calculate initial heading towards first waypoint
    _currentHeading = calculateBearing(_currentPosition!, _route[1]);

    _ticker = Timer.periodic(const Duration(milliseconds: tickMs), (_) {
      _tick();
    });
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _isPaused = false;
    _route.clear();
    _currentIndex = 0;
  }

  void _tick() {
    if (_isPaused || _currentPosition == null || _route.isEmpty) return;

    final targetIndex = _currentIndex + 1;
    if (targetIndex >= _route.length) {
      if (_loop && _route.length >= 2) {
        _currentIndex = 0;
        _currentPosition = _route.first;
        return;
      } else {
        stop();
        onDestinationReached?.call();
        return;
      }
    }

    final targetPoint = _route[targetIndex];
    final distToTarget = _distance.as(LengthUnit.Meter, _currentPosition!, targetPoint);

    // Distance covered in this single frame (e.g. 1.4 m/s * 1.5 * 0.04s = ~0.084 meters)
    final stepDistance = baseSpeedMps * speedMultiplier * (tickMs / 1000.0);

    // Target bearing towards next waypoint
    final targetHeading = calculateBearing(_currentPosition!, targetPoint);
    _currentHeading = _lerpAngle(_currentHeading, targetHeading, 0.2);

    if (distToTarget <= stepDistance) {
      // Reached this waypoint, step to the next one
      _currentPosition = targetPoint;
      _currentIndex++;
      if (_currentIndex >= _route.length - 1) {
        if (_loop) {
          _currentIndex = 0;
          _currentPosition = _route.first;
        } else {
          stop();
          onDestinationReached?.call();
          return;
        }
      }
    } else {
      // Linear interpolation between current position and target waypoint
      final fraction = stepDistance / distToTarget;
      final newLat = _currentPosition!.latitude +
          (targetPoint.latitude - _currentPosition!.latitude) * fraction;
      final newLng = _currentPosition!.longitude +
          (targetPoint.longitude - _currentPosition!.longitude) * fraction;
      _currentPosition = LatLng(newLat, newLng);
    }

    // Calculate total remaining distance along the route
    final remainingDist = _calculateRemainingDistance();

    onLocationUpdate?.call(_currentPosition!, _currentHeading, remainingDist);
  }

  double _calculateRemainingDistance() {
    if (_currentPosition == null || _currentIndex + 1 >= _route.length) return 0.0;
    double dist = _distance.as(LengthUnit.Meter, _currentPosition!, _route[_currentIndex + 1]);
    for (int i = _currentIndex + 1; i < _route.length - 1; i++) {
      dist += _distance.as(LengthUnit.Meter, _route[i], _route[i + 1]);
    }
    return dist;
  }

  /// Calculates initial compass bearing in degrees (0..360) from [start] to [end].
  static double calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitudeInRad;
    final lon1 = start.longitudeInRad;
    final lat2 = end.latitudeInRad;
    final lon2 = end.longitudeInRad;

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final radians = math.atan2(y, x);
    return (radians * 180 / math.pi + 360) % 360;
  }

  /// Smoothly interpolates angles with proper 0-360 wraparound.
  static double _lerpAngle(double current, double target, double t) {
    var diff = (target - current) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (current + diff * t) % 360;
  }
}
