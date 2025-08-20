import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ContributeScreen extends StatefulWidget {
  const ContributeScreen({super.key});

  @override
  _ContributeScreenState createState() => _ContributeScreenState();
}

class _ContributeScreenState extends State<ContributeScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _capturedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Open camera immediately when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openCamera();
    });
  }

  Future<void> _openCamera() async {
    setState(() => _isLoading = true);
    
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // Compress image to 80% quality
      );
      
      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
        });
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contribute'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _capturedImage == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No photo captured'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _openCamera,
                    child: const Text('Take Photo'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Image.file(_capturedImage!),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _openCamera,
                        child: const Text('Retake'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Next step - process the image
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Image processing will be implemented next')),
                          );
                        },
                        child: const Text('Use This Photo'),
        ),
                    ],
                  ),
                ),
              ],
      ),
    );
  }
}
