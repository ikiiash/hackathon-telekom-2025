enum MessageType { user, bot }

enum MessageStatus { sending, sent, error }

class ChatMessage {
  final String id;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final String? imageUrl;
  final String? imagePath; // Local path for preview
  final MessageStatus status;
  final Map<String, dynamic>? analysisResult;

  ChatMessage({
    required this.id,
    required this.text,
    required this.type,
    required this.timestamp,
    this.imageUrl,
    this.imagePath,
    this.status = MessageStatus.sent,
    this.analysisResult,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    MessageType? type,
    DateTime? timestamp,
    String? imageUrl,
    String? imagePath,
    MessageStatus? status,
    Map<String, dynamic>? analysisResult,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      analysisResult: analysisResult ?? this.analysisResult,
    );
  }
}
