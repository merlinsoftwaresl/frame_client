import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frame_client/providers/connection_provider.dart';

class ImageDisplay extends ConsumerStatefulWidget {
  const ImageDisplay({super.key});

  @override
  ConsumerState<ImageDisplay> createState() => ImageDisplayState();
}

class ImageDisplayState extends ConsumerState<ImageDisplay> {
  Timer? carouselTimer;
  Uint8List? imageData;
  String? serverUrl;
  int currentDelay = 5;

  @override
  void initState() {
    super.initState();
    _initializeImageFetching();
  }

  void _initializeImageFetching() {
    final connectionState = ref.read(connectionStateProvider);
    if (connectionState.serverAddress != null) {
      serverUrl = 'http://${connectionState.serverAddress}';
      _updateCarouselTimer();
      _fetchNextImage();
    }
  }

  Future<void> _fetchNextImage() async {
    if (serverUrl == null) return;

    try {
      final response = await http.get(Uri.parse('$serverUrl/images/next'));
      
      if (response.statusCode == 200) {
        setState(() {
          imageData = response.bodyBytes;
        });
      } else {
        print('Error fetching image: ${response.statusCode}');
      }
    } catch (e) {
      print('Network error: $e');
    }
  }

  void _updateCarouselTimer() {
    carouselTimer?.cancel();
    final delaySeconds = ref.read(connectionStateProvider).delaySeconds;
    if (currentDelay != delaySeconds) {
      print('Updating carousel timer to $delaySeconds seconds');
    }
    currentDelay = delaySeconds;
    carouselTimer = Timer.periodic(Duration(seconds: delaySeconds), (timer) {
      _fetchNextImage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    
    // React to delay changes
    if (currentDelay != connectionState.delaySeconds) {
      Future.microtask(() => _updateCarouselTimer());
    }
    
    // React to server URL changes
    if (connectionState.serverAddress != null && 
        'http://${connectionState.serverAddress}' != serverUrl) {
      Future.microtask(() {
        serverUrl = 'http://${connectionState.serverAddress}';
        _fetchNextImage();
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
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
    if (imageData == null) {
      return Container(
        key: const ValueKey("placeholder"),
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        alignment: Alignment.center,
        child: const Text(
          'Awaiting Image...',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      );
    }

    return Image.memory(
      imageData!,
      key: ValueKey(imageData.hashCode), // Unique key for each image
      fit: BoxFit.contain,
    );
  }

  @override
  void dispose() {
    carouselTimer?.cancel();
    super.dispose();
  }
}
