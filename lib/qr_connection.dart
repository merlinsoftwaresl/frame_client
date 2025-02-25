import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'image_display.dart';
import 'providers/connection_provider.dart';
import 'providers/http_config_provider.dart';
import 'services/discovery_service.dart';

class QrConnection extends ConsumerStatefulWidget {
  const QrConnection({super.key});

  @override
  ConsumerState<QrConnection> createState() => _QrConnectionState();
}

class _QrConnectionState extends ConsumerState<QrConnection> {
  late DiscoveryService _discoveryService;

  @override
  void initState() {
    super.initState();
    _getLocalIpAddress();
    // Initialize the server
    ref.read(configServerProvider);
    
    // Initialize and start discovery service with ref
    _discoveryService = DiscoveryService(ref);
    _discoveryService.startDiscoveryService();
  }

  @override
  void dispose() {
    _discoveryService.stopDiscoveryService();
    super.dispose();
  }

  Future<void> _getLocalIpAddress() async {
    final networkInfo = NetworkInfo();
    try {
      String? ip = await networkInfo.getWifiIP();
      ref.read(connectionStateProvider.notifier).updateIpAddress(ip ?? 'Unable to fetch IP');
    } catch (e) {
      print('Error fetching local IP: $e');
      ref.read(connectionStateProvider.notifier).updateIpAddress('Error fetching IP');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch both providers
    final connectionState = ref.watch(connectionStateProvider);
    final connectionString = '${connectionState.ipAddress}:${connectionState.port}/${connectionState.frameId}';

    // Listen to socket direction changes to navigate
    ref.listen(connectionStateProvider.select((state) => state.serverAddress),
        (previous, next) {
      if (next != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ImageDisplay(),
          ),
        );
      }
    });
    
    // Get screen size for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    // Adjust QR size based on orientation
    final qrSize = isLandscape 
        ? screenSize.height * 0.4  // 40% of height in landscape
        : screenSize.width * 0.6;  // 60% of width in portrait
    
    // Calculate responsive text sizes - smaller in landscape
    final multiplier = isLandscape ? 0.8 : 1.0;
    final headingSize = screenSize.width * 0.045 * multiplier;
    final bodySize = screenSize.width * 0.04 * multiplier;
    final smallSize = screenSize.width * 0.035 * multiplier;
    
    // Create the content widgets
    final qrSection = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Scan QR code to connect',
          style: TextStyle(fontSize: headingSize, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        QrImageView(
          data: connectionString,
          version: QrVersions.auto,
          size: qrSize,
        ),
      ],
    );
    
    final infoSection = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Or discover via network',
          style: TextStyle(fontSize: headingSize, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Frame ID: ${connectionState.frameId}',
          style: TextStyle(fontSize: bodySize),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'IP Address: ${connectionState.ipAddress}',
          style: TextStyle(fontSize: bodySize),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Port: ${connectionState.port}',
          style: TextStyle(fontSize: bodySize),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Text(
          'Discovery service is running',
          style: TextStyle(fontSize: smallSize, color: Colors.green),
          textAlign: TextAlign.center,
        ),
      ],
    );
    
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: isLandscape
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: qrSection),
                      const SizedBox(width: 40),
                      Expanded(child: infoSection),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      qrSection,
                      const SizedBox(height: 40),
                      infoSection,
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
