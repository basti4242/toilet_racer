import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:toilet_racer/app/constants.dart';

class GameOverMenu extends StatelessWidget {
  final VoidCallback onBackToMenuPressed, onPlayPressed;
  final int score;

  const GameOverMenu(this.onBackToMenuPressed, this.onPlayPressed, this.score);

  @override
  Widget build(BuildContext context) {
    final buttonStyle = Theme.of(context).textTheme.headline2;
    final titleStyle = buttonStyle.copyWith(
        fontSize: Theme.of(context).textTheme.headline1.fontSize, height: 1);
    final dividerHeight = 5.0;
    final blur = 10.0;
    final backgroundColor = buttonStyle.color;

    const spacing = 16.0;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        padding: const EdgeInsets.all(kStartMenuMargin),
        color: Colors.orangeAccent.withOpacity(0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Divider(
                        thickness: dividerHeight, color: backgroundColor),
                  ),
                ),
                Icon(Icons.star_border, size: 128, color: backgroundColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Divider(
                        thickness: dividerHeight, color: backgroundColor),
                  ),
                ),
              ],
            ),
            Text(score.toString(), style: titleStyle),
            Divider(thickness: dividerHeight, color: backgroundColor),
            SizedBox(height: spacing),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                children: [
                  TextButton(
                    onPressed: onBackToMenuPressed,
                    child: Text('HOME', style: buttonStyle),
                  ),
                  SizedBox(height: spacing),
                  TextButton(
                    onPressed: onPlayPressed,
                    child: Text('TRY AGAIN', style: buttonStyle),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
