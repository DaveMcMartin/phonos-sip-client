import 'package:sip_ua/sip_ua.dart';

class IceServerConfig {
  final String urls;
  final String? username;
  final String? credential;

  IceServerConfig({required this.urls, this.username, this.credential});

  Map<String, dynamic> toJson() => {
    'urls': urls,
    if (username != null) 'username': username,
    if (credential != null) 'credential': credential,
  };

  factory IceServerConfig.fromJson(Map<String, dynamic> json) =>
      IceServerConfig(
        urls: json['urls'] as String,
        username: json['username'] as String?,
        credential: json['credential'] as String?,
      );
}

class SipConfiguration {
  final String username;
  final String password;
  final String hostname;
  final int port;
  final TransportType protocol;
  final List<IceServerConfig> iceServers;
  final bool useSsl;
  final String? authorizationUser;
  final String? displayName;
  final String? wsUrl;
  final String? userAgent;
  final DtmfMode? dtmfMode;

  SipConfiguration({
    required this.username,
    required this.password,
    required this.hostname,
    required this.port,
    required this.protocol,
    required this.iceServers,
    required this.useSsl,
    this.authorizationUser,
    this.displayName,
    this.wsUrl,
    this.userAgent,
    this.dtmfMode,
  });

  String get webSocketUrl {
    if (wsUrl != null && wsUrl!.isNotEmpty) {
      return wsUrl!;
    }
    final scheme = useSsl ? 'wss' : 'ws';
    return '$scheme://$hostname:$port';
  }

  String get sipUri => '$username@$hostname';

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'hostname': hostname,
    'port': port,
    'protocol': protocol.name,
    'iceServers': iceServers.map((e) => e.toJson()).toList(),
    'useSsl': useSsl,
    if (authorizationUser != null) 'authorizationUser': authorizationUser,
    if (displayName != null) 'displayName': displayName,
    if (wsUrl != null) 'wsUrl': wsUrl,
    if (userAgent != null) 'userAgent': userAgent,
    if (dtmfMode != null) 'dtmfMode': dtmfMode!.name,
  };

  factory SipConfiguration.fromJson(Map<String, dynamic> json) =>
      SipConfiguration(
        username: json['username'] as String,
        password: json['password'] as String,
        hostname: json['hostname'] as String,
        port: json['port'] as int,
        protocol: TransportType.values.firstWhere(
          (e) => e.name == json['protocol'],
          orElse: () => TransportType.WS,
        ),
        iceServers:
            (json['iceServers'] as List<dynamic>?)
                ?.map(
                  (e) => IceServerConfig.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            [],
        useSsl: json['useSsl'] as bool,
        authorizationUser: json['authorizationUser'] as String?,
        displayName: json['displayName'] as String?,
        wsUrl: json['wsUrl'] as String?,
        userAgent: json['userAgent'] as String?,
        dtmfMode: json['dtmfMode'] != null
            ? DtmfMode.values.firstWhere(
                (e) => e.name == json['dtmfMode'],
                orElse: () => DtmfMode.RFC2833,
              )
            : null,
      );

  factory SipConfiguration.defaultConfig() => SipConfiguration(
    username: '',
    password: '',
    hostname: 'sip.example.com',
    port: 5060,
    protocol: TransportType.WS,
    iceServers: [
      IceServerConfig(urls: 'stun:stun.l.google.com:19302'),
      IceServerConfig(urls: 'stun:stun1.l.google.com:19302'),
      IceServerConfig(urls: 'stun:stun2.l.google.com:19302'),
    ],
    useSsl: false,
    userAgent: 'Phonos SIP Client',
    dtmfMode: DtmfMode.RFC2833,
  );

  SipConfiguration copyWith({
    String? username,
    String? password,
    String? hostname,
    int? port,
    TransportType? protocol,
    List<IceServerConfig>? iceServers,
    bool? useSsl,
    String? authorizationUser,
    String? displayName,
    String? wsUrl,
    String? userAgent,
    DtmfMode? dtmfMode,
  }) => SipConfiguration(
    username: username ?? this.username,
    password: password ?? this.password,
    hostname: hostname ?? this.hostname,
    port: port ?? this.port,
    protocol: protocol ?? this.protocol,
    iceServers: iceServers ?? this.iceServers,
    useSsl: useSsl ?? this.useSsl,
    authorizationUser: authorizationUser ?? this.authorizationUser,
    displayName: displayName ?? this.displayName,
    wsUrl: wsUrl ?? this.wsUrl,
    userAgent: userAgent ?? this.userAgent,
    dtmfMode: dtmfMode ?? this.dtmfMode,
  );
}
