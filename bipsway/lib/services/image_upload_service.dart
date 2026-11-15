import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

import '../core/constants/cloudinary_config.dart';

abstract interface class ImageUploadService {
  Future<String> uploadImage(File file, String path);
}

class CloudinaryImageUploadService implements ImageUploadService {
  const CloudinaryImageUploadService();

  @override
  Future<String> uploadImage(File file, String path) async {
    final compressed = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      // Large phone/emulator images are unnecessarily expensive to upload.
      // The original dimensions are read separately for floor-plan pin math;
      // this only controls the Cloudinary copy.
      minWidth: 1600,
      minHeight: 1600,
      quality: 80,
      inSampleSize: 2,
      format: CompressFormat.jpeg,
    );
    final bytes = compressed ?? await file.readAsBytes();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(CloudinaryConfig.uploadEndpoint),
    )
      ..fields['upload_preset'] = CloudinaryConfig.unsignedUploadPreset
      ..fields['folder'] = path
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: '${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

    final response = await request.send().timeout(
      const Duration(minutes: 2),
      onTimeout: () => throw const ImageUploadException(
        'Image upload timed out. Check the emulator internet connection and try again.',
      ),
    );
    final body = await response.stream.bytesToString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ImageUploadException(
        data['error']?['message'] as String? ?? 'Cloudinary upload failed.',
      );
    }
    final url = data['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      throw const ImageUploadException('Cloudinary returned no image URL.');
    }
    return url;
  }
}

class ImageUploadException implements Exception {
  const ImageUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}

// Swap this implementation for Firebase Storage without changing callers.
final ImageUploadService imageUploadService =
    const CloudinaryImageUploadService();
