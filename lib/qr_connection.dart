import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'image_display.dart';
import 'providers/connection_provider.dart';

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
    _startHttpServer();
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

  Future<void> _startHttpServer() async {
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_handleRequest);

    try {
      final server = await io.serve(handler, InternetAddress.anyIPv4, 8888);
      ref.read(connectionStateProvider.notifier).setServer(server);
      final ip = ref.read(connectionStateProvider).ipAddress;
      print('HTTP server running on http://$ip:8888');
    } catch (e) {
      print('Error starting HTTP server: $e');
    }
  }

  Future<Response> _handleRequest(Request request) async {
    print('Received request: ${request.method} ${request.url.path}');

    final body = await request.readAsString();
    print('Received configuration: $body');

    // Navigate to ImageDisplay with the received socket direction
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ImageDisplay(socketDirection: body),
        ),
      );
    }

    return Response.ok('Configuration received');
  }

  @override
  void dispose() {
    // Don't close the server on dispose since we need it in ImageDisplay
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final connectionString = '${connectionState.ipAddress}:${connectionState.port}';
    
    return Scaffold(
      body: Center(
        child: QrImageView(
          data: connectionString,
          version: QrVersions.auto,
          size: 200.0,
        ),
      ),
    );
  }
}
