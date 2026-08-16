import 'package:supabase_flutter/supabase_flutter.dart';

class PollSnapshot {
  const PollSnapshot({required this.counts, this.selectedOption});

  final List<int> counts;
  final int? selectedOption;

  int get totalVotes => counts.fold(0, (sum, count) => sum + count);
}

class PollService {
  PollService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<PollSnapshot> load(String postId, int optionCount) async {
    final userId = _client.auth.currentUser?.id;
    final rows = await _client
        .from('poll_votes')
        .select('user_id, option_index')
        .eq('post_id', postId);
    final counts = List<int>.filled(optionCount, 0);
    int? selectedOption;
    for (final row in rows) {
      final index = row['option_index'] as int?;
      if (index != null && index >= 0 && index < optionCount) {
        counts[index]++;
        if (row['user_id'] == userId) selectedOption = index;
      }
    }
    return PollSnapshot(counts: counts, selectedOption: selectedOption);
  }

  Future<void> vote(String postId, int optionIndex) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Debes iniciar sesión para votar.');
    await _client.from('poll_votes').upsert({
      'post_id': postId,
      'user_id': userId,
      'option_index': optionIndex,
    }, onConflict: 'post_id,user_id');
  }
}
