import 'dart:io';
import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController messageController;
  final File? selectedImage;
  final bool isLoading;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSendMessage;

  const ChatInput({
    super.key,
    required this.messageController,
    required this.selectedImage,
    required this.isLoading,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image preview
        if (selectedImage != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    selectedImage!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Image selected'),
                ),
                IconButton(
                  icon: const Icon(Icons.close_outlined),
                  onPressed: onRemoveImage,
                ),
              ],
            ),
          ),

        // Input field - Capsule design
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SafeArea(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Paperclip icon inside capsule
                  IconButton(
                    icon: Icon(Icons.attach_file_outlined, size: 22, color: Colors.grey[700]),
                    onPressed: isLoading ? null : onPickImage,
                    tooltip: 'Attach image',
                    padding: const EdgeInsets.all(8),
                  ),
                  // Text field
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 100),
                      child: SingleChildScrollView(
                        child: TextField(
                          controller: messageController,
                          decoration: InputDecoration(
                            hintText: 'Message VerifAI...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            isDense: true,
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          enabled: !isLoading,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  // Send button inside capsule - circular with red background
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: isLoading ? Colors.grey[400] : Colors.red[600],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: isLoading ? null : onSendMessage,
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
