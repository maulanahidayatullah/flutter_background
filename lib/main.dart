import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart'; // ✅ Tambahkan untuk format tanggal

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

/// Inisialisasi Background Service
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // 🟢 Tambahkan inisialisasi Notification Channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'background_service', // id channel
    'Background Service', // nama channel
    description: 'Notifikasi untuk stopwatch background',
    importance: Importance.low,
  );

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStartService,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'background_service',
      initialNotificationTitle: 'Stopwatch Aktif',
      initialNotificationContent: 'Sedang berjalan di background...',
    ),
    iosConfiguration: IosConfiguration(),
  );
}

/// Fungsi utama background
@pragma('vm:entry-point')
void onStartService(ServiceInstance service) async {
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    final now = DateTime.now();
    final formatted = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(now); // ✅ format timestamp
    service.invoke('update', {"timestamp": formatted});

    // Update notifikasi biar user tahu stopwatch masih hidup
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Stopwatch Aktif',
        content: 'Terakhir update: $formatted',
      );
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final List<String> _timestamps = [];
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();

    // Listener untuk menerima data dari service
    FlutterBackgroundService().on('update').listen((event) {
      if (event?['timestamp'] != null) {
        setState(() {
          // ✅ Masukkan data terbaru di urutan pertama
          _timestamps.insert(0, event!['timestamp']);
        });
      }
    });
  }

  Future<void> _startStopwatch() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
      setState(() {
        _isRunning = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Background Stopwatch')),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _timestamps.length,
                itemBuilder: (context, index) =>
                    ListTile(title: Text(_timestamps[index])),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _startStopwatch,
                child: Text(_isRunning ? 'Running...' : 'Start Stopwatch'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
