import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoMetadata {
  final String path;
  final Duration duration;
  final int width;
  final int height;
  final double frameRate;
  final DateTime? creationTime;

  VideoMetadata({
    required this.path,
    required this.duration,
    required this.width,
    required this.height,
    this.frameRate = 30.0,
    this.creationTime,
  });

  String get resolution => '${width}x$height';
  
  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class VideoMetadataService {
  static const MethodChannel _channel = MethodChannel('video_metadata_channel');

  Future<VideoMetadata?> getVideoMetadata(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        print('Video file not found: $videoPath');
        return null;
      }

      final controller = VideoPlayerController.file(file);
      await controller.initialize();

      DateTime? creationTime;

      if (!kIsWeb) {
        if (Platform.isAndroid || Platform.isIOS) {
          creationTime = await _getNativeCreationTime(videoPath);
        } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          creationTime = await _runFFprobe(videoPath);
        }
      }

      if (creationTime == null) {
        creationTime = await _getFallbackTime(videoPath);
      }

      final videoInfo = VideoMetadata(
        path: videoPath,
        duration: controller.value.duration,
        width: controller.value.size.width.toInt(),
        height: controller.value.size.height.toInt(),
        frameRate: 30.0,
        creationTime: creationTime,
      );

      await controller.dispose();

      print('\n=== Video Metadata ===');
      print('Path: $videoPath');
      print('Duration: ${videoInfo.durationFormatted}');
      print('Resolution: ${videoInfo.resolution}');
      print('Creation time: ${videoInfo.creationTime}');
      print('=== End ===\n');

      return videoInfo;
    } catch (e) {
      print('Error getting video metadata: $e');
      return null;
    }
  }

  Future<DateTime?> _getNativeCreationTime(String videoPath) async {
    try {
      final result = await _channel.invokeMethod<String>('getCreationTime', {'path': videoPath});
      if (result != null) {
        print('Native creation time: $result');
        return DateTime.parse(result);
      }
    } catch (e) {
      print('Native method failed: $e');
    }
    return null;
  }

  Future<DateTime?> _runFFprobe(String videoPath) async {
    try {
      final result = await Process.run(
        'ffprobe',
        [
          '-v', 'quiet',
          '-show_entries', 'format_tags=creation_time',
          '-of', 'json',
          videoPath,
        ],
      );

      if (result.exitCode != 0) {
        print('FFprobe failed: ${result.stderr}');
        return null;
      }

      final output = result.stdout as String;

      final creationTimeMatch = RegExp(
        r'"creation_time"\s*:\s*"([^"]+)"',
      ).firstMatch(output);

      if (creationTimeMatch != null) {
        final timeStr = creationTimeMatch.group(1)!;
        print('Raw creation_time from ffprobe: $timeStr');
        
        try {
          DateTime parsedTime;
          bool isUtc = false;
          
          if (timeStr.endsWith('Z')) {
            parsedTime = DateTime.parse(timeStr);
            isUtc = true;
            print('Parsed as UTC time: $parsedTime');
          } else {
            parsedTime = DateTime.parse(timeStr.replaceFirst(' ', 'T'));
            if (timeStr.contains('T') || !timeStr.contains('+')) {
              isUtc = true;
              print('Parsed time without timezone marker, assuming UTC: $parsedTime');
            }
          }
          
          if (isUtc) {
            final localTime = parsedTime.toLocal();
            print('Converted UTC to local time: $localTime');
            print('UTC offset: ${localTime.timeZoneOffset}');
            return localTime;
          }
          
          return parsedTime;
        } catch (e) {
          print('Failed to parse creation_time: $e');
        }
      }

      return null;
    } catch (e) {
      print('Error running ffprobe: $e');
      return null;
    }
  }

  Future<DateTime?> _getFallbackTime(String videoPath) async {
    try {
      final file = File(videoPath);
      final stat = await file.stat();
      
      final fileName = file.path.split(Platform.pathSeparator).last;
      
      DateTime? parsedTime = _parseTimeFromFileName(fileName);
      if (parsedTime != null) {
        return parsedTime;
      }
      
      return stat.modified;
    } catch (e) {
      print('Error getting file time: $e');
      return null;
    }
  }

  DateTime? _parseTimeFromFileName(String fileName) {
    final patterns = [
      RegExp(r'(\d{4})[-_]?(\d{2})[-_]?(\d{2})[-_]?(\d{2})[-_]?(\d{2})[-_]?(\d{2})'),
      RegExp(r'VID[-_]?(\d{4})[-_]?(\d{2})[-_]?(\d{2})[-_]?(\d{2})[-_]?(\d{2})[-_]?(\d{2})'),
      RegExp(r'(\d{4})(\d{2})(\d{2})[-_]?(\d{2})(\d{2})(\d{2})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(fileName);
      if (match != null) {
        try {
          final groups = match.groups([1, 2, 3, 4, 5, 6]);
          return DateTime(
            int.parse(groups[0]!),
            int.parse(groups[1]!),
            int.parse(groups[2]!),
            int.parse(groups[3]!),
            int.parse(groups[4]!),
            int.parse(groups[5]!),
          );
        } catch (e) {
          continue;
        }
      }
    }

    return null;
  }

  Future<VideoPlayerController> createVideoController(String videoPath) async {
    final file = File(videoPath);
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    return controller;
  }
}