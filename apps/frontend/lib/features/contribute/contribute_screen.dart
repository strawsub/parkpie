import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;  
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

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
  
  // Upload photos to cloud
  Future<void> _uploadPhoto() async {
    if (_capturedImage == null) return;

    setState(() => _isLoading = true);

    try {
      final file = _capturedImage!;
      final fileName =
          DateTime.now().millisecondsSinceEpoch.toString() + ".jpg";

      // Azure Blob SAS URL
      final url = Uri.parse(
        "https://parkpie.blob.core.windows.net/sign-photo-container/$fileName"
        "?sp=rac&st=2025-08-21T03:30:32Z&se=2025-12-21T10:45:32Z&spr=https&sv=2024-11-04&sr=c&sig=1UreYplNAKWeImXjTxXJ1OTSAlRQ3lO2kVHWEaHhpkE%3D",
      );

      final bytes = await file.readAsBytes();

      // upload photo to blob
      final response = await http.put(
        url,
        headers: {
          "x-ms-blob-type": "BlockBlob",
          "Content-Type": "image/jpeg",
        },
        body: bytes,
      );

      if (response.statusCode == 201) {
        // get gps location
        LocationPermission permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No GPS Permission')),
          );
          return;
        }

        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

        double lat = position.latitude;
        double lng = position.longitude;

        // call Spring Boot API and save signs metadata
        final metadataResponse = await http.post(
          Uri.parse("https://parkpie-90018.azurewebsites.net/signs"),
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            "text": fileName, 
            "lat": lat,
            "lng": lng,
          }),
        );

        if (metadataResponse.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload + Metadata success!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Metadata API failed: ${metadataResponse.statusCode}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed! Code: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
                        onPressed: _uploadPhoto, 
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