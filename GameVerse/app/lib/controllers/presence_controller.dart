import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceController extends ChangeNotifier {
  static final PresenceController instance = PresenceController._internal();
  factory PresenceController() => instance;
  PresenceController._internal();

  RealtimeChannel? _presenceChannel;
  Set<String> _onlineUserIds = {};

  Set<String> get onlineUserIds => _onlineUserIds;
  bool isUserOnline(String userId) => _onlineUserIds.contains(userId);

  void startPresence() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _presenceChannel = Supabase.instance.client.channel('online-users');
    _presenceChannel!.onPresenceSync((payload) {
      final state = _presenceChannel!.presenceState();
      final Set<String> onlineIds = {};

      for (final singlePresence in state) {
        final presences = singlePresence.presences;
        for (final presence in presences) {
          final payload = presence.payload;
          if (payload != null && payload['user_id'] != null) {
            onlineIds.add(payload['user_id'].toString());
          }
        }
      }

      _onlineUserIds = onlineIds;
      notifyListeners();
    }).subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _presenceChannel!.track({
          'user_id': userId,
          'online_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });
  }

  void stopPresence() {
    final channel = _presenceChannel;
    _presenceChannel = null;
    if (channel != null) {
      channel.untrack();
      Supabase.instance.client.removeChannel(channel);
    }
    _onlineUserIds.clear();
    notifyListeners();
  }
}
