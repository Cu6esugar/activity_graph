import 'gps_point.dart';

class FitData {
  final List<GpsPoint> gpsPoints;
  final DateTime? startTime;
  final DateTime? endTime;
  final double totalDistance;
  final double totalDurationSeconds;
  final String? activityType;
  
  FitData({
    required this.gpsPoints,
    this.startTime,
    this.endTime,
    this.totalDistance = 0,
    this.totalDurationSeconds = 0,
    this.activityType,
  });
  
  GpsPoint? findPointAtTime(DateTime targetTime) {
    print('\n=== GPS Matching Debug ===');
    print('Target time (image): $targetTime');
    
    if (gpsPoints.isEmpty) {
      print('GPS points list is empty - no match possible');
      print('=== Matching Debug End ===\n');
      return null;
    }
    
    print('GPS points count: ${gpsPoints.length}');
    print('GPS time range: ${gpsPoints.first.timestamp} to ${gpsPoints.last.timestamp}');
    
    final tolerance = Duration(seconds: 5);
    
    for (final point in gpsPoints) {
      final diff = point.timestamp.difference(targetTime).abs();
      if (diff <= tolerance) {
        print('Found exact match within ${tolerance.inSeconds}s tolerance:');
        print('  Matched point time: ${point.timestamp}');
        print('  Time difference: ${diff.inSeconds}s');
        print('  Lat: ${point.latitude.toStringAsFixed(6)}');
        print('  Lon: ${point.longitude.toStringAsFixed(6)}');
        if (point.speed != null) {
          print('  Speed: ${point.speed!.toStringAsFixed(2)} m/s');
          print('  Pace: ${point.paceFormatted()} min/km');
        }
        print('=== Matching Debug End ===\n');
        return point;
      }
    }
    
    print('No exact match within tolerance, finding closest point...');
    
    int closestIndex = 0;
    Duration smallestDiff = gpsPoints[0].timestamp.difference(targetTime).abs();
    
    for (int i = 1; i < gpsPoints.length; i++) {
      final diff = gpsPoints[i].timestamp.difference(targetTime).abs();
      if (diff < smallestDiff) {
        smallestDiff = diff;
        closestIndex = i;
      }
    }
    
    final closestPoint = gpsPoints[closestIndex];
    print('Closest point found at index $closestIndex:');
    print('  Point time: ${closestPoint.timestamp}');
    print('  Time difference: ${smallestDiff.inSeconds}s (${smallestDiff.inMinutes}min)');
    print('  Lat: ${closestPoint.latitude.toStringAsFixed(6)}');
    print('  Lon: ${closestPoint.longitude.toStringAsFixed(6)}');
    
    if (smallestDiff > Duration(minutes: 30)) {
      print('WARNING: Time difference is more than 30 minutes!');
      print('This might indicate timezone mismatch or wrong file selection');
    }
    
    print('=== Matching Debug End ===\n');
    return closestPoint;
  }
  
  List<GpsPoint> getPointsInRange(DateTime start, DateTime end) {
    return gpsPoints.where((point) =>
      point.timestamp.isAfter(start) && point.timestamp.isBefore(end)
    ).toList();
  }
  
  double calculateAveragePace() {
    if (totalDistance == 0 || totalDurationSeconds == 0) return 0;
    return totalDurationSeconds / (totalDistance / 1000);
  }
  
  String formatTotalDuration() {
    final hours = (totalDurationSeconds / 3600).floor();
    final minutes = ((totalDurationSeconds % 3600) / 60).floor();
    final seconds = (totalDurationSeconds % 60).floor();
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  String formatTotalDistance() {
    if (totalDistance < 1000) {
      return '${totalDistance.toStringAsFixed(0)}m';
    }
    return '${(totalDistance / 1000).toStringAsFixed(2)}km';
  }
}