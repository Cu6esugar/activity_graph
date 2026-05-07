import 'package:fit_parser/fit_parser.dart';
import '../models/gps_point.dart';
import '../models/fit_data.dart';

class FitParserService {
  Future<FitData> parseFitFile(String filePath) async {
    print('\n=== FIT Parser Debug Log ===');
    print('FIT file path: $filePath');
    
    final fitFile = FitFile(path: filePath).parse();
    print('FIT file parsed, total data messages: ${fitFile.dataMessages.length}');
    
    final gpsPoints = <GpsPoint>[];
    DateTime? startTime;
    DateTime? endTime;
    double totalDistance = 0;
    double totalDurationSeconds = 0;
    String? activityType;
    
    for (final message in fitFile.dataMessages) {
      if (message.any('position_lat') && message.any('position_long')) {
        final timestamp = _extractTimestampFromMessage(message);
        final latitude = _extractValueFromMessage(message, 'position_lat');
        final longitude = _extractValueFromMessage(message, 'position_long');
        
        if (timestamp != null && latitude != null && longitude != null) {
          // Try to get speed from both 'speed' and 'enhanced_speed' fields
          final speedValue = _extractValueFromMessage(message, 'speed') 
            ?? _extractValueFromMessage(message, 'enhanced_speed');
          
          final gpsPoint = GpsPoint(
            timestamp: timestamp,
            latitude: _convertSemicirclesToDegrees(latitude),
            longitude: _convertSemicirclesToDegrees(longitude),
            altitude: _extractValueFromMessage(message, 'altitude'),
            speed: speedValue,
            distance: _extractValueFromMessage(message, 'distance'),
            heartRate: _extractValueFromMessage(message, 'heart_rate'),
          );
          gpsPoints.add(gpsPoint);
          
          if (startTime == null || timestamp.isBefore(startTime)) {
            startTime = timestamp;
          }
          if (endTime == null || timestamp.isAfter(endTime)) {
            endTime = timestamp;
          }
        }
      }
      
      if (message.any('total_distance') || message.any('sport')) {
        final timestamp = _extractTimestampFromMessage(message);
        startTime = timestamp ?? startTime;
        
        final distValue = _extractValueFromMessage(message, 'total_distance');
        if (distValue != null) {
          totalDistance = distValue;
        }
        
        final timerTime = _extractValueFromMessage(message, 'total_timer_time');
        if (timerTime != null) {
          totalDurationSeconds = timerTime;
        }
        
        final sportValue = _extractStringValueFromMessage(message, 'sport');
        if (sportValue != null) {
          activityType = sportValue;
        }
      }
    }
    
    print('GPS points extracted: ${gpsPoints.length}');
    print('FIT start time: $startTime');
    print('FIT end time: $endTime');
    print('Activity type: $activityType');
    print('Total distance: ${totalDistance}m');
    
    if (gpsPoints.isNotEmpty && startTime != null && endTime != null) {
      totalDurationSeconds = endTime.difference(startTime).inSeconds.toDouble();
      print('Calculated duration: ${totalDurationSeconds}s');
      
      print('\nFirst 3 GPS points:');
      for (int i = 0; i < 3 && i < gpsPoints.length; i++) {
        final point = gpsPoints[i];
        print('  Point $i: Time=${point.timestamp}, Lat=${point.latitude.toStringAsFixed(6)}, Lon=${point.longitude.toStringAsFixed(6)}');
        if (point.speed != null) {
          print('    Speed: ${point.speed!.toStringAsFixed(2)} m/s (${(point.speed! * 3.6).toStringAsFixed(1)} km/h)');
          print('    Pace: ${point.paceFormatted()} min/km');
        }
        if (point.distance != null) {
          print('    Distance: ${point.distance!.toStringAsFixed(2)} m');
        }
      }
      
      print('\nLast 3 GPS points:');
      for (int i = gpsPoints.length - 3; i < gpsPoints.length; i++) {
        if (i >= 0) {
          final point = gpsPoints[i];
          print('  Point $i: Time=${point.timestamp}, Lat=${point.latitude.toStringAsFixed(6)}, Lon=${point.longitude.toStringAsFixed(6)}');
        }
      }
    }
    
    print('=== FIT Parser Debug End ===\n');
    
    return FitData(
      gpsPoints: gpsPoints,
      startTime: startTime,
      endTime: endTime,
      totalDistance: totalDistance,
      totalDurationSeconds: totalDurationSeconds,
      activityType: activityType,
    );
  }
  
  DateTime? _extractTimestampFromMessage(DataMessage message) {
    if (!message.any('timestamp')) return null;
    final value = message.get('timestamp');
    if (value == null) return null;
    
    double timestampValue;
    if (value is int) {
      timestampValue = value.toDouble();
    } else if (value is double) {
      timestampValue = value;
    } else {
      return null;
    }
    
    final utcTime = DateTime.fromMillisecondsSinceEpoch(
      (timestampValue * 1000).toInt() + 315537600000,
      isUtc: true,
    );
    
    return utcTime.toLocal();
  }
  
  double? _extractValueFromMessage(DataMessage message, String fieldName) {
    if (!message.any(fieldName)) return null;
    final value = message.get(fieldName);
    if (value == null) return null;
    
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }
  
  String? _extractStringValueFromMessage(DataMessage message, String fieldName) {
    if (!message.any(fieldName)) return null;
    final value = message.get(fieldName);
    if (value == null) return null;
    
    return value.toString();
  }
  
  double _convertSemicirclesToDegrees(double semicircles) {
    return semicircles * 180 / 2147483648.0;
  }
}