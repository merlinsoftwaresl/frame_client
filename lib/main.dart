import 'package:flutter/material.dart';
import 'package:frame_client/image_display.dart';

void main() {
  runApp(FrameClientApp());
}

class FrameClientApp extends StatelessWidget {
  const FrameClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frame Client',
      home: ImageDisplay(),
    );
  }
}
