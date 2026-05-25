import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import '../models/fit_data.dart';
import '../models/gps_point.dart';
import '../widgets/overlay_painter.dart';

class VideoExportService {
  Future<String?> exportVideoWithOverlay({
    required String inputVideoPath,
    required String outputPath,
    required FitData fitData,
    required DateTime videoStartTime,
    required String activityName,
    double fps = 10.0,
    Color trackColor = Colors.blue,
    double trackWidth = 2.5,
    Color positionColor = Colors.red,
    double positionRadius = 6.0,
    Color textColor = Colors.white,
    double textSize = 24.0,
    bool showTrack = true,
    bool showPosition = true,
    bool showPace = true,
    bool showTimestamp = true,
    Function(String message)? onProgress,
  }) async {
    if (kIsWeb) {
      onProgress?.call('Video export not supported on web');
      return null;
    }

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return await _exportWithFfmpegKit(
        inputVideoPath: inputVideoPath,
        outputPath: outputPath,
        fitData: fitData,
        videoStartTime: videoStartTime,
        activityName: activityName,
        fps: fps,
        trackColor: trackColor,
        trackWidth: trackWidth,
        positionColor: positionColor,
        positionRadius: positionRadius,
        textColor: textColor,
        textSize: textSize,
        showTrack: showTrack,
        showPosition: showPosition,
        showPace: showPace,
        showTimestamp: showTimestamp,
        onProgress: onProgress,
      );
    } else if (Platform.isWindows || Platform.isLinux) {
      return await _exportDesktop(
        inputVideoPath: inputVideoPath,
        outputPath: outputPath,
        fitData: fitData,
        videoStartTime: videoStartTime,
        activityName: activityName,
        fps: fps,
        trackColor: trackColor,
        trackWidth: trackWidth,
        positionColor: positionColor,
        positionRadius: positionRadius,
        textColor: textColor,
        textSize: textSize,
        showTrack: showTrack,
        showPosition: showPosition,
        showPace: showPace,
        showTimestamp: showTimestamp,
        onProgress: onProgress,
      );
    }

    return null;
  }

  Future<String?> _exportWithFfmpegKit({
    required String inputVideoPath,
    required String outputPath,
    required FitData fitData,
    required DateTime videoStartTime,
    required String activityName,
    double fps = 10.0,
    Color trackColor = Colors.blue,
    double trackWidth = 2.5,
    Color positionColor = Colors.red,
    double positionRadius = 6.0,
    Color textColor = Colors.white,
    double textSize = 24.0,
    bool showTrack = true,
    bool showPosition = true,
    bool showPace = true,
    bool showTimestamp = true,
    Function(String message)? onProgress,
  }) async {
    try {
      onProgress?.call('Preparing temporary directory...');
      
      final tempDir = await getTemporaryDirectory();
      final sessionId = DateTime.now().millisecondsSinceEpoch;
      final frameInputDir = Directory('${tempDir.path}/input_frames_$sessionId');
      final frameOutputDir = Directory('${tempDir.path}/output_frames_$sessionId');
      
      await frameInputDir.create(recursive: true);
      await frameOutputDir.create(recursive: true);

      onProgress?.call('Extracting frames from video...');
      
      final extractCommand = '-i "$inputVideoPath" -vf fps=$fps "${frameInputDir.path}/frame_%06d.png" -y';
      await FFmpegKit.execute(extractCommand);

      final inputFrames = await frameInputDir.list().toList();
      final totalFrames = inputFrames.length;
      
      print('Extracted $totalFrames frames');
      onProgress?.call('Processing $totalFrames frames with overlay...');

      int processedCount = 0;
      
      for (final fileEntity in inputFrames) {
        if (fileEntity is! File) continue;
        
        final fileName = fileEntity.path.split(Platform.pathSeparator).last;
        final frameNumberMatch = RegExp(r'frame_(\d+)').firstMatch(fileName);
        if (frameNumberMatch == null) continue;
        
        final frameNumber = int.parse(frameNumberMatch.group(1)!);
        final positionMs = (frameNumber - 1) * (1000 / fps).round();
        final position = Duration(milliseconds: positionMs);
        
        final currentTimestamp = videoStartTime.add(position);
        final currentPosition = fitData.findPointAtTime(currentTimestamp);

        if (currentPosition == null) {
          processedCount++;
          continue;
        }

        final frameData = await fileEntity.readAsBytes();
        
        final processedFrame = await _addOverlayToFrame(
          frameData: frameData,
          gpsPoints: fitData.gpsPoints,
          currentPosition: currentPosition,
          timestamp: currentTimestamp,
          activityName: activityName,
          trackColor: trackColor,
          trackWidth: trackWidth,
          positionColor: positionColor,
          positionRadius: positionRadius,
          textColor: textColor,
          textSize: textSize,
          showTrack: showTrack,
          showPosition: showPosition,
          showPace: showPace,
          showTimestamp: showTimestamp,
        );

        if (processedFrame != null) {
          final outputPath = '${frameOutputDir.path}/$fileName';
          await File(outputPath).writeAsBytes(processedFrame);
        }
        
        processedCount++;
        if (processedCount % 10 == 0 || processedCount == totalFrames) {
          onProgress?.call('Processed $processedCount/$totalFrames frames...');
        }
      }

      onProgress?.call('Encoding final video...');

      final encodeCommand = '-framerate $fps -i "${frameOutputDir.path}/frame_%06d.png" -c:v libx264 -preset medium -crf 23 -pix_fmt yuv420p -y "$outputPath"';
      final session = await FFmpegKit.execute(encodeCommand);
      final returnCode = await session.getReturnCode();

      await frameInputDir.delete(recursive: true);
      await frameOutputDir.delete(recursive: true);

      if (returnCode!.isValueSuccess()) {
        onProgress?.call('Video exported successfully!');
        return outputPath;
      } else {
        onProgress?.call('Encoding failed');
        return null;
      }
    } catch (e) {
      onProgress?.call('Error: $e');
      return null;
    }
  }

  Future<String?> _exportDesktop({
    required String inputVideoPath,
    required String outputPath,
    required FitData fitData,
    required DateTime videoStartTime,
    required String activityName,
    double fps = 10.0,
    Color trackColor = Colors.blue,
    double trackWidth = 2.5,
    Color positionColor = Colors.red,
    double positionRadius = 6.0,
    Color textColor = Colors.white,
    double textSize = 24.0,
    bool showTrack = true,
    bool showPosition = true,
    bool showPace = true,
    bool showTimestamp = true,
    Function(String message)? onProgress,
  }) async {
    try {
      onProgress?.call('Preparing temporary directory...');
      
      final tempDir = await getTemporaryDirectory();
      final sessionId = DateTime.now().millisecondsSinceEpoch;
      final frameInputDir = Directory('${tempDir.path}/input_frames_$sessionId');
      final frameOutputDir = Directory('${tempDir.path}/output_frames_$sessionId');
      
      await frameInputDir.create(recursive: true);
      await frameOutputDir.create(recursive: true);

      onProgress?.call('Extracting frames from video...');
      
      final extractResult = await Process.run(
        'ffmpeg',
        [
          '-i', inputVideoPath,
          '-vf', 'fps=$fps',
          '${frameInputDir.path}/frame_%06d.png',
          '-y',
        ],
      );

      if (extractResult.exitCode != 0) {
        onProgress?.call('Frame extraction failed');
        await frameInputDir.delete(recursive: true);
        await frameOutputDir.delete(recursive: true);
        return null;
      }

      final inputFrames = await frameInputDir.list().toList();
      final totalFrames = inputFrames.length;
      
      onProgress?.call('Processing $totalFrames frames with overlay...');

      int processedCount = 0;
      
      for (final fileEntity in inputFrames) {
        if (fileEntity is! File) continue;
        
        final fileName = fileEntity.path.split(Platform.pathSeparator).last;
        final frameNumberMatch = RegExp(r'frame_(\d+)').firstMatch(fileName);
        if (frameNumberMatch == null) continue;
        
        final frameNumber = int.parse(frameNumberMatch.group(1)!);
        final positionMs = (frameNumber - 1) * (1000 / fps).round();
        final position = Duration(milliseconds: positionMs);
        
        final currentTimestamp = videoStartTime.add(position);
        final currentPosition = fitData.findPointAtTime(currentTimestamp);

        if (currentPosition == null) {
          processedCount++;
          continue;
        }

        final frameData = await fileEntity.readAsBytes();
        
        final processedFrame = await _addOverlayToFrame(
          frameData: frameData,
          gpsPoints: fitData.gpsPoints,
          currentPosition: currentPosition,
          timestamp: currentTimestamp,
          activityName: activityName,
          trackColor: trackColor,
          trackWidth: trackWidth,
          positionColor: positionColor,
          positionRadius: positionRadius,
          textColor: textColor,
          textSize: textSize,
          showTrack: showTrack,
          showPosition: showPosition,
          showPace: showPace,
          showTimestamp: showTimestamp,
        );

        if (processedFrame != null) {
          final outputPath = '${frameOutputDir.path}/$fileName';
          await File(outputPath).writeAsBytes(processedFrame);
        }
        
        processedCount++;
        if (processedCount % 10 == 0 || processedCount == totalFrames) {
          onProgress?.call('Processed $processedCount/$totalFrames frames...');
        }
      }

      onProgress?.call('Encoding final video...');

      final encodeResult = await Process.run(
        'ffmpeg',
        [
          '-framerate', fps.toString(),
          '-i', '${frameOutputDir.path}/frame_%06d.png',
          '-c:v', 'libx264',
          '-preset', 'medium',
          '-crf', '23',
          '-pix_fmt', 'yuv420p',
          '-y', outputPath,
        ],
      );

      await frameInputDir.delete(recursive: true);
      await frameOutputDir.delete(recursive: true);

      if (encodeResult.exitCode == 0) {
        onProgress?.call('Video exported successfully!');
        return outputPath;
      } else {
        onProgress?.call('Encoding failed');
        return null;
      }
    } catch (e) {
      onProgress?.call('Error: $e');
      return null;
    }
  }

  Future<Uint8List?> _addOverlayToFrame({
    required Uint8List frameData,
    required List<GpsPoint> gpsPoints,
    required GpsPoint currentPosition,
    required DateTime timestamp,
    required String activityName,
    Color trackColor = Colors.blue,
    double trackWidth = 2.5,
    Color positionColor = Colors.red,
    double positionRadius = 6.0,
    Color textColor = Colors.white,
    double textSize = 24.0,
    bool showTrack = true,
    bool showPosition = true,
    bool showPace = true,
    bool showTimestamp = true,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(frameData);
      final frame = await codec.getNextFrame();
      final uiImage = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(uiImage.width.toDouble(), uiImage.height.toDouble());

      canvas.drawImage(uiImage, Offset.zero, Paint());

      final overlayPainter = OverlayPainter(
        gpsPoints: gpsPoints,
        currentPosition: currentPosition,
        imageTimestamp: timestamp,
        imageSize: size,
        activityName: activityName,
        trackColor: trackColor,
        trackWidth: trackWidth,
        positionColor: positionColor,
        positionRadius: positionRadius,
        textColor: textColor,
        textSize: textSize,
        showTrack: showTrack,
        showPosition: showPosition,
        showPace: showPace,
        showTimestamp: showTimestamp,
      );

      overlayPainter.paint(canvas, size);

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );

      final pngData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (pngData == null) return null;

      return pngData.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }
}