import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

void main() => runApp(const OmniRobotApp());

class OmniRobotApp extends StatelessWidget {
  const OmniRobotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Omni Robot Controller',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        primaryColor: const Color(0xFF00d9ff),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0f3460),
          foregroundColor: Color(0xFF00d9ff),
          elevation: 2,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF16213e),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const RobotControlScreen(),
    );
  }
}

class RobotControlScreen extends StatefulWidget {
  const RobotControlScreen({super.key});

  @override
  _RobotControlScreenState createState() => _RobotControlScreenState();
}

// Loading screen widget
class LoadingScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const LoadingScreen({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    // Simulate loading for 3 seconds, then proceed
    Future.delayed(const Duration(seconds: 3), onComplete);

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Custom logo image
            SizedBox(
              width: 300,
              height: 300,
              child: Image.asset(
                'assets/omni_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if image fails to load
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00d9ff), width: 4),
                      color: const Color(0xFF0f3460),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.precision_manufacturing,
                        size: 120,
                        color: Color(0xFF00d9ff),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'OMNI ROBOT',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00d9ff),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFF0f3460),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00d9ff)),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF00d9ff),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RobotControlScreenState extends State<RobotControlScreen> {
  static const platform = MethodChannel('bluetooth_classic');

  bool isConnected = false;
  bool isLoading = true;
  List<Map<dynamic, dynamic>> devices = [];
  String? connectedDeviceName;
  double speed = 180.0;
  bool isScanning = false;
  Timer? _holdTimer;
  String? _holdCommand;

  @override
  void initState() {
    super.initState();
    _setPortrait();
    _requestPermissions();
  }

  Future<void> _setPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _setLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.bluetoothConnect.request();
      await Permission.bluetoothScan.request();
      await Permission.location.request();
    }
    _getPairedDevices();
  }

  Future<void> _getPairedDevices() async {
    setState(() => isScanning = true);
    try {
      final List<dynamic> result =
          await platform.invokeMethod('getPairedDevices');
      setState(() {
        devices = result.cast<Map<dynamic, dynamic>>();
      });
    } catch (e) {
      print('Error getting devices: $e');
    }
    setState(() => isScanning = false);
  }

  Future<void> _connect(String address, String name) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      final bool result =
          await platform.invokeMethod('connect', {'address': address});

      Navigator.pop(context);

      if (result) {
        await _setLandscape();
        setState(() {
          isConnected = true;
          connectedDeviceName = name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('✓ Connected to $name'),
              backgroundColor: Colors.green),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        _sendCommand('SPD ${speed.toInt()}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to connect'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      print('Connection error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5)),
      );
    }
  }

  Future<void> _disconnect() async {
    try {
      await platform.invokeMethod('disconnect');
      await _setPortrait();
      setState(() {
        isConnected = false;
        connectedDeviceName = null;
      });
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }

  Future<void> _sendCommand(String cmd) async {
    if (isConnected) {
      try {
        await platform.invokeMethod('sendData', {'data': '$cmd\n'});
        print('Sent: $cmd');
      } catch (e) {
        print('Error sending command: $e');
      }
    }
  }

  void _startHold(String cmd) {
    // start periodic sends while held so motors keep running
    _holdCommand = cmd;
    _holdTimer?.cancel();
    // send immediately then repeatedly while held
    _sendCommand(cmd);
    _holdTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_holdCommand != null) {
        _sendCommand(cmd);
      }
    });
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdCommand = null;
    // send stop command to ensure robot halts
    _sendCommand('S');
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return LoadingScreen(
        onComplete: () {
          setState(() {
            isLoading = false;
          });
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Omni Robot Controller'),
        actions: [
          if (isConnected)
            IconButton(icon: const Icon(Icons.bluetooth_connected), onPressed: _disconnect)
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _getPairedDevices),
        ],
      ),
      body: isConnected ? _buildControlInterface() : _buildDeviceList(),
    );
  }

  // ---------------------- Device Selection -----------------------
  Widget _buildDeviceList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Select a Bluetooth Device',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Looking for "SARM_OMNI_BT"',
                  style: TextStyle(fontSize: 14, color: Colors.blueAccent)),
              const SizedBox(height: 5),
              const Text('Make sure your ESP32 is paired in phone settings first',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              if (isScanning)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Devices'),
                    onPressed: _getPairedDevices),
            ],
          ),
        ),
        Expanded(
          child: devices.isEmpty
              ? const Center(
                  child: Text(
                      'No paired devices found.\nPair your ESP32 in Bluetooth settings first.'))
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final name = device['name'] ?? 'Unknown';
                    final address = device['address'] ?? '';
                    return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(name),
                        subtitle: Text(address),
                        trailing: name.contains('SARM') || name.contains('OMNI')
                            ? const Icon(Icons.stars, color: Colors.amber)
                            : null,
                        onTap: () => _connect(address, name));
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------- Landscape Movement -----------------------
  Widget _buildControlInterface() {
    return LayoutBuilder(builder: (context, constraints) {
      // Make D-pad larger and right controls more organized.
      final double dpadButtonSize = constraints.maxHeight / 4.8; // larger D-pad
      final double dpadCellSize = dpadButtonSize; // each D-pad cell
      final double rotationButtonSize = constraints.maxHeight / 5; // larger rotate buttons
      final double sliderWidth = constraints.maxWidth * 0.22; // narrower slider

      return Row(
        children: [
          // ---------------- D-Pad Left ----------------
          Expanded(
            flex: 4,
            child: Center(
              child: SizedBox(
                width: dpadCellSize * 3 + 20,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSmallButton('↖', 'FL', dpadCellSize),
                        const SizedBox(width: 6),
                        _buildSmallButton('↑', 'F', dpadCellSize),
                        const SizedBox(width: 6),
                        _buildSmallButton('↗', 'FR', dpadCellSize),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSmallButton('←', 'L', dpadCellSize),
                        const SizedBox(width: 6),
                        _buildSmallButton('■', 'S', dpadCellSize),
                        const SizedBox(width: 6),
                        _buildSmallButton('→', 'R', dpadCellSize),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSmallButton('↙', 'BL', dpadCellSize),
                        const SizedBox(width: 6),
                        _buildSmallButton('↓', 'B', dpadCellSize),
                        const SizedBox(width: 6),
                        _buildSmallButton('↘', 'BR', dpadCellSize),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---------------- Right Controls ----------------
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Connected: ${connectedDeviceName ?? "Robot"}',
                      style: const TextStyle(fontSize: 16, color: Colors.greenAccent)),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildSpeedControl(sliderWidth),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildRotationButtons(rotationButtonSize),
                    ),
                  ),
                  // Quick command buttons removed per user request
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildSpeedControl([double? width]) {
    return Column(
      children: [
        const Text('Speed Control', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        SizedBox(
          width: width ?? double.infinity,
          child: Slider(
            value: speed,
            min: 0,
            max: 255,
            divisions: 10,
            label: speed.round().toString(),
            onChanged: (value) => setState(() => speed = value),
            onChangeEnd: (value) => _sendCommand('SPD ${value.toInt()}'),
          ),
        ),
        Text('${speed.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRotationButtons(double size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton('↺ Rotate L', 'CCW', size),
        const SizedBox(width: 10),
        _buildControlButton('↻ Rotate R', 'CW', size),
      ],
    );
  }

  Widget _buildControlButton(String label, String command, double size) {
    return GestureDetector(
      onTapDown: (_) => _startHold(command),
      onTapUp: (_) => _stopHold(),
      onTapCancel: () => _stopHold(),
      child: Container(
        margin: const EdgeInsets.all(4),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF0066cc),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0xFF00d9ff), blurRadius: 8, offset: Offset(0, 0), spreadRadius: 2)],
        ),
        child: Center(
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(color: const Color(0xFF00d9ff), fontSize: (size * 0.16).clamp(10, 18), fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildSmallButton(String label, String command, double size) {
    return GestureDetector(
      onTapDown: (_) => _startHold(command),
      onTapUp: (_) => _stopHold(),
      onTapCancel: () => _stopHold(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF16213e),
          border: Border.all(color: const Color(0xFF00d9ff), width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0xFF00d9ff), blurRadius: 6, offset: Offset(0, 0), spreadRadius: 1)],
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(color: const Color(0xFF00d9ff), fontSize: (size * 0.28).clamp(12, 20), fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
