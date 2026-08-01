import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import 'editable_avatar.dart';
import 'editable_banner.dart';
import 'edit_profile_dialog.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, this.collapsed = false});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final profile = ProfileController.instance;
    return AnimatedBuilder(
      animation: profile,
      builder: (context, _) {
        if (collapsed) return _collapsedHeader(context, profile);
        return _expandedHeader(context, profile);
      },
    );
  }

  Widget _collapsedHeader(BuildContext context, ProfileController profile) =>
      SizedBox(
        height: 112,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xFF15121F))),
            Positioned(
              left: 24,
              top: 16,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF6D35F5),
                ),
                child: CircleAvatar(
                  radius: 35,
                  backgroundImage:
                      profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                      ? NetworkImage(profile.avatarUrl!)
                      : const AssetImage('assets/images/avatar.png'),
                ),
              ),
            ),
            Positioned(
              left: 118,
              top: 29,
              right: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.username,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        color: Colors.greenAccent,
                        size: 9,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        profile.status,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 24,
              top: 33,
              child: OutlinedButton.icon(
                onPressed: () => showEditProfileDialog(context),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Editar'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      );

  Widget _expandedHeader(
    BuildContext context,
    ProfileController profile,
  ) => SizedBox(
    height: 270,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 185,
          child: EditableBanner(),
        ),
        const Positioned(left: 34, top: 90, child: EditableAvatar()),
        Positioned(
          left: 215,
          top: 197,
          right: 290,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      profile.username,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 19,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                  const SizedBox(width: 7),
                  Text(
                    profile.status,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 14,
                    ),
                  ),
                  if (profile.handle.isNotEmpty) ...[
                    const SizedBox(width: 14),
                    Text(
                      '@${profile.handle}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
              if (profile.motto.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  profile.motto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          right: 30,
          top: 207,
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => showEditProfileDialog(context),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar perfil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D35F5),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Compartir'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
