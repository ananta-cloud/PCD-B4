import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/app_theme.dart';
import 'core/app_colors.dart';
import 'screens/login_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/history_screen.dart';
import 'screens/reports_screen.dart';
import 'services/hive_service.dart';
import 'services/mongo_service.dart';
import 'screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ── Hive Database Initialization ────────────────────────────────────────
    print('🔄 Initializing Hive...');
    await HiveService.initialize();
    print('✓ Hive initialized');

    // ── Environment & MongoDB Initialization ────────────────────────────────
    // Load .env dulu (sync, cepat)
    print('🔄 Loading .env...');
    await dotenv.load(fileName: ".env");
    print('✓ .env loaded');

    // Koneksi MongoDB dilakukan di background — tidak block runApp()
    // Kalau offline/timeout, app tetap jalan dan login akan tampilkan error
    MongoService.connect().catchError((e) {
      log("⚠️ MongoDB tidak tersambung saat startup: $e");
    });

    // ── System UI ───────────────────────────────────────────────────────────
    print('🔄 Setting up SystemChrome...');
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.surfaceContainerLow,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    print('✓ SystemChrome set');

    print('✅ All initialization complete, running app...');
    runApp(const SmartReceiptScannerApp());
  } catch (e, stackTrace) {
    print('❌ FATAL ERROR during initialization: $e');
    print('Stack trace: $stackTrace');
    // Show error dialog instead of crashing
    runApp(
      ErrorDisplayApp(error: e.toString(), stackTrace: stackTrace.toString()),
    );
  }
}

class SmartReceiptScannerApp extends StatelessWidget {
  const SmartReceiptScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Receipt Scanner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // App starts at AuthGate; navigates to MainShell after auth
      home: const AuthGate(),
    );
  }
}

/// Bottom navigation shell — shown after successful login/register
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _screens = [ScanScreen(), HistoryScreen(), ReportsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

/// Error display app — shown if initialization fails
class ErrorDisplayApp extends StatelessWidget {
  final String error;
  final String stackTrace;

  const ErrorDisplayApp({
    required this.error,
    required this.stackTrace,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Receipt Scanner - ERROR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Icon(Icons.error, size: 48, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    '❌ INITIALIZATION ERROR',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Stack Trace:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    stackTrace,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
