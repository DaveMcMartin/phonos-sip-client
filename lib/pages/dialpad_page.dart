import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/sip_service.dart';

class DialpadPage extends StatefulWidget {
  const DialpadPage({super.key});

  @override
  State<DialpadPage> createState() => _DialpadPageState();
}

class _DialpadPageState extends State<DialpadPage> {
  late SipService _sipService;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _sipService = context.read<SipService>();
    _sipService.addListener(_onSipServiceChanged);
  }

  @override
  void dispose() {
    _sipService.removeListener(_onSipServiceChanged);
    super.dispose();
  }

  void _onSipServiceChanged() {
    if (!mounted) return;
    final error = _sipService.lastCallError;

    if (error != null && error != _lastError) {
      _lastError = error;
      final messenger = ScaffoldMessenger.of(context);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Call Failed: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () {
              messenger.hideCurrentSnackBar();
            },
            textColor: Colors.white,
          ),
        ),
      );
    } else if (error == null) {
      _lastError = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sipService = context.watch<SipService>();

    if (sipService.isInCall) {
      return const CallScreen();
    }

    return const DialpadScreen();
  }
}

class DialpadScreen extends StatelessWidget {
  const DialpadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sipService = context.watch<SipService>();
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusIndicator(context, sipService),
                const SizedBox(height: 32),
                _buildNumberDisplay(context, sipService),
                const SizedBox(height: 24),
                _buildDialpad(context, sipService),
                const SizedBox(height: 24),
                _buildCallButton(context, sipService),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, SipService sipService) {
    final theme = Theme.of(context);
    final isRegistered = sipService.isRegistered;
    final statusText = sipService.registrationState.state?.name ?? 'NONE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isRegistered
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 12,
            color: isRegistered ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isRegistered ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberDisplay(BuildContext context, SipService sipService) {
    final theme = Theme.of(context);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sipService.dialedNumber.isEmpty ? '' : sipService.dialedNumber,
              style: theme.textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
          ),
          if (sipService.dialedNumber.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.backspace_outlined),
              onPressed: sipService.backspaceDialedNumber,
            ),
        ],
      ),
    );
  }

  Widget _buildDialpad(BuildContext context, SipService sipService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildDialpadRow(['1', '2', '3'], sipService),
          const SizedBox(height: 12),
          _buildDialpadRow(['4', '5', '6'], sipService),
          const SizedBox(height: 12),
          _buildDialpadRow(['7', '8', '9'], sipService),
          const SizedBox(height: 12),
          _buildDialpadRow(['*', '0', '#'], sipService),
        ],
      ),
    );
  }

  Widget _buildDialpadRow(List<String> digits, SipService sipService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((digit) => _buildDialpadButton(digit, sipService))
          .toList(),
    );
  }

  Widget _buildDialpadButton(String digit, SipService sipService) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => sipService.appendToDialedNumber(digit),
          customBorder: const CircleBorder(),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton(BuildContext context, SipService sipService) {
    final canCall =
        sipService.isRegistered && sipService.dialedNumber.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            heroTag: 'voice_call',
            onPressed: canCall
                ? () {
                    sipService.call(sipService.dialedNumber, video: false);
                  }
                : null,
            backgroundColor: canCall ? Colors.green : Colors.grey,
            child: const Icon(Icons.call, size: 32),
          ),
        ),
        if (canCall) ...[
          const SizedBox(width: 24),
          SizedBox(
            width: 72,
            height: 72,
            child: FloatingActionButton(
              heroTag: 'video_call',
              onPressed: () {
                sipService.call(sipService.dialedNumber, video: true);
              },
              backgroundColor: Colors.blue,
              child: const Icon(Icons.videocam, size: 32),
            ),
          ),
        ],
      ],
    );
  }
}

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sipService = context.watch<SipService>();
    final theme = Theme.of(context);
    final call = sipService.currentCall;

    if (call == null) return const SizedBox();

    final isIncoming = call.direction == Direction.incoming;
    final callState = call.state;
    final remoteNumber = call.remote_identity ?? 'Unknown';
    final remoteName = call.remote_display_name;
    final hasVideo = !call.voiceOnly;

    return Scaffold(
      body: Stack(
        children: [
          if (hasVideo &&
              (callState == CallStateEnum.CONFIRMED ||
                  callState == CallStateEnum.STREAM))
            Positioned.fill(
              child: RTCVideoView(
                sipService.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!hasVideo || callState != CallStateEnum.CONFIRMED) ...[
                      _buildCallStateIndicator(context, callState),
                      const SizedBox(height: 48),
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          size: 60,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (remoteName != null && remoteName.isNotEmpty)
                        Text(
                          remoteName,
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                      Text(
                        remoteNumber,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 16),
                    if (callState == CallStateEnum.CONFIRMED ||
                        callState == CallStateEnum.HOLD ||
                        callState == CallStateEnum.MUTED)
                      Text(
                        _formatDuration(sipService.callDuration),
                        style: hasVideo
                            ? theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                shadows: [
                                  const Shadow(
                                    blurRadius: 2,
                                    color: Colors.black,
                                  ),
                                ],
                              )
                            : theme.textTheme.titleLarge,
                      ),
                    const SizedBox(height: 48),
                    if (isIncoming &&
                        callState == CallStateEnum.CALL_INITIATION)
                      _buildIncomingCallButtons(context, sipService)
                    else if (callState == CallStateEnum.CONFIRMED ||
                        callState == CallStateEnum.HOLD ||
                        callState == CallStateEnum.MUTED)
                      _buildActiveCallButtons(context, sipService, hasVideo)
                    else
                      _buildHangupButton(context, sipService),
                  ],
                ),
              ),
            ),
          ),

          if (hasVideo &&
              (callState == CallStateEnum.CONFIRMED ||
                  callState == CallStateEnum.STREAM))
            Positioned(
              right: 20,
              bottom: 20,
              width: 120,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(
                  sipService.localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCallStateIndicator(BuildContext context, CallStateEnum state) {
    final theme = Theme.of(context);
    String stateText;
    Color stateColor;

    switch (state) {
      case CallStateEnum.CALL_INITIATION:
        stateText = 'Incoming Call';
        stateColor = Colors.blue;
        break;
      case CallStateEnum.CONNECTING:
        stateText = 'Connecting...';
        stateColor = Colors.orange;
        break;
      case CallStateEnum.PROGRESS:
        stateText = 'Ringing...';
        stateColor = Colors.orange;
        break;
      case CallStateEnum.CONFIRMED:
        stateText = 'Connected';
        stateColor = Colors.green;
        break;
      case CallStateEnum.HOLD:
        stateText = 'On Hold';
        stateColor = Colors.orange;
        break;
      case CallStateEnum.MUTED:
        stateText = 'Muted';
        stateColor = Colors.orange;
        break;
      default:
        stateText = state.name;
        stateColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: stateColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        stateText,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: stateColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildIncomingCallButtons(
    BuildContext context,
    SipService sipService,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            onPressed: sipService.reject,
            backgroundColor: Colors.red,
            heroTag: 'reject',
            child: const Icon(Icons.call_end, size: 32),
          ),
        ),
        const SizedBox(width: 48),
        SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            onPressed: () => sipService.answer(video: false),
            backgroundColor: Colors.green,
            heroTag: 'answer_audio',
            child: const Icon(Icons.call, size: 32),
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            onPressed: () => sipService.answer(video: true),
            backgroundColor: Colors.blue,
            heroTag: 'answer_video',
            child: const Icon(Icons.videocam, size: 32),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCallButtons(
    BuildContext context,
    SipService sipService,
    bool hasVideo,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionButton(
              icon: sipService.isMuted ? Icons.mic_off : Icons.mic,
              label: 'Mute',
              onPressed: sipService.toggleMute,
              isActive: sipService.isMuted,
              hasVideo: hasVideo,
            ),
            const SizedBox(width: 24),
            _buildActionButton(
              icon: Icons.dialpad,
              label: 'Keypad',
              onPressed: () => _showDtmfDialog(context, sipService),
              hasVideo: hasVideo,
            ),
            const SizedBox(width: 24),
            _buildActionButton(
              icon: sipService.isOnHold ? Icons.play_arrow : Icons.pause,
              label: 'Hold',
              onPressed: sipService.toggleHold,
              isActive: sipService.isOnHold,
              hasVideo: hasVideo,
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildHangupButton(context, sipService),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
    bool hasVideo = false,
  }) {
    return Column(
      children: [
        Material(
          color: isActive
              ? Colors.blue
              : (hasVideo ? Colors.black45 : Colors.grey.shade800),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: hasVideo ? Colors.white : null,
            shadows: hasVideo
                ? [const Shadow(blurRadius: 2, color: Colors.black)]
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildHangupButton(BuildContext context, SipService sipService) {
    return SizedBox(
      width: 72,
      height: 72,
      child: FloatingActionButton(
        onPressed: sipService.hangup,
        backgroundColor: Colors.red,
        child: const Icon(Icons.call_end, size: 32),
      ),
    );
  }

  void _showDtmfDialog(BuildContext context, SipService sipService) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'DTMF Keypad',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildDtmfDialpad(sipService),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDtmfDialpad(SipService sipService) {
    return Column(
      children: [
        _buildDtmfRow(['1', '2', '3'], sipService),
        const SizedBox(height: 12),
        _buildDtmfRow(['4', '5', '6'], sipService),
        const SizedBox(height: 12),
        _buildDtmfRow(['7', '8', '9'], sipService),
        const SizedBox(height: 12),
        _buildDtmfRow(['*', '0', '#'], sipService),
      ],
    );
  }

  Widget _buildDtmfRow(List<String> digits, SipService sipService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((digit) => _buildDtmfButton(digit, sipService))
          .toList(),
    );
  }

  Widget _buildDtmfButton(String digit, SipService sipService) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => sipService.sendDtmf(digit),
          customBorder: const CircleBorder(),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(digit, style: const TextStyle(fontSize: 24)),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
