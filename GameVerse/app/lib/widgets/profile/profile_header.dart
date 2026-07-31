import 'package:flutter/material.dart';

import 'editable_banner.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 220, child: EditableBanner());
  }
}
