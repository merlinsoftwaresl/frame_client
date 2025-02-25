import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';

class DiscoveryService {
  static const String _serviceType = '_frame-client._tcp';
  static const String _serviceName = 'Frame Client';
  
  BonsoirBroadcast? _broadcast;
  bool _isBroadcasting = false;

  final Ref _ref;

  DiscoveryService(this._ref);

  Future<void> startBroadcast(String ipAddress, int port) async {
    if (_isBroadcasting) return;

    try {
      final service = BonsoirService(
        name: _serviceName,
        type: _serviceType,
        port: port,
        attributes: {
          'device_type': 'frame_client',
          'address': ipAddress,
        },
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.ready;
      
      await _broadcast!.start();
      _isBroadcasting = true;
      
      print('mDNS service broadcasting started on $ipAddress:$port');
    } catch (e) {
      print('Failed to start mDNS broadcast: $e');
    }
  }

  Future<void> stopBroadcast() async {
    if (!_isBroadcasting || _broadcast == null) return;
    
    try {
      await _broadcast!.stop();
      _isBroadcasting = false;
      print('mDNS service broadcasting stopped');
    } catch (e) {
      print('Error stopping mDNS broadcast: $e');
    }
  }

  bool get isBroadcasting => _isBroadcasting;
}

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final service = DiscoveryService(ref);
  
  ref.onDispose(() async {
    await service.stopBroadcast();
  });
  
  return service;
}); 