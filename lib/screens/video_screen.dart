import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import '../models/fit_data.dart';
import '../models/gps_point.dart';
import '../services/fit_parser_service.dart';
import '../services/video_metadata_service.dart';
import '../services/video_export_service.dart';
import '../widgets/overlay_painter.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final FitParserService _fitParserService = FitParserService();
  final VideoMetadataService _videoMetadataService = VideoMetadataService();
  final VideoExportService _videoExportService = VideoExportService();
  final GlobalKey _videoKey = GlobalKey();

  String? _videoPath;
  VideoPlayerController? _videoController;
  VideoMetadata? _videoMetadata;
  FitData? _fitData;
  DateTime? _videoStartTime;
  DateTime? _manualStartTime;
  bool _useManualTime = false;

  String _activityName = '';

  bool _showTrack = true;
  bool _showPosition = true;
  bool _showPace = true;
  bool _showTimestamp = true;

  Color _trackColor = Colors.blue;
  double _trackWidth = 2.5;
  Color _positionColor = Colors.red;
  double _positionRadius = 6.0;
  Color _textColor = Colors.white;
  double _textSize = 24.0;

  bool _isLoading = false;
  String? _errorMessage;
  String _loadingMessage = '';

  GpsPoint? _currentPosition;
  Duration _currentVideoPosition = Duration.zero;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _selectVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _loadingMessage = 'Selecting video...';
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv'],
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path!;

        final metadata = await _videoMetadataService.getVideoMetadata(path);
        if (metadata == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to get video metadata';
          });
          return;
        }

        _videoController?.dispose();
        final controller = await _videoMetadataService.createVideoController(path);
        controller.addListener(_videoPositionListener);

        setState(() {
          _videoPath = path;
          _videoMetadata = metadata;
          _videoController = controller;
          _isLoading = false;
          _videoStartTime = metadata.creationTime;
          _manualStartTime = metadata.creationTime;
        });

        _updateCurrentPosition();
      } else {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to select video: $e';
      });
    }
  }

  void _videoPositionListener() {
    if (_videoController != null) {
      final position = _videoController!.value.position;
      setState(() {
        _currentVideoPosition = position;
      });
      _updateCurrentPosition();
    }
  }

  void _updateCurrentPosition() {
    if (_fitData == null || _videoStartTime == null) return;

    final startTime = _useManualTime ? _manualStartTime : _videoStartTime;
    if (startTime == null) return;

    final currentTimestamp = startTime.add(_currentVideoPosition);
    final matched = _fitData!.findPointAtTime(currentTimestamp);

    setState(() {
      _currentPosition = matched;
    });
  }

  Future<void> _selectFitFile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _loadingMessage = 'Parsing FIT file...';
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path!;

        final fitData = await _fitParserService.parseFitFile(path);
        setState(() {
          _fitData = fitData;
          _isLoading = false;
          _loadingMessage = '';
        });

        _updateCurrentPosition();
      } else {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to parse FIT file: $e';
      });
    }
  }

  Future<void> _selectManualStartTime() async {
    if (_fitData == null || _fitData!.startTime == null || _fitData!.endTime == null) {
      setState(() {
        _errorMessage = 'Please select a FIT file first';
      });
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _manualStartTime ?? _fitData!.startTime!,
      firstDate: _fitData!.startTime!,
      lastDate: _fitData!.endTime!,
    );

    if (!mounted) return;

    if (picked != null) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_manualStartTime ?? _fitData!.startTime!),
      );

      if (!mounted) return;

      if (timePicked != null) {
        final DateTime selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          timePicked.hour,
          timePicked.minute,
          _manualStartTime?.second ?? 0,
        );

        setState(() {
          _manualStartTime = selectedDateTime;
          _useManualTime = true;
        });

        _updateCurrentPosition();
      }
    }
  }

  Future<void> _exportVideo() async {
    if (_videoPath == null || _fitData == null || _videoMetadata == null) {
      setState(() {
        _errorMessage = 'Please select video and FIT file first';
      });
      return;
    }

    final startTime = _useManualTime ? _manualStartTime : _videoStartTime;
    if (startTime == null) {
      setState(() {
        _errorMessage = 'Please set video start time';
      });
      return;
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final activityPrefix = _activityName.isNotEmpty ? '${_activityName}_' : '';
    final defaultFileName = '${activityPrefix}video_overlay_$timestamp.mp4';

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Video with Overlay',
      fileName: defaultFileName,
      allowedExtensions: ['mp4'],
    );

    if (outputPath == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _loadingMessage = 'Starting export...';
      });

      final result = await _videoExportService.exportVideoWithOverlay(
        inputVideoPath: _videoPath!,
        outputPath: outputPath,
        fitData: _fitData!,
        videoStartTime: startTime,
        activityName: _activityName,
        fps: 10.0,
        trackColor: _trackColor,
        trackWidth: _trackWidth,
        positionColor: _positionColor,
        positionRadius: _positionRadius,
        textColor: _textColor,
        textSize: _textSize,
        showTrack: _showTrack,
        showPosition: _showPosition,
        showPace: _showPace,
        showTimestamp: _showTimestamp,
        onProgress: (message) {
          setState(() {
            _loadingMessage = message;
          });
        },
      );

      setState(() {
        _isLoading = false;
        _loadingMessage = '';
      });

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video exported successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Failed to export video';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to export: $e';
        _loadingMessage = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Overlay on Video'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_loadingMessage, style: const TextStyle(fontSize: 16)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _selectVideo,
                          icon: const Icon(Icons.video_library),
                          label: const Text('Select Video'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _selectFitFile,
                          icon: const Icon(Icons.map),
                          label: const Text('Select FIT File'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (_videoMetadata != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Video Info', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                          const SizedBox(height: 8),
                          Text('Duration: ${_videoMetadata!.durationFormatted}'),
                          Text('Resolution: ${_videoMetadata!.resolution}'),
                          if (_videoMetadata!.creationTime != null)
                            Text('Created: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_videoMetadata!.creationTime!)}'),
                        ],
                      ),
                    ),

                  if (_fitData != null) const SizedBox(height: 8),

                  if (_fitData != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FIT Info', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                          const SizedBox(height: 8),
                          if (_fitData!.startTime != null)
                            Text('Start: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_fitData!.startTime!)}'),
                          if (_fitData!.endTime != null)
                            Text('End: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_fitData!.endTime!)}'),
                          Text('Distance: ${_fitData!.formatTotalDistance()}'),
                          Text('GPS Points: ${_fitData!.gpsPoints.length}'),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Activity Name (optional)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _activityName = value),
                  ),

                  if (_fitData != null) const SizedBox(height: 16),

                  if (_fitData != null)
                    Row(
                      children: [
                        Checkbox(
                          value: _useManualTime,
                          onChanged: (value) {
                            setState(() => _useManualTime = value ?? false);
                            _updateCurrentPosition();
                          },
                        ),
                        const Text('Use manual start time'),
                        if (_useManualTime)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: ElevatedButton.icon(
                                onPressed: _selectManualStartTime,
                                icon: const Icon(Icons.edit),
                                label: Text(_manualStartTime != null
                                    ? DateFormat('HH:mm:ss').format(_manualStartTime!)
                                    : 'Set Time'),
                              ),
                            ),
                          ),
                      ],
                    ),

                  if (_videoController != null && _videoController!.value.isInitialized)
                    const SizedBox(height: 16),

                  if (_videoController != null && _videoController!.value.isInitialized)
                    RepaintBoundary(
                      key: _videoKey,
                      child: Container(
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              VideoPlayer(_videoController!),
                              if (_fitData != null && _currentPosition != null)
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: OverlayPainter(
                                      gpsPoints: _fitData!.gpsPoints,
                                      currentPosition: _currentPosition,
                                      imageTimestamp: (_useManualTime ? _manualStartTime : _videoStartTime)!,
                                      imageSize: Size(_videoController!.value.size.width, _videoController!.value.size.height),
                                      activityName: _activityName,
                                      trackColor: _trackColor,
                                      trackWidth: _trackWidth,
                                      positionColor: _positionColor,
                                      positionRadius: _positionRadius,
                                      textColor: _textColor,
                                      textSize: _textSize,
                                      showTrack: _showTrack,
                                      showPosition: _showPosition,
                                      showPace: _showPace,
                                      showTimestamp: _showTimestamp,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_videoController != null && _videoController!.value.isInitialized)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(_videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: () {
                              setState(() {
                                if (_videoController!.value.isPlaying) {
                                  _videoController!.pause();
                                } else {
                                  _videoController!.play();
                                }
                              });
                            },
                          ),
                          Expanded(
                            child: VideoProgressIndicator(
                              _videoController!,
                              allowScrubbing: true,
                              colors: VideoProgressColors(playedColor: Colors.blue, bufferedColor: Colors.blue.shade100),
                            ),
                          ),
                          Text('${_currentVideoPosition.inMinutes}:${(_currentVideoPosition.inSeconds % 60).toString().padLeft(2, '0')} / ${_videoMetadata!.duration.inMinutes}:${(_videoMetadata!.duration.inSeconds % 60).toString().padLeft(2, '0')}'),
                        ],
                      ),
                    ),

                  if (_videoController != null && _fitData != null && !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
                    const SizedBox(height: 16),

                  if (_videoController != null && _fitData != null && !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
                    ElevatedButton.icon(
                      onPressed: _exportVideo,
                      icon: const Icon(Icons.video_file),
                      label: const Text('Export Video with Overlay'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),

                  if (_videoController != null && _fitData != null && !kIsWeb && (Platform.isAndroid || Platform.isIOS))
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Video export on Android/iOS requires ffmpeg-kit',
                              style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Steps to enable:',
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                            Text(
                              '1. Download ffmpeg-kit-min AAR from GitHub releases',
                              style: TextStyle(color: Colors.orange.shade600, fontSize: 12),
                            ),
                            Text(
                              '2. Place in android/app/libs/ffmpeg-kit-min-6.0-2.aar',
                              style: TextStyle(color: Colors.orange.shade600, fontSize: 12),
                            ),
                            Text(
                              '3. Uncomment the dependency in build.gradle.kts',
                              style: TextStyle(color: Colors.orange.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_currentPosition != null) const SizedBox(height: 16),

                  if (_currentPosition != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Position', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                          const SizedBox(height: 8),
                          Text('Pace: ${_currentPosition!.paceFormatted()} min/km'),
                          if (_currentPosition!.distance != null)
                            Text('Distance: ${(_currentPosition!.distance! / 1000).toStringAsFixed(2)} km'),
                          if (_currentPosition!.heartRate != null)
                            Text('Heart Rate: ${_currentPosition!.heartRate!.toStringAsFixed(0)} bpm'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}