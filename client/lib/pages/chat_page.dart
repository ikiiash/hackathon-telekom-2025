import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../widgets/dotted_background.dart';
import '../widgets/chat_header.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_drawer.dart';
import 'profile_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();
  final List<ChatMessage> _messages = [];
  final Uuid _uuid = const Uuid();

  File? _selectedImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        // IMPORTANT: No compression/resizing to preserve EXIF metadata
        // maxWidth, maxHeight, and imageQuality would strip metadata
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    
    if (text.isEmpty && _selectedImage == null) return;

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      text: text,
      type: MessageType.user,
      timestamp: DateTime.now(),
      imagePath: _selectedImage?.path,
      status: MessageStatus.sent,
    );

    setState(() {
      _messages.add(userMessage);
      _messageController.clear();
      _isLoading = true;
    });

    final imageFile = _selectedImage;
    setState(() {
      _selectedImage = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      // Send to Edge Function
      final result = await _chatService.processMessage(
        text: text.isEmpty ? 'Analyze this image for authenticity and AI generation.' : text,
        imageFile: imageFile,
      );

      // Create bot response
      final botMessage = ChatMessage(
        id: _uuid.v4(),
        text: _formatAnalysisResult(result),
        type: MessageType.bot,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
        analysisResult: result,
      );

      setState(() {
        _messages.add(botMessage);
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Add bot error response
      final errorMessage = ChatMessage(
        id: _uuid.v4(),
        text: 'Sorry, I couldn\'t process that. Please try again.',
        type: MessageType.bot,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

      setState(() {
        _messages.add(errorMessage);
      });
      
      _showNotification('Unable to analyze content. Please try again.');
    }
  }

  String _formatAnalysisResult(Map<String, dynamic> result) {
    // Return the response directly from the backend
    if (result.containsKey('response')) {
      return result['response'];
    }
    
    // Fallback: return JSON as string if no response field
    return result.toString();
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _selectedImage = null;
      _messageController.clear();
    });
  }



  void _showNotification(String message) {
    if (!mounted) return;
    
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[800], size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  void _showError(String message) {
    _showNotification(message);
  }

  Widget _buildCapabilityChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.red[700],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: ChatDrawer(
        onProfilePressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          );
        },
        onNewChatPressed: _clearChat,
      ),
      body: Builder(
        builder: (BuildContext scaffoldContext) {
          return DottedBackground(
            child: Column(
              children: [
                // Custom header
                ChatHeader(
                  onMenuPressed: () {
                    Scaffold.of(scaffoldContext).openDrawer();
                  },
                  onProfilePressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfilePage()),
                    );
                  },
                  onNewChatPressed: _clearChat,
                ),
            // Messages list
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'lib/assets/logo.png',
                            width: 80,
                            height: 80,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'TrustAI',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your AI-Powered\nFact-Checking Assistant',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildCapabilityChip('✓ Fact-Checking Analysis'),
                          const SizedBox(height: 12),
                          _buildCapabilityChip('✓ AI-Generated Content Detection'),
                          const SizedBox(height: 12),
                          _buildCapabilityChip('✓ Image Authenticity Verification'),
                          const SizedBox(height: 40),
                          Text(
                            'Send a message or image to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
          ),

          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  SizedBox(width: 16),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Analyzing...'),
                ],
              ),
            ),

          // Input widget
          ChatInput(
            messageController: _messageController,
            selectedImage: _selectedImage,
            isLoading: _isLoading,
            onPickImage: _pickImage,
            onRemoveImage: () {
              setState(() {
                _selectedImage = null;
              });
            },
            onSendMessage: _sendMessage,
          ),
        ],
      ),
      );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.type == MessageType.user;
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.red[100],
              child: const Icon(Icons.smart_toy, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? Colors.red[400] : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imagePath != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(message.imagePath!),
                          width: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  if (message.text.isNotEmpty) const SizedBox(height: 4),
                  Text(
                    timeFormat.format(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.red[100],
              child: const Icon(Icons.person_outline, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}
