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
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Scan QR code to connect',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            QrImageView(
              data: connectionString,
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 40),
            const Text(
              'Or discover via network',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Frame ID: ${connectionState.frameId}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'IP Address: ${connectionState.ipAddress}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Port: ${connectionState.port}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text(
              'Discovery service is running',
              style: TextStyle(fontSize: 14, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
