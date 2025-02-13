import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'image_display.dart';

class QrConnection extends StatefulWidget {
  const QrConnection({super.key});

  @override
  _QrConnectionState createState() => _QrConnectionState();
}

class _QrConnectionState extends State<QrConnection> {
  String _localIp = 'Loading...';
  HttpServer? _server;

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
      setState(() {
        _localIp = ip ?? 'Unable to fetch IP';
      });
    } catch (e) {
      print('Error fetching local IP: $e');
      setState(() {
        _localIp = 'Error fetching IP';
      });
    }
  }

  Future<void> _startHttpServer() async {
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_handleRequest);

    try {
      _server = await io.serve(handler, InternetAddress.anyIPv4, 8888);
      print('HTTP server running on http://$_localIp:8888');
    } catch (e) {
      print('Error starting HTTP server: $e');
    }
  }

  Future<Response> _handleRequest(Request request) async {
    print('Received request: ${request.method} ${request.url.path}');

    final body = await request.readAsString();
    print('Received configuration: $body');

    // Navigate to ImageDisplay with the received socket direction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageDisplay(socketDirection: body),
        ),
      );
    });

    return Response.ok('Configuration received');
  }

  @override
  void dispose() {
    //_server?.close(); // Close the server when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: QrImageView(
          data: 'http://$_localIp:8888',
          version: QrVersions.auto,
          size: 200.0,
        ),
      ),
    );
  }
}
