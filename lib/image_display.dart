import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frame_client/providers/connection_provider.dart';

class ImageDisplay extends ConsumerStatefulWidget {
  const ImageDisplay({super.key});

  @override
  ConsumerState<ImageDisplay> createState() => ImageDisplayState();
}

class ImageDisplayState extends ConsumerState<ImageDisplay> {
  IOWebSocketChannel? channel;
  Timer? carouselTimer;
  String? imageDataString;
  String? currentSocketDirection;  // Add this to track the current connection

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newSocketDirection = ref.read(connectionStateProvider).socketDirection;
    
    // If we have a new socket direction and it's different from the current one
    if (newSocketDirection != null && newSocketDirection != currentSocketDirection) {
      _reconnect();
    }
  }

  void _connectWebSocket() {
    final socketDirection = ref.read(connectionStateProvider).socketDirection;
    if (socketDirection == null || socketDirection.isEmpty) {
      print('No valid socket direction available');
      return;
    }

    try {
      final wsUrl = 'ws://$socketDirection';
      print('Attempting to connect to WebSocket at $wsUrl');
      channel = IOWebSocketChannel.connect(wsUrl);

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
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    carouselTimer?.cancel();
    channel?.sink.close();
    
    // Only attempt reconnection if we still have a valid socket direction
    if (ref.read(connectionStateProvider).socketDirection != null) {
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          _connectWebSocket();
        }
      });
    }
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
