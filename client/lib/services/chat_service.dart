import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final _supabase = Supabase.instance.client;

  /// Uploads an image to Supabase Storage and returns the public URL
  Future<String> uploadImage(File imageFile) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final filePath = 'uploads/$fileName';

      // Determine content type from file extension
      String contentType = 'image/jpeg';
      final ext = imageFile.path.split('.').last.toLowerCase();
      if (ext == 'png') contentType = 'image/png';
      if (ext == 'heic' || ext == 'heif') contentType = 'image/heic';
      if (ext == 'webp') contentType = 'image/webp';

      // Upload to Supabase Storage with original bytes
      await _supabase.storage.from('fact-checker-images').uploadBinary(
            filePath,
            imageFile.readAsBytesSync(),
            fileOptions: FileOptions(
              upsert: false,
              contentType: contentType,
            ),
          );

      // Get public URL
      final imageUrl = _supabase.storage.from('fact-checker-images').getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Sends text and optional image to Supabase Edge Function for analysis
  Future<Map<String, dynamic>> analyzeContent({
    required String text,
    String? imageUrl,
  }) async {
    try {
      // Call the Supabase Edge Function
      final response = await _supabase.functions.invoke(
        'analyze-content',
        body: {
          'text': text,
          if (imageUrl != null) 'image_url': imageUrl,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (response.status == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Edge function returned status: ${response.status}');
      }
    } catch (e) {
      throw Exception('Failed to analyze content: $e');
    }
  }

  /// Complete flow: upload image if present, then analyze with Edge Function
  Future<Map<String, dynamic>> processMessage({
    required String text,
    File? imageFile,
  }) async {
    String? imageUrl;

    // Upload image if present
    if (imageFile != null) {
      imageUrl = await uploadImage(imageFile);
    }

    // Call Edge Function for analysis (backend handles everything)
    final result = await analyzeContent(
      text: text,
      imageUrl: imageUrl,
    );

    return result;
  }
}
