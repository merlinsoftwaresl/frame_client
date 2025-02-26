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
  @override
  void initState() {
    super.initState();
    _getLocalIpAddress();
    // Initialize the server
    ref.read(configServerProvider);
  }

  Future<void> _getLocalIpAddress() async {
    final networkInfo = NetworkInfo();
    try {
      String? ip = await networkInfo.getWifiIP();
      ref
          .read(connectionStateProvider.notifier)
          .updateIpAddress(ip ?? 'Unable to fetch IP');

      // Wait for the server to be initialized
      await ref.read(configServerProvider.future);

      // Add a delay to ensure everything is properly initialized
      await Future.delayed(const Duration(seconds: 1));

      if (ip != null) {
        final port = ref.read(connectionStateProvider).port;
        print('QR Connection - IP: $ip, Port: $port');

        if (port > 0) {
          await ref
              .read(discoveryServiceProvider)
              .stopBroadcast(); // Stop any existing broadcast
          await ref.read(discoveryServiceProvider).startBroadcast(ip, port);
        }
      }
    } catch (e) {
      print('Error fetching local IP: $e');
      ref
          .read(connectionStateProvider.notifier)
          .updateIpAddress('Error fetching IP');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch both providers
    final connectionState = ref.watch(connectionStateProvider);
    final connectionString =
        '${connectionState.ipAddress}:${connectionState.port}';

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
    final qrSize =
        isLandscape ? screenSize.height * 0.4 : screenSize.width * 0.4;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(
              data: connectionString,
              version: QrVersions.auto,
              size: qrSize,
            ),
            const SizedBox(height: 20),
            Text(
              'Scan QR code or find device on network',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              connectionString,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
