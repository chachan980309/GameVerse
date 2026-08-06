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
  
  List<Map<String, dynamic>> _requestsList = [];
  List<Map<String, dynamic>> _inboxList = [];
  List<Map<String, dynamic>> _activityList = [];
  bool _loading = true;
  bool _hasMoreNotifications = true;
  bool _loadingMore = false;

  Timer? _refreshTimer;
  RealtimeChannel? _notificationChannel;
  OverlayEntry? _messagesOverlay;
  OverlayEntry? _notificationsOverlay;
  int _notificationLimit = 10;

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
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'direct_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'sender_id',
              value: userId,
            ),
            callback: (_) => _reload(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'direct_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id',
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
    _messagesOverlay?.remove();
    _notificationsOverlay?.remove();
    final channel = _notificationChannel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final results = await Future.wait([
        _friends.getPendingRequests(),
        _messages.getInbox(),
        _notifications.getNotifications(offset: 0, limit: 10),
      ]);

      if (!mounted) return;
      setState(() {
        _requestsList = results[0];
        _inboxList = results[1];
        _activityList = results[2];
        _loading = false;
        _hasMoreNotifications = results[2].length == 10;
        _notificationLimit = 10; // Resetear límite visual al recargar
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_loadingMore || !_hasMoreNotifications) return;
    setState(() => _loadingMore = true);

    try {
      final nextItems = await _notifications.getNotifications(
        offset: _activityList.length,
        limit: 10,
      );

      if (!mounted) return;
      setState(() {
        final existingIds = _activityList.map((item) => item['id'].toString()).toSet();
        for (final item in nextItems) {
          if (!existingIds.contains(item['id'].toString())) {
            _activityList.add(item);
          }
        }
        _loadingMore = false;
        _hasMoreNotifications = nextItems.length == 10;
        _notificationLimit = _activityList.length;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 146,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
          ),
        ),
      );
    }

    final unread = _inboxList
        .where((message) => message['has_unread'] == true)
        .length;

    return Row(
      children: [
        _requestsMenu(_requestsList),
        const SizedBox(width: 10),
        _messagesMenu(_inboxList, unread),
        const SizedBox(width: 10),
        _notificationsMenu(_requestsList, _inboxList, unread, _activityList),
      ],
    );
  }

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
      _alertButton(
        icon: Icons.chat_bubble_outline_rounded,
        count: unread,
        tooltip: 'Mensajes',
        onTap: () => _toggleMessagesPanel(messages),
      );

  void _toggleMessagesPanel(List<Map<String, dynamic>> messages) {
    if (_messagesOverlay != null) {
      _closeMessagesPanel();
      return;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    _messagesOverlay = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: 72,
        right: screenWidth > 1200 ? 300 : 16,
        child: TapRegion(
          onTapOutside: (_) => _closeMessagesPanel(),
          child: Material(
            color: const Color(0xFF171520),
            elevation: 16,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 360,
              constraints: const BoxConstraints(maxHeight: 520),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF39324F)),
              ),
              child: _messagesContent(messages),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_messagesOverlay!);
  }

  void _closeMessagesPanel() {
    _messagesOverlay?.remove();
    _messagesOverlay = null;
  }

  Widget _notificationsMenu(
    List<Map<String, dynamic>> requests,
    List<Map<String, dynamic>> inbox,
    int unread,
    List<Map<String, dynamic>> activity,
  ) => _alertButton(
    icon: Icons.notifications_none_rounded,
    count: activity.where((item) => item['read_at'] == null).length,
    tooltip: 'Notificaciones',
    onTap: () => _toggleNotificationsPanel(requests, inbox, unread, activity),
  );

  void _toggleNotificationsPanel(
    List<Map<String, dynamic>> requests,
    List<Map<String, dynamic>> inbox,
    int unread,
    List<Map<String, dynamic>> activity,
  ) async {
    if (_notificationsOverlay != null) {
      _closeNotificationsPanel();
      return;
    }

    try {
      await _notifications.markAllRead();
      _reload();
    } catch (_) {}

    final screenWidth = MediaQuery.sizeOf(context).width;
    _notificationsOverlay = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: 72,
        right: screenWidth > 1200 ? 250 : 16,
        child: TapRegion(
          onTapOutside: (_) => _closeNotificationsPanel(),
          child: Material(
            color: const Color(0xFF171520),
            elevation: 16,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 340,
              constraints: const BoxConstraints(maxHeight: 520),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF39324F)),
              ),
              child: _notificationsContent(requests, inbox, unread, activity),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_notificationsOverlay!);
  }

  void _closeNotificationsPanel() {
    _notificationsOverlay?.remove();
    _notificationsOverlay = null;
  }

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

  Widget _messagesContent(List<Map<String, dynamic>> messages) {
    var query = '';

    return StatefulBuilder(
      builder: (context, setMenuState) {
        final filtered = messages.where((message) {
          final user = Map<String, dynamic>.from(
            message['other_user'] as Map? ?? const {},
          );
          final name = user['username']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase());
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: TextField(
                  onChanged: (value) => setMenuState(() => query = value),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Buscar chat',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Colors.white38,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF211D2E),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const Divider(color: Color(0xFF39324F), height: 22),
              if (filtered.isEmpty)
                const Text(
                  'No se encontraron chats.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 390),
                  child: ListView(
                    shrinkWrap: true,
                    children: filtered.map(_conversationTile).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _conversationTile(Map<String, dynamic> message) {
    final user = Map<String, dynamic>.from(
      message['other_user'] as Map? ?? const {},
    );
    final name = user['username']?.toString() ?? 'Usuario';
    final avatar = user['avatar_url']?.toString() ?? '';
    final content = message['content']?.toString() ?? '';
    final preview = message['is_mine'] == true ? 'Tú: $content' : content;

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () async {
        final otherUserId = message['other_user_id'].toString();
        try {
          await _messages.markMessagesFromRead(otherUserId);
        } catch (_) {}
        if (!mounted) return;
        _reload();
        _closeMessagesPanel();
        await showDirectMessageSheet(
          context,
          userId: otherUserId,
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
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (message['has_unread'] == true)
              const Icon(Icons.circle, size: 9, color: Color(0xFF8B5CF6)),
          ],
        ),
      ),
    );
  }

  Widget _notificationsContent(
    List<Map<String, dynamic>> requests,
    List<Map<String, dynamic>> inbox,
    int unread,
    List<Map<String, dynamic>> activity,
  ) {
    final List<_NotificationItem> rawItems = [];

    // 1. Unificar Solicitudes de Amistad
    for (final request in requests) {
      final sender = Map<String, dynamic>.from(
        request['sender'] as Map? ?? const {},
      );
      final name = sender['username']?.toString() ?? 'Alguien';
      final time = DateTime.tryParse(request['created_at']?.toString() ?? '') ?? DateTime.now();
      rawItems.add(_NotificationItem(
        id: 'req-${request['id']}',
        type: 'friend_request',
        text: 'te envió una solicitud de amistad.',
        icon: Icons.person_add_alt_1_rounded,
        time: time,
        isRead: false,
        actorName: name,
        rawItem: request,
      ));
    }

    // 2. Unificar Mensajes no leídos
    for (final message in inbox.where((item) => item['has_unread'] == true)) {
      final sender = Map<String, dynamic>.from(
        message['other_user'] as Map? ?? const {},
      );
      final name = sender['username']?.toString() ?? 'Alguien';
      final time = DateTime.tryParse(message['created_at']?.toString() ?? '') ?? DateTime.now();
      rawItems.add(_NotificationItem(
        id: 'msg-${message['other_user_id']}',
        type: 'message',
        text: 'te envió un mensaje.',
        icon: Icons.chat_bubble_outline_rounded,
        time: time,
        isRead: false,
        actorName: name,
        rawItem: message,
      ));
    }

    // 3. Unificar Actividades de Supabase
    for (final item in activity) {
      final actor = Map<String, dynamic>.from(
        item['actor'] as Map? ?? const {},
      );
      final name = actor['username']?.toString() ?? 'Alguien';
      final type = item['type']?.toString() ?? '';
      final isRead = item['read_at'] != null;
      final time = DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now();

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

      rawItems.add(_NotificationItem(
        id: 'act-${item['id']}',
        type: type,
        text: details.$1,
        icon: details.$2,
        time: time,
        isRead: isRead,
        actorName: name,
        rawItem: item,
      ));
    }

    // 4. Ordenar: Las nuevas arriba (Requisito 4)
    rawItems.sort((a, b) => b.time.compareTo(a.time));

    // 5. Agrupar notificaciones iguales (Requisitos 6 y 7)
    final groupedItems = _groupNotifications(rawItems);

    // 6. Filtrar por límite (Requisito 1)
    final limitedItems = groupedItems.take(_notificationLimit).toList();

    // 7. Generar listado con Separadores de Día (Requisito 8)
    final List<Widget> listWidgets = [];
    String? currentDayLabel;

    for (final item in limitedItems) {
      final dayLabel = _dayLabel(item.time);
      if (dayLabel != currentDayLabel) {
        currentDayLabel = dayLabel;
        listWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Text(
                  dayLabel.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFAF8CFF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Divider(color: const Color(0xFF39324F).withOpacity(0.3), height: 1)),
              ],
            ),
          ),
        );
      }
      listWidgets.add(_noticeWidget(item));
    }

    // 8. Botón Cargar Más si existen más notificaciones (Requisito 3)
    final hasMore = groupedItems.length > _notificationLimit;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Notificaciones',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (rawItems.any((item) => !item.isRead))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${rawItems.where((item) => !item.isRead).length} Nuevas',
                    style: const TextStyle(color: Color(0xFFAF8CFF), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const Divider(color: Color(0xFF39324F), height: 22),
          if (groupedItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No tienes notificaciones nuevas.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            )
          else ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: listWidgets,
              ),
            ),
            if (hasMore) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: TextButton.icon(
                  onPressed: _loadingMore ? null : _loadMoreNotifications,
                  icon: _loadingMore
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFAF8CFF)),
                        )
                      : const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFFAF8CFF)),
                  label: Text(
                    _loadingMore ? 'Cargando...' : 'Cargar más notificaciones',
                    style: const TextStyle(color: Color(0xFFAF8CFF), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF29213F).withOpacity(0.6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'No hay más notificaciones.',
                  style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _noticeWidget(_NotificationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: item.isRead ? Colors.transparent : const Color(0xFF29213F).withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono con su cajita
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1F1A30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: item.isRead ? Colors.transparent : const Color(0xff8B5CF6).withOpacity(0.2)),
            ),
            child: Icon(item.icon, color: const Color(0xFFAF8CFF), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                    children: [
                      TextSpan(
                        text: item.actorName,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(text: item.text),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Tiempo relativo
                Text(
                  _relativeTime(item.time),
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // Punto morado de no leído (Requisito 5)
          if (!item.isRead) ...[
            const SizedBox(width: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(top: 14),
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: Color(0xFF8B5CF6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'hace ${diff.inSeconds} s';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return 'hace ${diff.inDays ~/ 7} sem';
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate == today) return 'Hoy';
    if (compareDate == yesterday) return 'Ayer';
    final diffDays = today.difference(compareDate).inDays;
    return 'Hace $diffDays días';
  }

  List<_NotificationItem> _groupNotifications(List<_NotificationItem> input) {
    if (input.isEmpty) return [];

    final List<_NotificationItem> result = [];
    int i = 0;
    while (i < input.length) {
      final current = input[i];

      // Agrupar Me gustas consecutivos (Requisitos 6 y 7)
      if (current.type == 'like') {
        int count = 1;
        final List<String> otherActors = [];
        int j = i + 1;
        while (j < input.length && input[j].type == 'like') {
          final nextItem = input[j];
          if (nextItem.actorName == current.actorName) {
            count++;
          } else {
            if (!otherActors.contains(nextItem.actorName)) {
              otherActors.add(nextItem.actorName);
            }
          }
          j++;
        }

        if (count > 1) {
          result.add(_NotificationItem(
            id: current.id,
            type: 'like_grouped',
            text: 'dio Me gusta a $count publicaciones.',
            icon: Icons.favorite_rounded,
            time: current.time,
            isRead: current.isRead,
            actorName: current.actorName,
            rawItem: current.rawItem,
          ));
          i = j;
          continue;
        } else if (otherActors.isNotEmpty) {
          final totalOthers = otherActors.length;
          result.add(_NotificationItem(
            id: current.id,
            type: 'like_grouped_others',
            text: 'y otras $totalOthers personas dieron Me gusta.',
            icon: Icons.favorite_rounded,
            time: current.time,
            isRead: current.isRead,
            actorName: current.actorName,
            rawItem: current.rawItem,
          ));
          i = j;
          continue;
        }
      }

      // Agrupar comentarios consecutivos del mismo usuario (Requisitos 6 y 7)
      if (current.type == 'comment') {
        int count = 1;
        int j = i + 1;
        while (j < input.length && input[j].type == 'comment' && input[j].actorName == current.actorName) {
          count++;
          j++;
        }
        if (count > 1) {
          result.add(_NotificationItem(
            id: current.id,
            type: 'comment_grouped',
            text: 'comentó en $count de tus publicaciones.',
            icon: Icons.mode_comment_outlined,
            time: current.time,
            isRead: current.isRead,
            actorName: current.actorName,
            rawItem: current.rawItem,
          ));
          i = j;
          continue;
        }
      }

      result.add(current);
      i++;
    }

    return result;
  }

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

class _NotificationItem {
  _NotificationItem({
    required this.id,
    required this.type,
    required this.text,
    required this.icon,
    required this.time,
    required this.isRead,
    required this.actorName,
    required this.rawItem,
  });

  final String id;
  final String type;
  final String text;
  final IconData icon;
  final DateTime time;
  final bool isRead;
  final String actorName;
  final Map<String, dynamic> rawItem;
}
