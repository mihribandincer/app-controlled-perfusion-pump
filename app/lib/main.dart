import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

void main() {
  runApp(const MyApp());
}

final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();
TextEditingController volumeController = TextEditingController();
TextEditingController durationController = TextEditingController();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Arduino Bluetooth',
      home: BluetoothPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  BluetoothConnection? connection;
  String receivedMessage = "";
  StringBuffer buffer = StringBuffer();
  String statusMessage = "Bluetooth verisi bekleniyor...";

  @override
  void initState() {
    super.initState();
    initNotifications();
    startForegroundService();
    connectToArduino();
  }

  Future<void> initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await notificationsPlugin.initialize(initSettings);
  }

  void showNotification(String message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'bluetooth_channel',
      'Bluetooth Mesajları',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      onlyAlertOnce: false,
      autoCancel: false,
      ongoing: true,
    );

    const NotificationDetails notifDetails = NotificationDetails(android: androidDetails);

    await notificationsPlugin.show(
      0,
      'Arduino Mesajı',
      message,
      notifDetails,
    );
  }

  Future<bool> checkBluetoothPermissions() async {
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final bluetoothScan = await Permission.bluetoothScan.request();
    final location = await Permission.location.request();
    final notification = await Permission.notification.request();

    return bluetoothConnect.isGranted && bluetoothScan.isGranted && location.isGranted && notification.isGranted;
  }

  void startForegroundService() async {
    await FlutterForegroundTask.startService(
      notificationTitle: 'Bluetooth bağlantısı aktif',
      notificationText: 'Arduino verileri dinleniyor...',
      callback: startCallback,
    );
  }

  void connectToArduino() async {
    setState(() {
      statusMessage = "Bluetooth bağlantısı başlatılıyor...";
    });

    bool permissionGranted = await checkBluetoothPermissions();
    if (!permissionGranted) {
      setState(() {
        statusMessage = "Bluetooth izinleri verilmedi.";
      });
      return;
    }

    await FlutterBluetoothSerial.instance.requestEnable();

    List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();

    if (bondedDevices.isEmpty) {
      setState(() {
        statusMessage = "Eşleştirilmiş Bluetooth cihazı bulunamadı.";
      });
      return;
    }

    BluetoothDevice? arduinoDevice;
    try {
      arduinoDevice = bondedDevices.firstWhere(
        (device) => device.name?.toLowerCase().contains('hc') == true,
      );
    } catch (e) {
      setState(() {
        statusMessage = "HC-05 benzeri cihaz bulunamadı.";
      });
      return;
    }

    try {
      BluetoothConnection connectionResult = await BluetoothConnection.toAddress(arduinoDevice.address);

      setState(() {
        statusMessage = "Bağlandı: ${arduinoDevice!.name}";
        connection = connectionResult;
      });

      connection!.input!.listen((Uint8List data) {
        String chunk = utf8.decode(data);
        buffer.write(chunk);

        if (chunk.contains('\n')) {
          String fullMessage = buffer.toString().trim();

          setState(() {
            receivedMessage = fullMessage;
          });

          showNotification(fullMessage);
          buffer.clear();
        }
      }).onDone(() {
        setState(() {
          statusMessage = "Bağlantı kapatıldı.";
        });
      });
    } catch (e) {
      setState(() {
        statusMessage = "Bağlantı hatası: $e";
      });
    }
  }

  void sendDataToArduino(String message) async {
    if (connection != null && connection!.isConnected) {
      connection!.output.add(Uint8List.fromList(utf8.encode('$message\n')));
      await connection!.output.allSent;
    }
  }

  @override
  void dispose() {
    connection?.dispose();
    FlutterForegroundTask.stopService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bluetooth Dinleyici")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: volumeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Hacim (mL)",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Süre (dk)",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final volume = volumeController.text;
                final duration = durationController.text;
                if (volume.isNotEmpty && duration.isNotEmpty) {
                  sendDataToArduino("$volume:$duration");
                }
              },
              child: const Text("Başlat"),
            ),
            const SizedBox(height: 30),
            Text(
              receivedMessage.isNotEmpty ? "Gelen: $receivedMessage" : statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}

void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {
    debugPrint('[onStart] Başlatıldı: $timestamp');
  }

  @override
  void onEvent(DateTime timestamp, SendPort? sendPort) {
    debugPrint('[onEvent] Olay tetiklendi: $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    debugPrint('[onRepeatEvent] Otomatik tekrar: $timestamp');
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    debugPrint('[onDestroy] Servis sonlandırıldı: $timestamp');
  }

  @override
  void onButtonPressed(String id) {
    debugPrint('[onButtonPressed] Butona tıklandı: $id');
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
    debugPrint('[onNotificationPressed] Bildirime tıklandı, uygulama açılıyor');
  }
}
