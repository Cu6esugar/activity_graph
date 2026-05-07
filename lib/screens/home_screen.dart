import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import '../models/fit_data.dart';
import '../models/gps_point.dart';
import '../services/fit_parser_service.dart';
import '../services/exif_service.dart';
import '../widgets/overlay_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _ImageDisplayInfo {
  final Size displaySize;
  final Offset offset;
  
  _ImageDisplayInfo({
    required this.displaySize,
    required this.offset,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  final FitParserService _fitParserService = FitParserService();
  final ExifService _exifService = ExifService();
  final GlobalKey _imageKey = GlobalKey();
  
  String? _imagePath;
  String? _fitFilePath;
  DateTime? _imageTimestamp;
  DateTime? _manualTimestamp;
  bool _useManualTime = false;
  FitData? _fitData;
  GpsPoint? _matchedPoint;
  
  Size? _imageOriginalSize;
  Size? _imageDisplaySize;
  Offset? _imageDisplayOffset;
  
  String _activityName = '';
  
  bool _showTrack = true;
  bool _showPosition = true;
  bool _showPace = true;
  bool _showTimestamp = true;
  
  Color _trackColor = Colors.blue;
  double _trackWidth = 3.0;
  Color _positionColor = Colors.red;
  double _positionRadius = 10.0;
  Color _textColor = Colors.white;
  double _textSize = 14.0;
  
  bool _isLoading = false;
  String? _errorMessage;
  
  Future<void> _selectImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path!;
        
        final timestamp = await _exifService.readImageTimestamp(path);
        
        final imageFile = File(path);
        final bytes = await imageFile.readAsBytes();
        
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final imageWidth = frame.image.width.toDouble();
        final imageHeight = frame.image.height.toDouble();
        
        setState(() {
          _imagePath = path;
          _errorMessage = null;
          _imageTimestamp = timestamp;
          _imageOriginalSize = Size(imageWidth, imageHeight);
          
          if (timestamp != null && _manualTimestamp == null) {
            _manualTimestamp = timestamp;
          }
        });
        
        print('\n=== Image Size Info ===');
        print('Original size: ${imageWidth.toInt()} x ${imageHeight.toInt()}');
        print('=== Image Size End ===\n');
        
        _matchAndCalculate();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to select image: $e';
      });
    }
  }
  
  Future<void> _selectFitFile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['fit'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path!;
        
        final fitData = await _fitParserService.parseFitFile(path);
        setState(() {
          _fitFilePath = path;
          _fitData = fitData;
          _isLoading = false;
        });
        
        _matchAndCalculate();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to parse FIT file: $e';
      });
    }
  }
  
  Future<void> _selectManualTime() async {
    if (_fitData == null || _fitData!.startTime == null || _fitData!.endTime == null) {
      setState(() {
        _errorMessage = 'Please select a FIT file first to set manual time';
      });
      return;
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _manualTimestamp ?? _fitData!.startTime!,
      firstDate: _fitData!.startTime!,
      lastDate: _fitData!.endTime!,
    );
    
    if (!mounted) return;
    
    if (picked != null) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_manualTimestamp ?? _fitData!.startTime!),
      );
      
      if (!mounted) return;
      
      if (timePicked != null) {
        final DateTime selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          timePicked.hour,
          timePicked.minute,
          _manualTimestamp?.second ?? 0,
        );
        
        setState(() {
          _manualTimestamp = selectedDateTime;
          _useManualTime = true;
        });
        
        print('\n=== Manual Time Set ===');
        print('Selected time: $selectedDateTime');
        print('Using manual time: $_useManualTime');
        print('=== Manual Time End ===\n');
        
        _matchAndCalculate();
      }
    }
  }
  
  void _matchAndCalculate() {
    if (_fitData == null) return;
    
    final DateTime? timeToUse = _useManualTime ? _manualTimestamp : _imageTimestamp;
    
    if (timeToUse == null) {
      print('\n=== Matching Skipped ===');
      print('No time available for matching');
      print('=== Matching End ===\n');
      return;
    }
    
    print('\n=== Time Source ===');
    print('Using: ${_useManualTime ? "Manual Time" : "EXIF Time"}');
    print('Time value: $timeToUse');
    print('=== Time Source End ===\n');
    
    final matched = _fitData!.findPointAtTime(timeToUse);
    setState(() {
      _matchedPoint = matched;
    });
  }
  
  _ImageDisplayInfo _calculateImageDisplayArea(Size containerSize, Size imageOriginalSize) {
    final containerWidth = containerSize.width;
    final containerHeight = containerSize.height;
    final imageWidth = imageOriginalSize.width;
    final imageHeight = imageOriginalSize.height;
    
    final containerRatio = containerWidth / containerHeight;
    final imageRatio = imageWidth / imageHeight;
    
    double displayWidth;
    double displayHeight;
    double offsetX;
    double offsetY;
    
    if (imageRatio > containerRatio) {
      displayWidth = containerWidth;
      displayHeight = containerWidth / imageRatio;
      offsetX = 0;
      offsetY = (containerHeight - displayHeight) / 2;
    } else {
      displayHeight = containerHeight;
      displayWidth = containerHeight * imageRatio;
      offsetX = (containerWidth - displayWidth) / 2;
      offsetY = 0;
    }
    
    print('\n=== Image Display Calculation ===');
    print('Container: ${containerWidth.toInt()} x ${containerHeight.toInt()}');
    print('Image original: ${imageWidth.toInt()} x ${imageHeight.toInt()}');
    print('Display area: ${displayWidth.toInt()} x ${displayHeight.toInt()}');
    print('Offset: (${offsetX.toInt()}, ${offsetY.toInt()})');
    print('=== Display Calculation End ===\n');
    
    return _ImageDisplayInfo(
      displaySize: Size(displayWidth, displayHeight),
      offset: Offset(offsetX, offsetY),
    );
  }
  
Future<void> _saveImageWithOverlay() async {
    if (_imagePath == null || _matchedPoint == null) {
      setState(() {
        _errorMessage = 'Please select an image and match GPS data first';
      });
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Load original image
      final originalImageFile = File(_imagePath!);
      final originalBytes = await originalImageFile.readAsBytes();
      final originalCodec = await ui.instantiateImageCodec(originalBytes);
      final originalFrame = await originalCodec.getNextFrame();
      final originalUiImage = originalFrame.image;
      
      // Create a new canvas with original image size
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final originalSize = Size(originalUiImage.width.toDouble(), originalUiImage.height.toDouble());
      
      // Draw original image
      canvas.drawImage(originalUiImage, Offset.zero, Paint());
      
      // Calculate overlay scale for original image
      if (_imageOriginalSize != null && _imageDisplaySize != null) {
        final scaleX = originalSize.width / _imageDisplaySize!.width;
        
        // Draw overlay on original image (scaled)
        final overlayPainter = OverlayPainter(
          gpsPoints: _fitData!.gpsPoints,
          currentPosition: _matchedPoint,
          imageTimestamp: (_useManualTime ? _manualTimestamp : _imageTimestamp)!,
          imageSize: originalSize,
          activityName: _activityName,
          trackColor: _trackColor,
          trackWidth: _trackWidth * scaleX,
          positionColor: _positionColor,
          positionRadius: _positionRadius * scaleX,
          textColor: _textColor,
          textSize: _textSize * scaleX,
          showTrack: _showTrack,
          showPosition: _showPosition,
          showPace: _showPace,
          showTimestamp: _showTimestamp,
        );
        
        overlayPainter.paint(canvas, originalSize);
      }
      
      // Convert to image
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(
        originalSize.width.toInt(),
        originalSize.height.toInt(),
      );
      
      // Check original file format
      final isOriginalJpg = _imagePath!.toLowerCase().endsWith('.jpg') || 
                           _imagePath!.toLowerCase().endsWith('.jpeg');
      
      // Decide format based on original
      late final Uint8List outputBytes;
      late final String formatName;
      
      if (isOriginalJpg) {
        // For JPG originals, convert to JPG with quality 85
        final pngData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
        if (pngData == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to convert image';
          });
          return;
        }
        
        final pngBytes = pngData.buffer.asUint8List();
        final decodedImage = img.decodeImage(pngBytes);
        if (decodedImage == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to decode image';
          });
          return;
        }
        
        // Use quality 70 for optimal file size (good quality/size balance)
        outputBytes = img.encodeJpg(decodedImage, quality: 70);
        formatName = 'JPG (quality 70)';
      } else {
        // For PNG originals, keep as PNG
        final pngData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
        if (pngData == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to convert image';
          });
          return;
        }
        
        outputBytes = pngData.buffer.asUint8List();
        formatName = 'PNG';
      }
      
      // Save file
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final activityPrefix = _activityName.isNotEmpty ? '${_activityName}_' : '';
      final extension = isOriginalJpg ? 'jpg' : 'png';
      final defaultFileName = '${activityPrefix}overlay_$timestamp.$extension';
      
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Image with Overlay',
        fileName: defaultFileName,
        allowedExtensions: isOriginalJpg ? ['jpg', 'jpeg'] : ['png'],
      );
      
      if (result != null) {
        final file = File(result);
        await file.writeAsBytes(outputBytes);
        
        print('\n=== Image Saved ===');
        print('File: $result');
        print('Size: ${originalSize.width.toInt()} x ${originalSize.height.toInt()}');
        print('File size: ${(outputBytes.length / 1024).toStringAsFixed(1)} KB');
        print('Format: $formatName');
        print('=== End ===\n');
        
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved: ${result.split('\\').last} (${(outputBytes.length / 1024).toStringAsFixed(1)} KB)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Overlay on Photo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
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
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Select Image'),
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
              
              if (_fitData != null && _fitData!.startTime != null)
                const SizedBox(height: 16),
              
              if (_fitData != null && _fitData!.startTime != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'FIT File Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      if (_fitData!.activityType != null)
                        Text('Activity: ${_fitData!.activityType!}'),
                      
                      Text('Start Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_fitData!.startTime!)}'),
                      Text('End Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_fitData!.endTime!)}'),
                      Text('Duration: ${_fitData!.formatTotalDuration()}'),
                      Text('Total Distance: ${_fitData!.formatTotalDistance()}'),
                      Text('GPS Points: ${_fitData!.gpsPoints.length}'),
                      
const SizedBox(height: 16),
              
              TextField(
                decoration: InputDecoration(
                  labelText: 'Activity Name (optional)',
                  hintText: 'e.g., Morning Run, Marathon 2024',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                ),
                onChanged: (value) {
                  setState(() {
                    _activityName = value;
                  });
                },
              ),
              
              const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      
                      Text(
                        'Time Selection',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      if (_imageTimestamp != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EXIF Time (from image):',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm:ss').format(_imageTimestamp!),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      
                      if (_imageTimestamp == null)
                        Text(
                          'No EXIF time found in image',
                          style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      CheckboxListTile(
                        title: const Text('Use Manual Time'),
                        subtitle: Text(
                          _useManualTime 
                            ? 'Manual time will be used for GPS matching'
                            : 'EXIF time (if available) will be used',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        value: _useManualTime,
                        onChanged: (value) {
                          setState(() {
                            _useManualTime = value ?? false;
                          });
                          _matchAndCalculate();
                        },
                      ),
                      
                      if (_useManualTime)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Manual Time:',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _manualTimestamp != null
                                        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_manualTimestamp!)
                                        : 'Not set - click button to select',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _manualTimestamp != null ? Colors.black : Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _selectManualTime,
                                icon: const Icon(Icons.edit, size: 18),
                                label: Text(_manualTimestamp != null ? 'Change' : 'Select'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_useManualTime ? Colors.orange.shade100 : Colors.green.shade100),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _useManualTime ? Icons.edit : Icons.check_circle,
                              size: 16,
                              color: (_useManualTime ? Colors.orange[700] : Colors.green[700]),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Currently using: ${_useManualTime ? "Manual Time" : "EXIF Time"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: (_useManualTime ? Colors.orange[700] : Colors.green[700]),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      if (_matchedPoint != null)
                        const SizedBox(height: 12),
                      
                      if (_matchedPoint != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 16, color: Colors.green[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'GPS Point Matched',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Lat: ${_matchedPoint!.latitude.toStringAsFixed(6)}', style: const TextStyle(fontSize: 12)),
                              Text('Lon: ${_matchedPoint!.longitude.toStringAsFixed(6)}', style: const TextStyle(fontSize: 12)),
                              if (_matchedPoint!.speed != null)
                                Text('Speed: ${(_matchedPoint!.speed! * 3.6).toStringAsFixed(1)} km/h', style: const TextStyle(fontSize: 12)),
                              if (_matchedPoint!.altitude != null)
                                Text('Altitude: ${_matchedPoint!.altitude!.toStringAsFixed(0)} m', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              
              if (_imagePath != null && _matchedPoint != null)
                const SizedBox(height: 16),
              
              if (_imagePath != null && _matchedPoint != null)
                ElevatedButton.icon(
                  onPressed: _saveImageWithOverlay,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Image with Overlay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              
              if (_imagePath != null)
                const SizedBox(height: 16),
              
              if (_imagePath != null)
                RepaintBoundary(
                  key: _imageKey,
                  child: SizedBox(
                    height: 400,
                    child: ClipRect(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 3.0,
                        constrained: true,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final containerSize = constraints.biggest;
                            
                            if (_imageOriginalSize != null) {
                              final displayInfo = _calculateImageDisplayArea(containerSize, _imageOriginalSize!);
                              _imageDisplaySize = displayInfo.displaySize;
                              _imageDisplayOffset = displayInfo.offset;
                            }
                            
                            return Stack(
                              children: [
                                SizedBox(
                                  width: containerSize.width,
                                  height: containerSize.height,
                                  child: Image.file(
                                    File(_imagePath!),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                if (_fitData != null && _matchedPoint != null && _imageDisplaySize != null && _imageDisplayOffset != null)
                                  Positioned(
                                    left: _imageDisplayOffset!.dx,
                                    top: _imageDisplayOffset!.dy,
                                    child: SizedBox(
                                      width: _imageDisplaySize!.width,
                                      height: _imageDisplaySize!.height,
                                      child: CustomPaint(
                                        painter: OverlayPainter(
                                          gpsPoints: _fitData!.gpsPoints,
                                          currentPosition: _matchedPoint,
                                          imageTimestamp: (_useManualTime ? _manualTimestamp : _imageTimestamp)!,
                                          imageSize: _imageDisplaySize!,
                                          activityName: _activityName,
                                          trackColor: _trackColor,
                                          trackWidth: _trackWidth,
                                          positionColor: _positionColor,
                                          positionRadius: _positionRadius,
                                          textColor: _textColor,
                                          showTrack: _showTrack,
                                          showPosition: _showPosition,
                                          showPace: _showPace,
                                          showTimestamp: _showTimestamp,
                                        ),
                                        size: _imageDisplaySize!,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
    );
  }
}
