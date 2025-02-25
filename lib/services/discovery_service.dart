import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/connection_provider.dart';

class DiscoveryService {
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  final int _discoveryPort = 8888;
  final WidgetRef _ref;
  
  DiscoveryService(this._ref);
  
  Future<void> startDiscoveryService() async {
    await _ensureFrameId();
    await _startUdpListener();
    _startBroadcasting();
  }
  
  void stopDiscoveryService() {
    _broadcastTimer?.cancel();
    _socket?.close();
  }
  
  // Generate a simple, readable frame ID
  String generateNewId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789abcdefghjklmnpqrstuvwxyz'; // Removed similar characters
    final random = Random();
    // Generate a 6-character ID
    final newId = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
    
    // Save the new ID
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('frame_id', newId);
    });
    
    return newId;
  }
  
  // Ensure we have a unique frame ID
  Future<void> _ensureFrameId() async {
    final prefs = await SharedPreferences.getInstance();
    String? frameId = prefs.getString('frame_id');
    
    if (frameId == null) {
      frameId = generateNewId();
    }
    
    _ref.read(connectionStateProvider.notifier).updateFrameId(frameId);
  }
  
  Future<void> _startUdpListener() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort);
      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            final message = utf8.decode(datagram.data);
            _handleDiscoveryMessage(message, datagram.address, datagram.port);
          }
        }
      });
      print('UDP discovery service started on port $_discoveryPort');
    } catch (e) {
      print('Error starting UDP discovery service: $e');
    }
  }
  
  void _handleDiscoveryMessage(String message, InternetAddress address, int port) {
    if (message == 'DISCOVER_FRAME_CLIENT') {
      final connectionState = _ref.read(connectionStateProvider);
      final response = {
        'type': 'FRAME_INFO',
        'frameId': connectionState.frameId,
        'ipAddress': connectionState.ipAddress,
        'port': connectionState.port,
      };
      
      final responseData = utf8.encode(jsonEncode(response));
      _socket?.send(responseData, address, port);
      print('Responded to discovery request from ${address.address}:$port');
    }
  }
  
  void _startBroadcasting() {
    _broadcastTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _broadcastPresence();
    });
    
    _broadcastPresence();
  }
  
  void _broadcastPresence() {
    try {
      final connectionState = _ref.read(connectionStateProvider);
      final message = {
        'type': 'FRAME_ANNOUNCEMENT',
        'frameId': connectionState.frameId,
        'ipAddress': connectionState.ipAddress,
        'port': connectionState.port,
      };
      
      final data = utf8.encode(jsonEncode(message));
      _socket?.send(data, InternetAddress('255.255.255.255'), _discoveryPort);
      print('Broadcast frame presence');
    } catch (e) {
      print('Error broadcasting frame presence: $e');
    }
  }
} 