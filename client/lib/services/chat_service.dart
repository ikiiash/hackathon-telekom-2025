import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';

class ChatService {
  final _supabase = Supabase.instance.client;

  /// Uploads an image to Supabase Storage and returns the public URL
  Future<String> uploadImage(File imageFile) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final filePath = 'uploads/$fileName';

      // Determine content type from file extension
      String contentType = 'image/jpeg';
      final ext = imageFile.path.split('.').last.toLowerCase();
      if (ext == 'png') contentType = 'image/png';
      if (ext == 'heic' || ext == 'heif') contentType = 'image/heic';
      if (ext == 'webp') contentType = 'image/webp';

      // Read bytes async, not sync
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase Storage
      await _supabase.storage.from('fact-checker-images').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          upsert: false,
          contentType: contentType,
        ),
      );

      // Get public URL
      final imageUrl =
      _supabase.storage.from('fact-checker-images').getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Calls the Supabase Edge Function for analysis.
  /// If chatId is provided, backend will append messages to that chat.
  Future<Map<String, dynamic>> analyzeContent({
    String? text, // може бути null/порожній при фото-only
    String? imageUrl,
    String? chatId,
  }) async {
    try {
      final body = <String, dynamic>{
        if (text != null) 'text': text,
        if (imageUrl != null) 'image_url': imageUrl,
        if (chatId != null) 'chat_id': chatId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await _supabase.functions.invoke(
        'analyze-content',
        body: body,
      );

      if (response.status == 200) {
        // backend повертає { chat_id, response, ... }
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception(
          'Edge function returned status: ${response.status} | ${response.data}',
        );
      }
    } catch (e) {
      throw Exception('Failed to analyze content: $e');
    }
  }

  /// Complete flow: optional image upload + analyze with Edge Function.
  ///
  /// Повертає JSON з бекенду, де ти зможеш взяти:
  ///   result['chat_id']  - поточний чат
  ///   result['response'] - текст відповіді асистента
  Future<Map<String, dynamic>> processMessage({
    String? text, // дозв. порожній для чистого фото
    File? imageFile,
    String? chatId, // поточний чат (може бути null для першого меседжа)
  }) async {
    String? imageUrl;

    // Upload image if present
    if (imageFile != null) {
      imageUrl = await uploadImage(imageFile);
    }

    if ((text == null || text.trim().isEmpty) && imageUrl == null) {
      throw Exception('Either text or image must be provided');
    }

    // Call Edge Function for analysis (backend handles chat + history)
    final result = await analyzeContent(
      text: text,
      imageUrl: imageUrl,
      chatId: chatId,
    );

    return result;
  }

  /// =========================
  ///  ЧАТИ ДЛЯ БОКОВОГО МЕНЮ
  /// =========================

  /// Тягне всі чати поточного користувача (RLS на бекенді вже фільтрує по auth.uid())
  Future<List<Map<String, dynamic>>> fetchChats() async {
    try {
      final res = await _supabase
          .from('chat')
          .select('id, title, created_at, updated_at')
          .order('updated_at', ascending: false)
          .order('created_at', ascending: false);

      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to fetch chats: $e');
    }
  }


  /// Тягне всі повідомлення конкретного чату
  Future<List<ChatMessage>> fetchChatMessages(String chatId) async {
    try {
      final res = await _supabase
          .from('message')
          .select('id, role, content, image_url, created_at, debug')
          .eq('chat_id', chatId)
          .order('created_at', ascending: true);

      final list = (res as List).cast<Map<String, dynamic>>();

      return list.map((row) {
        final role = row['role'] as String?;
        final isUser = role == 'user';

        return ChatMessage(
          id: row['id'] as String,
          text: row['content'] as String? ?? '',
          type: isUser ? MessageType.user : MessageType.bot,
          timestamp: DateTime.parse(row['created_at'] as String),
          imageUrl: row['image_url'] as String?,
          imagePath: null,
          status: MessageStatus.sent,
          analysisResult: row['debug'] is Map<String, dynamic>
              ? row['debug'] as Map<String, dynamic>
              : null,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch chat messages: $e');
    }
  }
}
