import 'package:flutter/material.dart';
import '../models/gps_point.dart';

class OverlayPainter extends CustomPainter {
  final List<GpsPoint> gpsPoints;
  final GpsPoint? currentPosition;
  final DateTime imageTimestamp;
  final Size imageSize;
  final String activityName;
  
  final Color trackColor;
  final double trackWidth;
  final Color positionColor;
  final double positionRadius;
  final Color textColor;
  final double textSize;
  final bool showTrack;
  final bool showPosition;
  final bool showPace;
  final bool showTimestamp;
  
  OverlayPainter({
    required this.gpsPoints,
    this.currentPosition,
    required this.imageTimestamp,
    required this.imageSize,
    this.activityName = '',
    this.trackColor = Colors.blue,
    this.trackWidth = 3.0,
    this.positionColor = Colors.red,
    this.positionRadius = 10.0,
    this.textColor = Colors.white,
    this.textSize = 14.0,
    this.showTrack = true,
    this.showPosition = true,
    this.showPace = true,
    this.showTimestamp = true,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (gpsPoints.isEmpty) return;
    
    // Dynamic scaling based on image size
    final scaleFactor = size.width / 800.0; // Base reference: 800px width
    final scaledPadding = 20.0 * scaleFactor;
    final scaledTextSize = textSize * scaleFactor;
    
    // Calculate track area (right upper corner, max 30-40% of width and height)
    final maxTrackWidth = size.width * (size.width > 600 ? 0.35 : 0.40);
    final maxTrackHeight = size.height * 0.35;
    
    final bounds = _calculateGpsBounds();
    final gpsWidth = bounds.maxLon - bounds.minLon;
    final gpsHeight = bounds.maxLat - bounds.minLat;
    
    // Use single scale to maintain aspect ratio
    final scaleX = maxTrackWidth / gpsWidth;
    final scaleY = maxTrackHeight / gpsHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY; // Use smaller scale to fit
    
    final areaWidth = gpsWidth * scale;
    final areaHeight = gpsHeight * scale;
    
    // Position in right upper corner with scaled padding
    final trackOffsetX = size.width - areaWidth - scaledPadding;
    final trackOffsetY = scaledPadding;
    
    // Draw semi-transparent background for track area
    final bgPaint = Paint();
    bgPaint.color = Colors.black.withOpacity(0.6);
    bgPaint.style = PaintingStyle.fill;
    
    final bgRect = Rect.fromLTWH(
      trackOffsetX - 10 * scaleFactor,
      trackOffsetY - 10 * scaleFactor,
      areaWidth + 20 * scaleFactor,
      areaHeight + 20 * scaleFactor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, Radius.circular(12 * scaleFactor)),
      bgPaint,
    );
    
    // Draw track within the area (maintaining aspect ratio)
    if (showTrack && gpsPoints.length > 1) {
      _drawTrack(canvas, trackOffsetX, trackOffsetY, areaWidth, areaHeight, bounds, scale);
    }
    
    // Draw current position marker
    if (showPosition && currentPosition != null) {
      _drawPosition(canvas, trackOffsetX, trackOffsetY, areaHeight, bounds, scale);
    }
    
    // Draw pace info (bottom left)
    if (showPace && currentPosition != null) {
      _drawPaceInfo(canvas, size);
    }
    
    // Draw activity name (top left, if provided)
    if (activityName.isNotEmpty) {
      _drawActivityName(canvas, size);
    }
  }
  
  void _drawTrack(Canvas canvas, double offsetX, double offsetY, double areaWidth, double areaHeight, GpsBounds bounds, double scale) {
    final scaleFactor = imageSize.width / 800.0;
    final scaledTrackWidth = trackWidth * scaleFactor;
    
    final paint = Paint();
    paint.color = trackColor;
    paint.strokeWidth = scaledTrackWidth;
    paint.style = PaintingStyle.stroke;
    paint.strokeCap = StrokeCap.round;
    paint.strokeJoin = StrokeJoin.round;
    
    final path = Path();
    final firstPoint = gpsPoints.first;
    final x1 = offsetX + (firstPoint.longitude - bounds.minLon) * scale;
    final y1 = offsetY + areaHeight - (firstPoint.latitude - bounds.minLat) * scale;
    path.moveTo(x1, y1);
    
    for (int i = 1; i < gpsPoints.length; i++) {
      final point = gpsPoints[i];
      final x = offsetX + (point.longitude - bounds.minLon) * scale;
      final y = offsetY + areaHeight - (point.latitude - bounds.minLat) * scale;
      path.lineTo(x, y);
    }
    
    canvas.drawPath(path, paint);
  }
  
  void _drawPosition(Canvas canvas, double offsetX, double offsetY, double areaHeight, GpsBounds bounds, double scale) {
    final scaleFactor = imageSize.width / 800.0;
    final scaledPositionRadius = positionRadius * scaleFactor;
    
    final x = offsetX + (currentPosition!.longitude - bounds.minLon) * scale;
    final y = offsetY + areaHeight - (currentPosition!.latitude - bounds.minLat) * scale;
    
    final outerPaint = Paint();
    outerPaint.color = positionColor;
    outerPaint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), scaledPositionRadius, outerPaint);
    
    final innerPaint = Paint();
    innerPaint.color = Colors.white;
    innerPaint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), scaledPositionRadius * 0.5, innerPaint);
    
    final borderPaint = Paint();
    borderPaint.color = positionColor;
    borderPaint.strokeWidth = 2 * scaleFactor;
    borderPaint.style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(x, y), scaledPositionRadius, borderPaint);
  }
  
  void _drawTrackInfoLabel(Canvas canvas, double x, double y) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'GPS Track',
        style: TextStyle(
          color: textColor.withOpacity(0.8),
          fontSize: textSize * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y));
  }
  
  void _drawActivityName(Canvas canvas, Size size) {
    final bgPaint = Paint();
    bgPaint.color = Colors.black.withOpacity(0.5);
    bgPaint.style = PaintingStyle.fill;
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: activityName,
        style: TextStyle(
          color: textColor,
          fontSize: textSize * 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    final textWidth = textPainter.width;
    final textHeight = textPainter.height;
    
    final bgRect = Rect.fromLTWH(10, 10, textWidth + 20, textHeight + 20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, Radius.circular(8)),
      bgPaint,
    );
    
    textPainter.paint(canvas, Offset(20, 20));
  }
  
  void _drawPaceInfo(Canvas canvas, Size size) {
    final scaleFactor = size.width / 800.0;
    final scaledTextSize = textSize * scaleFactor;
    final scaledPadding = 20.0 * scaleFactor;
    
    final pace = currentPosition!.paceFormatted();
    final distance = currentPosition!.distance != null
      ? '${(currentPosition!.distance! / 1000).toStringAsFixed(2)} km'
      : '-- km';
    final heartRate = currentPosition!.heartRate != null
      ? '${currentPosition!.heartRate!.toStringAsFixed(0)} bpm'
      : '-- bpm';
    final timestampStr = '${imageTimestamp.year}-${imageTimestamp.month.toString().padLeft(2, '0')}-${imageTimestamp.day.toString().padLeft(2, '0')} '
      '${imageTimestamp.hour.toString().padLeft(2, '0')}:${imageTimestamp.minute.toString().padLeft(2, '0')}:${imageTimestamp.second.toString().padLeft(2, '0')}';
    
    // Box width: almost full width with scaled margins
    final boxWidth = size.width - (scaledPadding * 2);
    
    // Calculate text dimensions
    final lineHeight = scaledTextSize * 1.6;
    final totalHeight = lineHeight * 4 + 30 * scaleFactor; // 4 lines + padding
    
    // Background - positioned at bottom with scaled margins
    final bgPaint = Paint();
    bgPaint.color = Colors.black.withOpacity(0.6);
    bgPaint.style = PaintingStyle.fill;
    
    final bgRect = Rect.fromLTWH(
      scaledPadding, 
      size.height - totalHeight - scaledPadding, 
      boxWidth, 
      totalHeight
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, Radius.circular(10 * scaleFactor)),
      bgPaint,
    );
    
    // Draw text - 4 lines, Chinese labels
    final startY = size.height - totalHeight - 5 * scaleFactor;
    
    final textPainter = TextPainter(
      text: TextSpan(
        style: TextStyle(
          color: textColor,
          fontSize: scaledTextSize,
          fontWeight: FontWeight.bold,
          height: 1.6,
        ),
        children: [
          TextSpan(text: '配速: $pace min/km\n'),
          TextSpan(text: '距离: $distance\n'),
          TextSpan(text: '心率: $heartRate\n'),
          TextSpan(text: '时间: $timestampStr'),
        ],
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout(maxWidth: boxWidth - scaledPadding);
    textPainter.paint(canvas, Offset(scaledPadding + 10 * scaleFactor, startY));
  }
  
  GpsBounds _calculateGpsBounds() {
    double minLat = gpsPoints.first.latitude;
    double maxLat = gpsPoints.first.latitude;
    double minLon = gpsPoints.first.longitude;
    double maxLon = gpsPoints.first.longitude;
    
    for (final point in gpsPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }
    
    final paddingLat = (maxLat - minLat) * 0.1;
    final paddingLon = (maxLon - minLon) * 0.1;
    
    return GpsBounds(
      minLat: minLat - paddingLat,
      maxLat: maxLat + paddingLat,
      minLon: minLon - paddingLon,
      maxLon: maxLon + paddingLon,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class GpsBounds {
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;
  
  GpsBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });
}