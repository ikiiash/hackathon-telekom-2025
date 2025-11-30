import 'package:flutter/material.dart';

/// Один елемент у списку чатів у боковому меню
class ChatListItem {
  final String id;
  final String title;
  final DateTime? updatedAt;

  ChatListItem({
    required this.id,
    required this.title,
    this.updatedAt,
  });
}

class ChatDrawer extends StatelessWidget {
  final VoidCallback onProfilePressed;
  final VoidCallback onNewChatPressed;

  /// Список чатів поточного юзера
  final List<ChatListItem> chats;

  /// Викликається, коли юзер тапнув по чату в списку
  final void Function(ChatListItem chat) onChatSelected;

  const ChatDrawer({
    super.key,
    required this.onProfilePressed,
    required this.onNewChatPressed,
    required this.chats,
    required this.onChatSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
        // Back arrow at the top
        SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_outlined),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close drawer',
          ),
        ),
      ),

      // New Chat - White rounded rectangle
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            onNewChatPressed();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_outlined, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'New Chat',
                  style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),

      const Divider(height: 1),

      // Chats section header
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Chats',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ),
      ),


      // Scrollable chat history (реальні чати)
      Expanded(
        child: chats.isEmpty
            ? const Center(
          child: Text(
            'No chats yet',
            style: TextStyle(color: Colors.grey),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  onChatSelected(chat);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.title.isNotEmpty
                            ? chat.title
                            : 'Untitled chat',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (chat.updatedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Updated: ${chat.updatedAt}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),

      const Divider(height: 1),

      // Profile button
      ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.person_outline, size: 20),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 16),
        ),
        onTap: () {
          Navigator.pop(context);
          onProfilePressed();
        },
      ),


          // About app button
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.info_outline, size: 20),
            ),
            title: const Text(
              'About app',
              style: TextStyle(fontSize: 16),
            ),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About TrustAI'),
                  content: const Text(
                    'TrustAI v1.0\n\n'
                        'AI-powered fact-checking assistant that helps you:\n\n'
                        '• Verify factual claims\n'
                        '• Detect AI-generated content\n'
                        '• Analyze image authenticity\n\n'
                        'Powered by advanced AI technology.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
