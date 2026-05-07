class GpsPoint {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? distance;
  final double? heartRate;
  
  GpsPoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.distance,
    this.heartRate,
  });
  
  double? paceInSeconds() {
    if (speed == null || speed == 0) return null;
    return 1000 / speed!;
  }
  
  String paceFormatted() {
    final paceSeconds = paceInSeconds();
    if (paceSeconds == null) return '--';
    final minutes = (paceSeconds / 60).floor();
    final seconds = (paceSeconds % 60).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'speed': speed,
    'distance': distance,
    'heartRate': heartRate,
  };
}