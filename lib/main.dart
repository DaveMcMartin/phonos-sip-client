import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/sip_service.dart';
import 'services/log_service.dart';
import 'pages/dialpad_page.dart';
import 'pages/call_history_page.dart';
import 'pages/configuration_page.dart';

void main() {
  final originalDebugPrint = debugPrint;

  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      LogService().addLog(message);
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };

  runApp(const PhonosSipClient());
}

class PhonosSipClient extends StatelessWidget {
  const PhonosSipClient({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SipService()),
        ChangeNotifierProvider(create: (_) => LogService()),
      ],
      child: MaterialApp(
        title: 'Phonos SIP Client',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    DialpadPage(),
    CallHistoryPage(),
    ConfigurationPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phonos SIP Client'), centerTitle: true),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dialpad), label: 'Dialpad'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Config'),
        ],
      ),
    );
  }
}
