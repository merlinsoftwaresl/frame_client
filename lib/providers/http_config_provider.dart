import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'connection_provider.dart';

part 'http_config_provider.g.dart';

@Riverpod(keepAlive: true)
class ConfigServer extends _$ConfigServer {
  HttpServer? _server;

  @override
  Future<void> build() async {
    ref.onDispose(() async {
      await _server?.close();
      _server = null;
    });

    await _startServer();
  }

  Future<void> _startServer() async {
    if (_server != null) return;

    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_handleRequest);

    try {
      _server = await io.serve(handler, InternetAddress.anyIPv4, 8888);
      print('HTTP server running on port 8888');
    } catch (e) {
      print('Error starting HTTP server: $e');
    }
  }

  Future<Response> _handleRequest(Request request) async {
    print('Received request: ${request.method} ${request.url.path}');

    if (request.method == 'POST') {
      try {
        final body = await request.readAsString();
        
        switch (request.url.path) {
          case 'configure_address':
            if (body.isNotEmpty) {
              final socketDirection = body.trim();
              print('Setting socket direction to: $socketDirection');
              ref.read(connectionStateProvider.notifier).updateServerAddress(socketDirection);
              return Response.ok('Configuration received: $socketDirection');
            }
            return Response.badRequest(body: 'Empty configuration');
            
          case 'configure_delay':
            if (body.isNotEmpty) {
              final delay = int.tryParse(body.trim());
              if (delay != null && delay > 0) {
                print('Setting delay to: $delay seconds');
                ref.read(connectionStateProvider.notifier).updateDelay(delay);
                return Response.ok('Delay configured: $delay seconds');
              }
              return Response.badRequest(body: 'Invalid delay value');
            }
            return Response.badRequest(body: 'Empty delay configuration');
        }
      } catch (e) {
        print('Error handling configuration request: $e');
        return Response.internalServerError(body: 'Error processing request');
      }
    }

    return Response.notFound('Not found');
  }
} 
