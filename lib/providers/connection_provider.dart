import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'connection_provider.g.dart';

class ConnectionStateModel {
  final String ipAddress;
  final int port;
  final String? serverAddress;
  final int delaySeconds;
  final String frameId;

  const ConnectionStateModel({
    this.ipAddress = '',
    this.port = 8888,
    this.serverAddress,
    this.delaySeconds = 5,
    this.frameId = 'Unknown',
  });

  ConnectionStateModel copyWith({
    String? ipAddress,
    int? port,
    String? serverAddress,
    int? delaySeconds,
    String? frameId,
  }) {
    return ConnectionStateModel(
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      serverAddress: serverAddress ?? this.serverAddress,
      delaySeconds: delaySeconds ?? this.delaySeconds,
      frameId: frameId ?? this.frameId,
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

  void updateServerAddress(String address) {
    state = state.copyWith(serverAddress: address);
  }

  void updateDelay(int seconds) {
    state = state.copyWith(delaySeconds: seconds);
  }

  void updateFrameId(String frameId) {
    state = state.copyWith(frameId: frameId);
  }
} 
