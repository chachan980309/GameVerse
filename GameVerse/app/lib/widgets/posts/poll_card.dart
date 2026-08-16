import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../services/poll_service.dart';

class PollCard extends StatefulWidget {
  const PollCard({super.key, required this.post});

  final PostModel post;

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  final PollService _pollService = PollService();
  late Future<PollSnapshot> _poll;

  @override
  void initState() {
    super.initState();
    _poll = _pollService.load(widget.post.id, widget.post.pollOptions.length);
  }

  @override
  void didUpdateWidget(covariant PollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _poll = _pollService.load(widget.post.id, widget.post.pollOptions.length);
    }
  }

  Future<void> _vote(int index) async {
    try {
      await _pollService.vote(widget.post.id, index);
      if (mounted) {
        setState(
          () => _poll = _pollService.load(
            widget.post.id,
            widget.post.pollOptions.length,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.post.pollQuestion;
    final options = widget.post.pollOptions;
    if (question == null || question.isEmpty || options.length < 2) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151321),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5B3D88)),
      ),
      child: FutureBuilder<PollSnapshot>(
        future: _poll,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final hasVoted = data?.selectedOption != null;
          final total = data?.totalVotes ?? 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.poll_rounded, color: Color(0xFFFFB74D), size: 19),
                  SizedBox(width: 7),
                  Text(
                    'ENCUESTA',
                    style: TextStyle(
                      color: Color(0xFFFFC46B),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                question,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(options.length, (index) {
                final votes = data?.counts[index] ?? 0;
                final percent = total == 0 ? 0.0 : votes / total;
                final selected = data?.selectedOption == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap:
                        snapshot.connectionState == ConnectionState.done &&
                            !hasVoted
                        ? () => _vote(index)
                        : null,
                    borderRadius: BorderRadius.circular(9),
                    child: Ink(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF211D2E),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFF39324F),
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (hasVoted)
                            FractionallySizedBox(
                              widthFactor: percent,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF7B4DFF,
                                  ).withValues(alpha: .24),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                if (selected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF9C70FF),
                                    size: 17,
                                  ),
                                if (selected) const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    options[index],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (hasVoted)
                                  Text(
                                    '${(percent * 100).round()}%',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              Text(
                '$total ${total == 1 ? 'voto' : 'votos'}${hasVoted ? '' : ' · Elige una respuesta'}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}
