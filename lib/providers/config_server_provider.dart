import 'dart:convert';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'connection_provider.dart';

part 'config_server_provider.g.dart';

@Riverpod(keepAlive: true)
class ConfigServer extends _$ConfigServer {
  HttpServer? _server;

  @override
  Future<void> build() async {
    await _startServer();
    return;
  }

  Future<void> _startServer() async {
    if (_server != null) return;

    var handler = Pipeline().addHandler(_handleRequest);

    try {
      _server = await io.serve(handler, '0.0.0.0', 8888);
      print('Server running on port ${_server!.port}');
    } catch (e) {
      print('Failed to start server: $e');
    }
  }

  Future<Response> _handleRequest(Request request) async {
    if (request.method == 'POST' && request.url.path == 'config') {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        
        // Update server address
        if (data['server_address'] != null) {
          final serverAddress = data['server_address'] as String;
          ref.read(connectionStateProvider.notifier).updateServerAddress(serverAddress);
        }

        // Update delay
        if (data['delay'] != null) {
          final delay = data['delay'] as int;
          ref.read(connectionStateProvider.notifier).updateDelay(delay);
        }

        return Response.ok('Configuration updated');
      } catch (e) {
        return Response(400, body: 'Invalid request format');
      }
    }

    return Response(404, body: 'Not found');
  }
} 
