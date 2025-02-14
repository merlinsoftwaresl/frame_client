import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'connection_provider.dart';

part 'http_server_provider.g.dart';

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

    if (request.method == 'POST' && request.url.path == 'configure') {
      try {
        final body = await request.readAsString();
        print('Received configuration: $body');
        
        // Validate and format the socket direction
        if (body.isNotEmpty) {
          final socketDirection = body.trim();
          print('Setting socket direction to: $socketDirection');
          
          // Update the socket direction using the connection provider
          ref.read(connectionStateProvider.notifier).updateSocketDirection(socketDirection);
          
          return Response.ok('Configuration received: $socketDirection');
        } else {
          print('Empty configuration received');
          return Response.badRequest(body: 'Empty configuration');
        }
      } catch (e) {
        print('Error handling configuration request: $e');
        return Response.internalServerError(body: 'Error processing request');
      }
    }

    return Response.notFound('Not found');
  }
} 