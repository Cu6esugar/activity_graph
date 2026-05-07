import 'dart:io';
import 'package:exif/exif.dart';

class ExifService {
  Future<DateTime?> readImageTimestamp(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    
    try {
      final tags = await readExifFromBytes(bytes);
      
      print('=== EXIF Debug Log ===');
      print('Image path: $imagePath');
      print('Available EXIF tags: ${tags.keys.toList()}');
      
      DateTime? result;
      String? usedField;
      
      if (tags.containsKey('Image DateTime')) {
        final dateTimeStr = tags['Image DateTime']!.toString();
        print('Found Image DateTime: $dateTimeStr');
        result = _parseExifDateTime(dateTimeStr);
        usedField = 'Image DateTime';
      }
      
      if (result == null && tags.containsKey('EXIF DateTimeOriginal')) {
        final dateTimeStr = tags['EXIF DateTimeOriginal']!.toString();
        print('Found EXIF DateTimeOriginal: $dateTimeStr');
        result = _parseExifDateTime(dateTimeStr);
        usedField = 'EXIF DateTimeOriginal';
      }
      
      if (result == null && tags.containsKey('EXIF DateTimeDigitized')) {
        final dateTimeStr = tags['EXIF DateTimeDigitized']!.toString();
        print('Found EXIF DateTimeDigitized: $dateTimeStr');
        result = _parseExifDateTime(dateTimeStr);
        usedField = 'EXIF DateTimeDigitized';
      }
      
      if (result != null) {
        print('Parsed EXIF time: $result (using field: $usedField)');
        
        if (tags.containsKey('GPSLatitude') && tags.containsKey('GPSLongitude')) {
          final lat = tags['GPSLatitude']!.toString();
          final lon = tags['GPSLongitude']!.toString();
          print('GPS coordinates in EXIF: Lat=$lat, Lon=$lon');
        } else {
          print('No GPS coordinates found in EXIF');
        }
      } else {
        print('Failed to parse EXIF datetime - no valid time field found');
      }
      
      print('=== EXIF Debug End ===\n');
      return result;
    } catch (e) {
      print('Error reading EXIF: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>> readAllExifData(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    
    try {
      final tags = await readExifFromBytes(bytes);
      final data = <String, dynamic>{};
      
      for (final entry in tags.entries) {
        data[entry.key] = entry.value.toString();
      }
      
      return data;
    } catch (e) {
      print('Error reading EXIF: $e');
      return {};
    }
  }
  
  DateTime? _parseExifDateTime(String dateTimeStr) {
    dateTimeStr = dateTimeStr.replaceAll(':', '-');
    final parts = dateTimeStr.split(' ');
    if (parts.length != 2) return null;
    
    final dateParts = parts[0].split('-');
    final timeParts = parts[1].split('-');
    
    if (dateParts.length != 3 || timeParts.length != 3) return null;
    
    try {
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        int.parse(timeParts[2]),
      );
    } catch (e) {
      return null;
    }
  }
}