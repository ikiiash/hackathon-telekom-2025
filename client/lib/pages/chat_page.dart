import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:lottie/lottie.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../widgets/dotted_background.dart';
import '../widgets/chat_header.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_drawer.dart'; // тут є ChatDrawer і ChatListItem
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

  /// Список чатів поточного юзера (для бокового меню)
  final List<ChatListItem> _chats = [];

  File? _selectedImage;
  bool _isLoading = false;

  /// Поточний активний чат (id з БД). Якщо null — це новий чат,
  /// який ще не збережений у таблиці `chat`.
  String? _currentChatId;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final rawChats = await _chatService.fetchChats();
      setState(() {
        _chats
          ..clear()
          ..addAll(
            rawChats.map((row) {
              return ChatListItem(
                id: row['id'] as String,
                title: (row['title'] as String?) ?? '',
                updatedAt: row['updated_at'] != null
                    ? DateTime.parse(row['updated_at'] as String)
                    : null,
              );
            }),
          );
      });
    } catch (e) {
      debugPrint('Failed to load chats: $e');
    }
  }

  Future<void> _openChat(ChatListItem chat) async {
    try {
      final loadedMessages =
      await _chatService.fetchChatMessages(chat.id); // з БД -> ChatMessage

      setState(() {
        _currentChatId = chat.id;
        _messages
          ..clear()
          ..addAll(loadedMessages);
        _selectedImage = null;
        _messageController.clear();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      debugPrint('Failed to open chat: $e');
      _showNotification('Failed to load chat. Please try again.');
    }
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

    // 1) локальне user-повідомлення (саме те, що ввів юзер)
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
      final result = await _chatService.processMessage(
        text: text.isEmpty ? null : text,
        imageFile: imageFile,
        chatId: _currentChatId, // якщо null -> бекенд створить новий чат
      );

      // якщо це був перший меседж у новому чаті — зберігаємо chat_id
      final newChatId = result['chat_id'] as String?;
      if (_currentChatId == null && newChatId != null) {
        _currentChatId = newChatId;
        // оновлюємо список чатів у боковому меню
        await _loadChats();
      }

      // створюємо відповідь бота
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
    if (result.containsKey('response')) {
      return result['response'];
    }
    return result.toString();
  }

  /// New Chat:
  /// - чистить локальні повідомлення
  /// - скидає _currentChatId = null
  /// Запис у БД зʼявиться тільки після першої відповіді бота.
  void _startNewChat() {
    setState(() {
      _messages.clear();
      _selectedImage = null;
      _messageController.clear();
      _currentChatId = null;
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
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                Icon(Icons.info_outline,
                    color: Colors.grey[800], size: 22),
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

  Widget _buildCapabilityPill(String text) {
    IconData icon;
    if (text.contains('image')) {
      icon = Icons.image_outlined;
    } else if (text.contains('text')) {
      icon = Icons.description_outlined;
    } else {
      icon = Icons.link_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.red[300]!, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        drawer: ChatDrawer(
          chats: _chats,
          onChatSelected: (chat) => _openChat(chat),
          onProfilePressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfilePage(),
              ),
            );
          },
          onNewChatPressed: _startNewChat,
        ),
        body: Builder(
            builder: (BuildContext scaffoldContext) {
              return DottedBackground(
                child: Column(
                    children: [
                    // Header
                    ChatHeader(
                    onMenuPressed: () {
              Scaffold.of(scaffoldContext).openDrawer();
              },
                onProfilePressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  );
                },
                onNewChatPressed: _startNewChat,
              ),

              // Messages list
              Expanded(
              child: _messages.isEmpty
              ? Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Text(
              'Hello I\'m Evida',
              style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
              ),
              ),
              const SizedBox(height: 24),
              Lottie.asset(
              'assets/bot_animation/Untitled file.json',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Text(
              'How can I help you?',
              style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
              ),
              ),
              const SizedBox(height: 16),
              Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
              _buildCapabilityPill('Check image'),
              _buildCapabilityPill('Check text'),
              ],
              ),
              ],
              ),
              )
              // ? Center(
              // child: SingleChildScrollView(
              // padding: const EdgeInsets.all(32.0),
              // child: Column(
              // mainAxisAlignment: MainAxisAlignment.center,
              // children: [
              // Image.asset(
              // 'assets/logo.png',
              // width: 80,
              // height: 80,
              // ),
              // const SizedBox(height: 24),
              // Text(
              // 'TrustAI',
              // style: TextStyle(
              // fontSize: 32,
              // fontWeight: FontWeight.bold,
              // color: Colors.red[700],
              // ),
              // ),
              // const SizedBox(height: 16),
              // Text(
              // 'Your AI-Powered\nFact-Checking Assistant',
              // textAlign: TextAlign.center,
              // style: TextStyle(
              // fontSize: 20,
              // fontWeight: FontWeight.w500,
              // color: Colors.grey[700],
              // ),
              // ),
              // const SizedBox(height: 32),
              // _buildCapabilityChip(
              // '✓ Fact-Checking Analysis',
              // ),
              // const SizedBox(height: 12),
              // _buildCapabilityChip(
              // '✓ AI-Generated Content Detection',
              // ),
              // const SizedBox(height: 12),
              // _buildCapabilityChip(
              // '✓ Image Authenticity Verification',
              // ),
              // const SizedBox(height: 40),
              // Text(
              // 'Send a message or image to get started',

              //   style: TextStyle(
              //     fontSize: 14,
              //     color: Colors.grey[500],
              //   ),
              // ),
              // ],
              // ),
              // ),
              // )
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _MessageBubble(
                    message: _messages[index],
                  );
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
              backgroundColor: Colors.transparent,
              child: ClipOval(
                child: Image.asset(
                  'assets/bot_small.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
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
                  if (message.imagePath == null && message.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          message.imageUrl!,
                          width: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 200,
                              height: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image, size: 40),
                            );
                          },
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
