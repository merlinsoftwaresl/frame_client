import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

void main() {
  runApp(FrameClientApp());
}

class FrameClientApp extends StatelessWidget {
  const FrameClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frame Client',
      home: CarouselPage(),
    );
  }
}

class CarouselPage extends StatefulWidget {
  const CarouselPage({super.key});

  @override
  _CarouselPageState createState() => _CarouselPageState();
}

class _CarouselPageState extends State<CarouselPage> {
  IOWebSocketChannel? channel;
  Timer? carouselTimer;
  String? imageDataString;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    // Connect to the server.
    channel = IOWebSocketChannel.connect('ws://localhost:8080');
    print('Attempting to connect to WebSocket...');

    // Listen for incoming messages (assumed to be image data).
    channel!.stream.listen(
      (message) {
        print('Image received');
        _updateImage(message);
        // Send acknowledgment back to the server.
        try {
          channel!.sink.add("ACK");
          print('Acknowledgment sent.');
        } catch (error) {
          print('Failed to send ACK: $error');
        }
      },
      onDone: () {
        print('WebSocket closed. Reconnecting in 2 seconds...');
        _reconnect();
      },
      onError: (error) {
        print('WebSocket error: $error');
        _reconnect();
      },
    );

    // Start the carousel: send a "REQUEST_IMAGE" every 5 seconds.
    carouselTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (channel != null) {
        print('Requesting new image...');
        channel!.sink.add("REQUEST_IMAGE");
      }
    });
  }

  void _reconnect() {
    carouselTimer?.cancel();
    Future.delayed(Duration(seconds: 2), () {
      _connectWebSocket();
    });
  }

  void _updateImage(String newData) {
    // Update the state with the new image data.
    setState(() {
      imageDataString = newData;
    });
  }

  @override
  void dispose() {
    carouselTimer?.cancel();
    channel?.sink.close(status.goingAway);
    super.dispose();
  }

  /// Utility: If the string is a data URL, extract and decode the Base64 part.
  Uint8List? _decodeImageData(String? dataString) {
    if (dataString == null) return null;
    if (dataString.startsWith("data:")) {
      try {
        // Format: data:[<mime type>][;charset=<charset>][;base64],<encoded data>
        final commaIndex = dataString.indexOf(',');
        if (commaIndex == -1) return null;
        final base64Str = dataString.substring(commaIndex + 1);
        return base64Decode(base64Str);
      } catch (e) {
        print("Error decoding base64 image: $e");
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: _buildImageWidget(),
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    // If we haven't received any image yet, show a placeholder.
    if (imageDataString == null) {
      return Container(
        key: ValueKey("placeholder"),
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        alignment: Alignment.center,
        child: Text(
          'Awaiting Image...',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      );
    }

    final bytes = _decodeImageData(imageDataString);
    if (bytes == null) {
      // If decoding failed, show an error message.
      return Container(
        key: ValueKey("error"),
        alignment: Alignment.center,
        child: Text(
          'Error decoding image data',
          style: TextStyle(color: Colors.red),
        ),
      );
    } else {
      return Image.memory(
        bytes,
        key: ValueKey(imageDataString),
        fit: BoxFit.contain,
      );
    }
  }
}
