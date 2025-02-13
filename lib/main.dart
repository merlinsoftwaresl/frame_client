import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frame_client/qr_connection.dart';

void main() {
  runApp(
    const ProviderScope(
      child: FrameClientApp(),
    ),
  );
}

class FrameClientApp extends StatelessWidget {
  const FrameClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frame Client',
      home: QrConnection(),
    );
  }
}
