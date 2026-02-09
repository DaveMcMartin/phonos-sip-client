import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/sip_configuration.dart';
import '../models/call_history_entry.dart';
import '../repositories/call_history_repository.dart';
import '../repositories/configuration_repository.dart';

import 'dart:io';

class SipService extends ChangeNotifier implements SipUaHelperListener {
  final SIPUAHelper _helper = SIPUAHelper();
  final ConfigurationRepository _configRepository = ConfigurationRepository();
  final CallHistoryRepository _historyRepository = CallHistoryRepository();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  SipConfiguration? _configuration;
  RegistrationState _registrationState = RegistrationState(
    state: RegistrationStateEnum.NONE,
  );
  TransportState _transportState = TransportState(TransportStateEnum.NONE);
  Call? _currentCall;
  String _dialedNumber = '';
  String? _lastCallError;
  DateTime? _callStartTime;
  Timer? _callDurationTimer;
  int _callDuration = 0;
  List<CallHistoryEntry> _callHistory = [];
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  SipConfiguration? get configuration => _configuration;
  RegistrationState get registrationState => _registrationState;
  TransportState get transportState => _transportState;
  Call? get currentCall => _currentCall;
  String get dialedNumber => _dialedNumber;
  String? get lastCallError => _lastCallError;
  int get callDuration => _callDuration;
  List<CallHistoryEntry> get callHistory => _callHistory;
  SIPUAHelper get helper => _helper;

  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  bool get isRegistered =>
      _registrationState.state == RegistrationStateEnum.REGISTERED;

  String get connectionStatus {
    if (_transportState.state == TransportStateEnum.CONNECTED) {
      if (_registrationState.state == RegistrationStateEnum.REGISTERED) {
        return 'REGISTERED';
      } else if (_registrationState.state ==
          RegistrationStateEnum.REGISTRATION_FAILED) {
        return 'DISCONNECTED';
      } else {
        return 'REGISTERING';
      }
    } else if (_transportState.state == TransportStateEnum.CONNECTING) {
      return 'REGISTERING';
    }

    return 'DISCONNECTED';
  }

  bool get isInCall => _currentCall != null;

  bool get isMuted => _currentCall?.state == CallStateEnum.MUTED;

  bool get isOnHold => _currentCall?.state == CallStateEnum.HOLD;

  bool get isCameraEnabled =>
      _localStream?.getVideoTracks().any((track) => track.enabled) ?? false;

  bool get hasRemoteVideo =>
      _remoteStream?.getVideoTracks().any((track) => track.enabled) ?? false;

  SipService() {
    _helper.addSipUaHelperListener(this);
    _initialize();
  }

  Future<bool> _checkPermissions({bool requestCamera = false}) async {
    debugPrint('Checking permissions. RequestCamera: $requestCamera');
    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        var microphoneStatus = await Permission.microphone.status;
        debugPrint('Microphone status: $microphoneStatus');
        if (microphoneStatus.isDenied) {
          debugPrint('Requesting microphone permission...');
          microphoneStatus = await Permission.microphone.request();
          debugPrint('Microphone permission result: $microphoneStatus');
        }

        if (microphoneStatus.isPermanentlyDenied) {
          debugPrint('Microphone permission permanently denied');
          return false;
        }

        if (!microphoneStatus.isGranted) return false;

        if (requestCamera) {
          var cameraStatus = await Permission.camera.status;
          debugPrint('Camera status: $cameraStatus');
          if (cameraStatus.isDenied) {
            debugPrint('Requesting camera permission...');
            cameraStatus = await Permission.camera.request();
            debugPrint('Camera permission result: $cameraStatus');
          }

          if (cameraStatus.isPermanentlyDenied) {
            debugPrint('Camera permission permanently denied');
            return false;
          }

          if (!cameraStatus.isGranted) return false;
        }

        return true;
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return true;
    }
    return true;
  }

  Future<void> _initialize() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _remoteRenderer.initialize();

    _configuration = await _configRepository.getConfiguration();
    _callHistory = await _historyRepository.getHistory();
    notifyListeners();

    if (_configuration != null &&
        _configuration!.username.isNotEmpty &&
        _configuration!.hostname.isNotEmpty) {
      connect().catchError((e) {
        debugPrint('Auto-connect failed: $e');
      });
    }
  }

  Future<void> saveConfiguration(SipConfiguration config) async {
    await _configRepository.saveConfiguration(config);
    _configuration = config;
    notifyListeners();
  }

  Future<void> connect() async {
    if (_configuration == null) {
      throw Exception('Configuration not set');
    }

    final settings = UaSettings();
    settings.webSocketUrl = _configuration!.protocol == TransportType.WS
        ? _configuration!.webSocketUrl
        : null;
    settings.webSocketSettings.allowBadCertificate = true;

    settings.host = _configuration!.hostname;
    settings.port = _configuration!.port.toString();
    settings.transportType = _configuration!.protocol;
    settings.uri =
        'sip:${_configuration!.username}@${_configuration!.hostname}';

    settings.authorizationUser =
        _configuration!.authorizationUser ?? _configuration!.username;
    settings.password = _configuration!.password;
    settings.displayName =
        _configuration!.displayName ?? _configuration!.username;
    settings.userAgent = _configuration!.userAgent ?? 'Phonos SIP Client';
    settings.dtmfMode = _configuration!.dtmfMode ?? DtmfMode.RFC2833;
    settings.register = true;

    if (_configuration!.protocol == TransportType.WS &&
        _configuration!.wsUrl == null) {}

    settings.iceServers = _configuration!.iceServers
        .map(
          (ice) => <String, String>{
            'urls': ice.urls,
            if (ice.username != null) 'username': ice.username!,
            if (ice.credential != null) 'credential': ice.credential!,
          },
        )
        .toList();

    _helper.start(settings);
  }

  Future<void> disconnect() async {
    if (_currentCall != null) {
      await hangup();
    }
    _helper.stop();
  }

  void updateDialedNumber(String number) {
    _dialedNumber = number;
    notifyListeners();
  }

  void appendToDialedNumber(String digit) {
    _dialedNumber += digit;
    notifyListeners();
  }

  void backspaceDialedNumber() {
    if (_dialedNumber.isNotEmpty) {
      _dialedNumber = _dialedNumber.substring(0, _dialedNumber.length - 1);
      notifyListeners();
    }
  }

  void clearDialedNumber() {
    _dialedNumber = '';
    notifyListeners();
  }

  Future<void> call(String destination, {bool video = false}) async {
    if (!await _checkPermissions(requestCamera: video)) {
      _lastCallError =
          'Permissions denied. Please enable microphone${video ? ' and camera' : ''}.';
      notifyListeners();
      return;
    }

    if (!isRegistered) {
      throw Exception('Not registered');
    }

    _helper.call(destination, voiceOnly: !video);
    _dialedNumber = destination;
    _lastCallError = null;
    notifyListeners();
  }

  Future<void> answer({bool video = false}) async {
    if (!await _checkPermissions(requestCamera: video)) {
      _lastCallError =
          'Permissions denied. Please enable microphone${video ? ' and camera' : ''}.';
      notifyListeners();
      return;
    }

    if (_currentCall == null) return;

    final options = _helper.buildCallOptions(!video);
    _currentCall!.answer(options);
  }

  Future<void> hangup() async {
    if (_currentCall == null) return;
    _currentCall!.hangup();
  }

  Future<void> reject() async {
    if (_currentCall == null) return;
    _currentCall!.hangup();
  }

  Future<void> sendDtmf(String digit) async {
    if (_currentCall == null) return;
    _currentCall!.sendDTMF(digit);
  }

  Future<void> toggleMute() async {
    if (_currentCall == null) return;

    if (_currentCall!.state == CallStateEnum.MUTED) {
      _currentCall!.unmute(true, false);
    } else {
      _currentCall!.mute(true, false);
    }
    notifyListeners();
  }

  Future<void> toggleVideo() async {
    if (!await _checkPermissions(requestCamera: true)) {
      _lastCallError = 'Permissions denied. Please enable camera.';
      notifyListeners();
      return;
    }

    if (_currentCall == null) return;

    try {
      final hasVideo =
          _localStream?.getVideoTracks().any((track) => track.enabled) ?? false;

      if (hasVideo) {
        _currentCall!.mute(false, true);
      } else {
        _currentCall!.unmute(true, true);
      }
    } catch (e) {
      debugPrint('Error toggling video: $e');
      _lastCallError = 'Failed to toggle video: $e';
    }
    notifyListeners();
  }

  Future<void> toggleHold() async {
    if (_currentCall == null) return;

    if (_currentCall!.state == CallStateEnum.HOLD) {
      _currentCall!.unhold();
    } else {
      _currentCall!.hold();
    }
    notifyListeners();
  }

  Future<void> loadCallHistory() async {
    _callHistory = await _historyRepository.getHistory();
    notifyListeners();
  }

  Future<void> deleteCallHistoryEntry(String id) async {
    await _historyRepository.deleteEntry(id);
    await loadCallHistory();
  }

  Future<void> clearCallHistory() async {
    await _historyRepository.clearHistory();
    await loadCallHistory();
  }

  void _startCallDurationTimer() {
    _callStartTime = DateTime.now();
    _callDuration = 0;
    _callDurationTimer?.cancel();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_callStartTime != null) {
        _callDuration = DateTime.now().difference(_callStartTime!).inSeconds;
        notifyListeners();
      }
    });
  }

  void _stopCallDurationTimer() {
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
  }

  Future<void> _addCallToHistory({
    required String remoteNumber,
    String? remoteName,
    required CallDirection direction,
    required CallStatus status,
    int? duration,
  }) async {
    final entry = CallHistoryEntry(
      id: const Uuid().v4(),
      remoteNumber: remoteNumber,
      remoteName: remoteName,
      direction: direction,
      status: status,
      timestamp: DateTime.now(),
      duration: duration,
    );

    await _historyRepository.addEntry(entry);
    await loadCallHistory();
  }

  @override
  void callStateChanged(Call call, CallState state) {
    debugPrint('Call state changed: ${state.state}');
    _currentCall = call;

    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        if (call.direction == Direction.incoming) {
          _audioPlayer.setReleaseMode(ReleaseMode.loop);
          _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
        }
        break;
      case CallStateEnum.CONNECTING:
        break;
      case CallStateEnum.PROGRESS:
        break;
      case CallStateEnum.STREAM:
        _handleStreams(state);
        break;
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        _audioPlayer.stop();
        _startCallDurationTimer();
        break;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _audioPlayer.stop();
        _cleanUpCall();
        _lastCallError = state.cause?.cause;
        final duration = _callDuration > 0 ? _callDuration : null;
        final direction = call.direction == Direction.incoming
            ? CallDirection.incoming
            : CallDirection.outgoing;

        CallStatus status;
        if (state.state == CallStateEnum.FAILED) {
          status = CallStatus.rejected;
        } else if (duration != null && duration > 0) {
          status = CallStatus.answered;
        } else {
          status = CallStatus.missed;
        }

        _addCallToHistory(
          remoteNumber: call.remote_identity ?? 'Unknown',
          direction: direction,
          status: status,
          duration: duration,
        );

        _stopCallDurationTimer();
        _currentCall = null;
        _callDuration = 0;
        _callStartTime = null;
        break;
      case CallStateEnum.HOLD:
      case CallStateEnum.UNHOLD:
      case CallStateEnum.MUTED:
      case CallStateEnum.UNMUTED:
      case CallStateEnum.REFER:
        break;
      default:
        break;
    }

    notifyListeners();
  }

  void _handleStreams(CallState state) {
    if (state.stream != null) {
      if (state.originator == Originator.local) {
        _localRenderer.srcObject = state.stream;
        _localStream = state.stream;
      } else {
        _remoteRenderer.srcObject = state.stream;
        _remoteStream = state.stream;
      }
    }
    notifyListeners();
  }

  void _cleanUpCall() {
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    _localStream = null;
    _remoteStream = null;
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    _registrationState = state;
    notifyListeners();
  }

  @override
  void transportStateChanged(TransportState state) {
    _transportState = state;
    notifyListeners();
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {
    debugPrint('Received ReInvite');
    if (event.accept != null) {
      event.accept!(<String, dynamic>{});
    }
  }

  @override
  void dispose() {
    _helper.removeSipUaHelperListener(this);
    _stopCallDurationTimer();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    disconnect();
    super.dispose();
  }
}
