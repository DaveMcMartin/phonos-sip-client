import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';
import '../models/sip_configuration.dart';
import '../services/sip_service.dart';

class ConfigurationPage extends StatefulWidget {
  const ConfigurationPage({super.key});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _hostnameController = TextEditingController();
  final _portController = TextEditingController();
  final _authorizationUserController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _wsUrlController = TextEditingController();
  final _userAgentController = TextEditingController();
  final _iceServersController = TextEditingController();

  TransportType _selectedProtocol = TransportType.WS;
  DtmfMode _selectedDtmfMode = DtmfMode.RFC2833;
  bool _useSsl = true;
  RegistrationStateEnum? _lastRegistrationState;
  late SipService _sipService;

  @override
  void initState() {
    super.initState();
    _sipService = context.read<SipService>();
    _sipService.addListener(_onSipServiceChanged);
    _loadConfiguration();
  }

  @override
  void dispose() {
    _sipService.removeListener(_onSipServiceChanged);
    _usernameController.dispose();
    _passwordController.dispose();
    _hostnameController.dispose();
    _portController.dispose();
    _authorizationUserController.dispose();
    _displayNameController.dispose();
    _wsUrlController.dispose();
    _userAgentController.dispose();
    _iceServersController.dispose();
    super.dispose();
  }

  void _onSipServiceChanged() {
    if (!mounted) return;
    final sipService = context.read<SipService>();
    final currentState = sipService.registrationState.state;

    if (currentState == RegistrationStateEnum.REGISTRATION_FAILED &&
        currentState != _lastRegistrationState) {
      final cause =
          sipService.registrationState.cause?.cause ?? 'Unknown error';
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration Failed: $cause'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    _lastRegistrationState = currentState;
  }

  void _loadConfiguration() {
    final sipService = context.read<SipService>();
    final config = sipService.configuration ?? SipConfiguration.defaultConfig();

    _usernameController.text = config.username;
    _passwordController.text = config.password;
    _hostnameController.text = config.hostname;
    _portController.text = config.port.toString();
    _authorizationUserController.text = config.authorizationUser ?? '';
    _displayNameController.text = config.displayName ?? '';
    _wsUrlController.text = config.wsUrl ?? '';
    _userAgentController.text = config.userAgent ?? '';
    _selectedProtocol = config.protocol;
    _selectedDtmfMode = config.dtmfMode ?? DtmfMode.RFC2833;
    _useSsl = config.useSsl;
    _iceServersController.text = config.iceServers
        .map((ice) => ice.urls)
        .join('\n');

    setState(() {});
  }

  Future<void> _saveAndConnect() async {
    if (!_formKey.currentState!.validate()) return;

    final iceServers = _iceServersController.text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((url) => IceServerConfig(urls: url.trim()))
        .toList();

    final config = SipConfiguration(
      username: _usernameController.text,
      password: _passwordController.text,
      hostname: _hostnameController.text,
      port: int.parse(_portController.text),
      protocol: _selectedProtocol,
      iceServers: iceServers,
      useSsl: _useSsl,
      authorizationUser: _authorizationUserController.text.isEmpty
          ? null
          : _authorizationUserController.text,
      displayName: _displayNameController.text.isEmpty
          ? null
          : _displayNameController.text,
      wsUrl: _wsUrlController.text.isEmpty ? null : _wsUrlController.text,
      userAgent: _userAgentController.text.isEmpty
          ? null
          : _userAgentController.text,
      dtmfMode: _selectedDtmfMode,
    );

    final sipService = context.read<SipService>();
    await sipService.saveConfiguration(config);

    if (!mounted) return;

    try {
      await sipService.connect();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecting to SIP server...'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    final sipService = context.read<SipService>();
    await sipService.disconnect();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disconnected from SIP server')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sipService = context.watch<SipService>();
    final theme = Theme.of(context);

    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildConnectionStatus(context, sipService, theme),
            const SizedBox(height: 24),
            _buildBasicSettings(),
            const SizedBox(height: 24),
            _buildAdvancedSettings(),
            const SizedBox(height: 24),
            _buildIceServers(),
            const SizedBox(height: 32),
            _buildActionButtons(sipService),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(
    BuildContext context,
    SipService sipService,
    ThemeData theme,
  ) {
    final isRegistered = sipService.isRegistered;
    final statusText = sipService.connectionStatus;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 16,
              color: isRegistered ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Username is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hostnameController,
              decoration: const InputDecoration(
                labelText: 'Hostname',
                prefixIcon: Icon(Icons.dns),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Hostname is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Port is required';
                      }
                      final port = int.tryParse(value);
                      if (port == null || port < 1 || port > 65535) {
                        return 'Invalid port';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<TransportType>(
                    value: _selectedProtocol,
                    decoration: const InputDecoration(
                      labelText: 'Protocol',
                      prefixIcon: Icon(Icons.swap_horiz),
                      border: OutlineInputBorder(),
                    ),
                    items: TransportType.values.map((protocol) {
                      return DropdownMenuItem(
                        value: protocol,
                        child: Text(protocol.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          if (value == TransportType.WS) {
                            if (_portController.text == '5060') {
                              _portController.text = _useSsl ? '443' : '80';
                            }
                          } else {
                            if (_portController.text == '80' ||
                                _portController.text == '443') {
                              _portController.text = '5060';
                            }
                          }
                          _selectedProtocol = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_selectedProtocol == TransportType.WS) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _wsUrlController,
                decoration: const InputDecoration(
                  labelText: 'WebSocket URL (Optional)',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                  hintText: 'wss://example.com/ws',
                  helperText: 'Overrides Hostname/Port/SSL settings if set',
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Use SSL (WSS)'),
                subtitle: const Text('Secure WebSocket connection'),
                value: _useSsl,
                onChanged: (value) {
                  setState(() {
                    _useSsl = value;
                    if (value && _portController.text == '80') {
                      _portController.text = '443';
                    } else if (!value && _portController.text == '443') {
                      _portController.text = '80';
                    }
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advanced Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name (Optional)',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
                hintText: 'Your name',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _authorizationUserController,
              decoration: const InputDecoration(
                labelText: 'Authorization User (Optional)',
                prefixIcon: Icon(Icons.verified_user),
                border: OutlineInputBorder(),
                hintText: 'Leave empty if same as username',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _userAgentController,
              decoration: const InputDecoration(
                labelText: 'User Agent (Optional)',
                prefixIcon: Icon(Icons.phone_android),
                border: OutlineInputBorder(),
                hintText: 'Phonos SIP Client',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DtmfMode>(
              value: _selectedDtmfMode,
              decoration: const InputDecoration(
                labelText: 'DTMF Mode',
                prefixIcon: Icon(Icons.dialpad),
                border: OutlineInputBorder(),
              ),
              items: DtmfMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(mode.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedDtmfMode = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIceServers() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ICE Servers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'One STUN/TURN server URL per line',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _iceServersController,
              decoration: const InputDecoration(
                labelText: 'ICE Servers',
                prefixIcon: Icon(Icons.cloud),
                border: OutlineInputBorder(),
                hintText: 'stun:stun.l.google.com:19302',
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'At least one ICE server is required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(SipService sipService) {
    final isRegistered = sipService.isRegistered;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isRegistered ? _disconnect : _saveAndConnect,
            icon: Icon(isRegistered ? Icons.link_off : Icons.link),
            label: Text(isRegistered ? 'Disconnect' : 'Save & Connect'),
            style: FilledButton.styleFrom(
              backgroundColor: isRegistered ? Colors.orange : Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
