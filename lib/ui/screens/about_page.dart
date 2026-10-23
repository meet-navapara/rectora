import 'package:flutter/material.dart';
import 'package:rectora/theme/palette.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = RectoraTheme.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Rectora is a logic game. Parcels covers a grid with rectangles. '
          'Trace draws one orthogonal path through every open cell, visiting numbers in order. '
          'Inks covers the grid with connected regions that do not have to be rectangles. '
          'Threads joins matching letters. You can play as a guest or sign in with Google. '
          'An internet connection is required to open the game.',
        ),
      ),
    );
  }
}
