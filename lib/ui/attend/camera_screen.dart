import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:lottie/lottie.dart';

import 'attend_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late FaceDetector faceDetector;
  List<CameraDescription>? cameras;
  CameraController? controller;
  XFile? image;
  bool isBusy = false;
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && !Platform.isWindows) {
      _initializeFaceDetector();
    }
    _initializeCamera();
  }

  void _initializeFaceDetector() {
    faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Skip camera initialization on web
      if (!kIsWeb && !Platform.isWindows) {
        cameras = await availableCameras();

        if (cameras == null || cameras!.isEmpty) {
          throw Exception('No cameras available on this device');
        }

        // Find front camera
        final frontCamera = cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => cameras!.first,
        );

        controller = CameraController(
          frontCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await controller!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Camera not available on this platform';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
      debugPrint('Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    if (!kIsWeb && !Platform.isWindows) {
      faceDetector.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          "Face Capture",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _buildCameraContent(size),
    );
  }

  Widget _buildCameraContent(Size size) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    if (!_isCameraInitialized || controller == null) {
      return _buildInitializingState();
    }

    return _buildCameraView(size);
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            SizedBox(height: 20),
            Text(
              "Initializing Camera...",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, color: Colors.white, size: 64),
              const SizedBox(height: 20),
              Text(
                "Camera Error",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage.contains('No cameras available')
                    ? "No camera found on this device"
                    : "Unable to access camera",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _initializeCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Try Again",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitializingState() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 20),
            Text(
              "Setting up camera...",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView(Size size) {
    return Stack(
      children: [
        // Camera Preview
        SizedBox(
          height: size.height,
          width: size.width,
          child: CameraPreview(controller!),
        ),

        // Face Detection Overlay
        _buildFaceDetectionOverlay(),

        // Bottom Controls
        _buildBottomControls(size),
      ],
    );
  }

  Widget _buildFaceDetectionOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Lottie.asset("assets/raw/face_id_ring.json", fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildBottomControls(Size size) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: size.width,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.yellow[300],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Ensure your face is clearly visible in the frame",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Capture Button
            _buildCaptureButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _captureImage,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          color: Colors.transparent,
        ),
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Icon(Icons.camera_alt, color: Colors.black, size: 32),
        ),
      ),
    );
  }

  Future<void> _captureImage() async {
    if (isBusy || controller == null || !controller!.value.isInitialized) {
      return;
    }

    try {
      setState(() => isBusy = true);

      // Check location permission first
      final hasLocationPermission = await _checkLocationPermission();
      if (!hasLocationPermission) {
        setState(() => isBusy = false);
        return;
      }

      // Take picture
      final XFile capturedImage = await controller!.takePicture();

      // Process face detection
      await _processFaceDetection(capturedImage);
    } catch (e) {
      debugPrint('Error capturing image: $e');
      _showErrorSnackBar('Failed to capture image: $e');
    } finally {
      if (mounted) {
        setState(() => isBusy = false);
      }
    }
  }

  Future<bool> _checkLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('Please enable location services to continue');
        return false;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('Location permission is required for attendance');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('Please enable location permission in app settings');
        return false;
      }

      return true;
    } catch (e) {
      _showErrorSnackBar('Error checking location permission');
      return false;
    }
  }

  Future<void> _processFaceDetection(XFile capturedImage) async {
    try {
      _showProcessingDialog();

      final inputImage = InputImage.fromFilePath(capturedImage.path);
      final List<Face> faces = await faceDetector.processImage(inputImage);

      // Close processing dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (faces.isNotEmpty) {
        // Face detected - navigate to attendance screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AttendScreen(image: capturedImage),
            ),
          );
        }
      } else {
        // No face detected
        _showErrorSnackBar(
          'No face detected. Please ensure your face is clearly visible in good lighting',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      _showErrorSnackBar('Error processing face detection: $e');
    }
  }

  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              "Verifying Face...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: duration,
      ),
    );
  }
}
