import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

part 'connection_provider.g.dart';

class ConnectionStateModel {
  final String ipAddress;
  final int port;
  final String? socketDirection;
  final int delaySeconds;

  const ConnectionStateModel({
    this.ipAddress = '',
    this.port = 8888,
    this.socketDirection,
    this.delaySeconds = 5,
  });

  ConnectionStateModel copyWith({
    String? ipAddress,
    int? port,
    String? socketDirection,
    int? delaySeconds,
  }) {
    return ConnectionStateModel(
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      socketDirection: socketDirection ?? this.socketDirection,
      delaySeconds: delaySeconds ?? this.delaySeconds,
    );
  }
}

@Riverpod(keepAlive: true)
class ConnectionState extends _$ConnectionState {
  @override
  ConnectionStateModel build() {
    return const ConnectionStateModel();
  }

  void updateIpAddress(String ip) {
    state = state.copyWith(ipAddress: ip);
  }

  void updateSocketDirection(String direction) {
    state = state.copyWith(socketDirection: direction);
  }

  void updateDelay(int seconds) {
    state = state.copyWith(delaySeconds: seconds);
  }
} 