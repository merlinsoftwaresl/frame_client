import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

class ImageDisplay extends StatefulWidget {
  final String socketDirection;
  const ImageDisplay({super.key, required this.socketDirection});

  @override
  ImageDisplayState createState() => ImageDisplayState();
}

class ImageDisplayState extends State<ImageDisplay> {
  IOWebSocketChannel? channel;
  Timer? carouselTimer;
  String? imageDataString;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    channel = IOWebSocketChannel.connect('ws://${widget.socketDirection}');
    print('Attempting to connect to WebSocket at ws://${widget.socketDirection}...');

    channel!.stream.listen(
      (message) {
        print('Image received');
        _updateImage(message);
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

    carouselTimer = Timer.periodic(Duration(seconds: 10), (timer) {
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
    final decoded = _decodeImageData(newData);
    if (decoded != null) {
      setState(() {
        imageDataString = newData;
      });
    } else {
      print("Decoding failed, keeping last image");
    }
  }

  @override
  void dispose() {
    carouselTimer?.cancel();
    channel?.sink.close(status.goingAway);
    super.dispose();
  }

  Uint8List? _decodeImageData(String? dataString) {
    if (dataString == null) return null;
    if (dataString.startsWith("data:")) {
      try {
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
    Widget buildPlaceholder() {
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

    Widget buildError() {
      return Container(
        key: ValueKey("error"),
        alignment: Alignment.center,
        child: Text(
          'Error decoding image data',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    if (imageDataString == null) {
      return buildPlaceholder();
    }

    final bytes = _decodeImageData(imageDataString);
    if (bytes == null) {
      return buildError();
    }

    return Image.memory(
      bytes,
      key: ValueKey(imageDataString), // Unique key for each image
      fit: BoxFit.contain,
    );
  }
}
