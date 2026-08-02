import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/direct_message_service.dart';
import '../../services/friend_service.dart';
import '../../services/notification_service.dart';
import '../chat/direct_message_sheet.dart';

class TopBarAlerts extends StatefulWidget {
  const TopBarAlerts({super.key});

  @override
  State<TopBarAlerts> createState() => _TopBarAlertsState();
}

class _TopBarAlertsState extends State<TopBarAlerts> {
  final _friends = FriendService();
  final _messages = DirectMessageService();
  final _notifications = NotificationService();
  late Future<List<Map<String, dynamic>>> _requests;
  late Future<List<Map<String, dynamic>>> _inbox;
  late Future<List<Map<String, dynamic>>> _activity;
  Timer? _refreshTimer;
  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();
    _reload();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _reload(),
    );
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _notificationChannel = Supabase.instance.client
          .channel('topbar-notifications-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'recipient_id',
              value: userId,
            ),
            callback: (_) => _reload(),
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final channel = _notificationChannel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _requests = _friends.getPendingRequests();
      _inbox = _messages.getInbox();
      _activity = _notifications.getNotifications();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: Future.wait<dynamic>([_requests, _inbox, _activity]),
    builder: (context, snapshot) {
      final requests =
          snapshot.data?.first as List<Map<String, dynamic>>? ?? const [];
      final inbox =
          snapshot.data?[1] as List<Map<String, dynamic>>? ?? const [];
      final activity =
          snapshot.data?[2] as List<Map<String, dynamic>>? ?? const [];
      final unread = inbox
          .where((message) => message['read_at'] == null)
          .length;
      return Row(
        children: [
          _requestsMenu(requests),
          const SizedBox(width: 10),
          _messagesMenu(inbox, unread),
          const SizedBox(width: 10),
          _notificationsMenu(requests, inbox, unread, activity),
        ],
      );
    },
  );

  Widget _requestsMenu(List<Map<String, dynamic>> requests) => MenuAnchor(
    style: _menuStyle,
    menuChildren: [SizedBox(width: 320, child: _requestsContent(requests))],
    builder: (context, controller, _) => _alertButton(
      icon: Icons.person_add_alt_1_rounded,
      count: requests.length,
      tooltip: 'Solicitudes de amistad',
      onTap: () => controller.isOpen ? controller.close() : controller.open(),
    ),
  );

  Widget _messagesMenu(List<Map<String, dynamic>> messages, int unread) =>
      MenuAnchor(
        style: _menuStyle,
        menuChildren: [SizedBox(width: 340, child: _messagesContent(messages))],
        builder: (context, controller, _) => _alertButton(
          icon: Icons.chat_bubble_outline_rounded,
          count: unread,
          tooltip: 'Mensajes',
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      );

  Widget _notificationsMenu(
    List<Map<String, dynamic>> requests,
    List<Map<String, dynamic>> inbox,
    int unread,
    List<Map<String, dynamic>> activity,
  ) => MenuAnchor(
    style: _menuStyle,
    menuChildren: [
      SizedBox(
        width: 340,
        child: _notificationsContent(requests, inbox, unread, activity),
      ),
    ],
    builder: (context, controller, _) => _alertButton(
      icon: Icons.notifications_none_rounded,
      count: activity.where((item) => item['read_at'] == null).length,
      tooltip: 'Notificaciones',
      onTap: () async {
        if (controller.isOpen) {
          controller.close();
          return;
        }
        controller.open();
        try {
          await _notifications.markAllRead();
          _reload();
        } catch (_) {}
      },
    ),
  );

  Widget _requestsContent(List<Map<String, dynamic>> requests) => _menuShell(
    title: 'Solicitudes de amistad',
    empty: 'No tienes solicitudes pendientes.',
    children: requests.map((request) {
      final sender = Map<String, dynamic>.from(
        request['sender'] as Map? ?? const {},
      );
      final name = sender['username']?.toString() ?? 'Usuario';
      final avatar = sender['avatar_url']?.toString() ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            _avatar(name, avatar),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Aceptar',
              onPressed: () async {
                await _friends.acceptRequest(request['id'].toString());
                _reload();
              },
              icon: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF4EE6A2),
              ),
            ),
            IconButton(
              tooltip: 'Rechazar',
              onPressed: () async {
                await _friends.rejectRequest(request['id'].toString());
                _reload();
              },
              icon: const Icon(Icons.cancel_outlined, color: Color(0xFFFF7187)),
            ),
          ],
        ),
      );
    }).toList(),
  );

  Widget _messagesContent(List<Map<String, dynamic>> messages) => _menuShell(
    title: 'Mensajes',
    empty: 'Aún no tienes mensajes.',
    children: messages.map((message) {
      final sender = Map<String, dynamic>.from(
        message['sender'] as Map? ?? const {},
      );
      final name = sender['username']?.toString() ?? 'Usuario';
      final avatar = sender['avatar_url']?.toString() ?? '';
      final preview = message['content']?.toString() ?? '';
      return InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () async {
          // El chat debe poder abrirse aunque aún no se haya aplicado la
          // política SQL que permite marcar mensajes como leídos.
          try {
            await _messages.markMessagesFromRead(
              message['sender_id'].toString(),
            );
          } catch (_) {}
          if (!mounted) return;
          _reload();
          await showDirectMessageSheet(
            context,
            userId: message['sender_id'].toString(),
            username: name,
            avatarUrl: avatar,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _avatar(name, avatar),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (message['read_at'] == null)
                const Icon(Icons.circle, size: 9, color: Color(0xFF8B5CF6)),
            ],
          ),
        ),
      );
    }).toList(),
  );

  Widget _notificationsContent(
    List<Map<String, dynamic>> requests,
    List<Map<String, dynamic>> inbox,
    int unread,
    List<Map<String, dynamic>> activity,
  ) {
    final notifications = <Widget>[];
    for (final request in requests) {
      final sender = Map<String, dynamic>.from(
        request['sender'] as Map? ?? const {},
      );
      notifications.add(
        _notice(
          Icons.person_add_alt_1_rounded,
          '${sender['username'] ?? 'Alguien'} te envió una solicitud.',
        ),
      );
    }
    for (final message in inbox.where((item) => item['read_at'] == null)) {
      final sender = Map<String, dynamic>.from(
        message['sender'] as Map? ?? const {},
      );
      notifications.add(
        _notice(
          Icons.chat_bubble_outline_rounded,
          '${sender['username'] ?? 'Alguien'} te envió un mensaje.',
        ),
      );
    }
    for (final item in activity) {
      final actor = Map<String, dynamic>.from(
        item['actor'] as Map? ?? const {},
      );
      final name = actor['username']?.toString() ?? 'Alguien';
      final type = item['type']?.toString() ?? '';
      final details = switch (type) {
        'like' => ('dio Me gusta a tu publicación.', Icons.favorite_rounded),
        'comment' => ('comentó tu publicación.', Icons.mode_comment_outlined),
        'mention' => (
          'te mencionó en una publicación.',
          Icons.alternate_email_rounded,
        ),
        'share' => ('compartió tu publicación.', Icons.share_outlined),
        'friend_request' => (
          'te envió una solicitud de amistad.',
          Icons.person_add_alt_1_rounded,
        ),
        'message' => (
          'te envió un mensaje.',
          Icons.chat_bubble_outline_rounded,
        ),
        _ => ('tiene una interacción nueva.', Icons.notifications_none_rounded),
      };
      notifications.add(_notice(details.$2, '$name ${details.$1}'));
    }
    return _menuShell(
      title: 'Notificaciones',
      empty: 'No hay notificaciones nuevas.',
      children: notifications,
    );
  }

  Widget _notice(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF29213F),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFAF8CFF), size: 17),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _menuShell({
    required String title,
    required String empty,
    required List<Widget> children,
  }) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Divider(color: Color(0xFF39324F), height: 22),
        if (children.isEmpty)
          Text(
            empty,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          )
        else
          ...children,
      ],
    ),
  );

  Widget _avatar(String name, String url) => CircleAvatar(
    radius: 18,
    backgroundColor: const Color(0xFF6D35F5),
    backgroundImage: url.isEmpty ? null : NetworkImage(url),
    child: url.isEmpty
        ? Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          )
        : null,
  );

  Widget _alertButton({
    required IconData icon,
    required int count,
    required String tooltip,
    required VoidCallback onTap,
  }) => Tooltip(
    message: tooltip,
    child: InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF211D2E),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
          if (count > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF8B5CF6),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  static const _menuStyle = MenuStyle(
    backgroundColor: WidgetStatePropertyAll(Color(0xFF211E2E)),
    elevation: WidgetStatePropertyAll(12),
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: Color(0xFF39324F)),
      ),
    ),
  );
}
