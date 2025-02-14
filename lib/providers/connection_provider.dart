import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

part 'connection_provider.g.dart';

class ConnectionStateModel {
  final String ipAddress;
  final HttpServer? server;
  final int port;
  final String? socketDirection;

  ConnectionStateModel({
    required this.ipAddress,
    this.server,
    this.port = 8888,
    this.socketDirection,
  });

  ConnectionStateModel copyWith({
    String? ipAddress,
    HttpServer? server,
    int? port,
    String? socketDirection,
  }) {
    return ConnectionStateModel(
      ipAddress: ipAddress ?? this.ipAddress,
      server: server ?? this.server,
      port: port ?? this.port,
      socketDirection: socketDirection ?? this.socketDirection,
    );
  }
}

@Riverpod(keepAlive: true)
class ConnectionState extends _$ConnectionState {
  @override
  ConnectionStateModel build() {
    return ConnectionStateModel(ipAddress: 'Loading...');
  }

  void updateIpAddress(String ip) {
    state = state.copyWith(ipAddress: ip);
  }

  void setServer(HttpServer server) {
    state = state.copyWith(server: server);
  }

  Future<void> closeServer() async {
    await state.server?.close();
    state = state.copyWith(server: null);
  }

  void updateSocketDirection(String direction) {
    state = state.copyWith(socketDirection: direction);
  }
} 