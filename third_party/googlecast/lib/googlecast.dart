import 'dart:async';
import 'package:flutter/services.dart';


class GoogleChromeCast {

  static const MethodChannel _channel = MethodChannel('googlecast');
    static Future<String?> get platformVersion async {
      final version = await _channel.invokeMethod<String>('getPlatformVersion');
      return version;
    }

  final EventChannel _connection_state_channel= const EventChannel("com.salamay.googlecast/connectionstate");
  final EventChannel _messageEvent= const EventChannel("com.salamay.googlecast/messagestream");

  late Stream<bool> _connectionstream;
  late Stream<String?> _messageStream;

  Stream<bool> get connectionState{
    _connectionstream=_connection_state_channel.receiveBroadcastStream().map<bool>((event){
      return event;
    });
    return _connectionstream;
  }

  Stream<String?> get messageStream{
    _messageStream=_messageEvent.receiveBroadcastStream().map<String?>((event) => event);
    return _messageStream;
  }

  static Future<void>castAudio(var metadata) async {
    try{
      await _channel.invokeMethod('loadAudio',metadata);
    }catch(e){
      throw Exception(e);
    }
  }

  static Future<void>playAudio() async {
    try{
      await _channel.invokeMethod('playAudio');
    }catch(e){
      throw Exception(e);
    }
  }

  static Future<void>pauseAudio() async {
    try{
      await _channel.invokeMethod('pauseAudio');
    }catch(e){
      throw Exception(e);
    }
  }

  static Future<void>stopAudio() async {
    try{
      await _channel.invokeMethod('stopAudio');
    }catch(e){
      throw Exception(e);
    }
  }

  static Future<bool> isConnected() async {
    try {
      final connected = await _channel.invokeMethod<bool>('isConnected');
      return connected ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> debugState() async {
    try {
      final state = await _channel.invokeMapMethod<String, dynamic>('debugState');
      return state ?? <String, dynamic>{};
    } catch (e) {
      return <String, dynamic>{'error': e.toString()};
    }
  }

  static Future<bool> showCastDialog() async {
    try {
      final shown = await _channel.invokeMethod<bool>('showCastDialog');
      return shown ?? false;
    } catch (e) {
      // Keep a clear signal in logs when native chooser cannot be shown.
      // ignore: avoid_print
      print('showCastDialog failed: $e');
      return false;
    }
  }

  static Future<void> startDiscovery() async {
    try {
      // Older native plugin builds may not expose startDiscovery directly.
      // Fall back to showing the Cast chooser, which also performs discovery.
      final started = await _channel.invokeMethod<bool>('startDiscovery');
      if (started == true) return;
    } catch (_) {
      // Ignore and try chooser fallback below.
    }

    try {
      await _channel.invokeMethod<bool>('showCastDialog');
    } catch (_) {
      // Best effort only; callers should still poll isConnected().
    }
  }
}

class Googlecast {
  static Future<String?> get platformVersion => GoogleChromeCast.platformVersion;
}
