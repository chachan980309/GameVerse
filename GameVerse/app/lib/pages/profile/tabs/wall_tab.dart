import 'package:app/widgets/post/post_create_box.dart';
import 'package:flutter/material.dart';

class WallTab extends StatelessWidget {
  const WallTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(children: [PostCreateBox()]);
  }
}
