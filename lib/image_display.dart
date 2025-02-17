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
  String? currentSocketDirection;
  bool isReconnecting = false;
  int currentDelay = 5;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the connection state for changes
    final connectionState = ref.watch(connectionStateProvider);
    
    // React to delay changes
    if (currentDelay != connectionState.delaySeconds) {
      // Use Future.microtask to avoid calling setState during build
      Future.microtask(() => _updateCarouselTimer());
    }
    
    // React to socket direction changes
    if (connectionState.socketDirection != null && 
        connectionState.socketDirection != currentSocketDirection) {
      Future.microtask(() => _reconnect());
    }

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

  void _updateCarouselTimer() {
    carouselTimer?.cancel();
    final delaySeconds = ref.read(connectionStateProvider).delaySeconds;
    if (currentDelay != delaySeconds) {
      print('Updating carousel timer to $delaySeconds seconds');
    }
    currentDelay = delaySeconds;
    carouselTimer = Timer.periodic(Duration(seconds: delaySeconds), (timer) {
      if (channel != null) {
        print('Requesting new image... (delay: $delaySeconds seconds)');
        channel!.sink.add("REQUEST_IMAGE");
      }
    });
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
      currentSocketDirection = socketDirection;  // Update the current socket direction

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

      _updateCarouselTimer();
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    if (isReconnecting) return;
    isReconnecting = true;

    carouselTimer?.cancel();
    channel?.sink.close();
    currentSocketDirection = null;  // Reset the current socket direction

    if (ref.read(connectionStateProvider).socketDirection != null) {
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          _connectWebSocket();
          isReconnecting = false;
        }
      });
    } else {
      isReconnecting = false;
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
