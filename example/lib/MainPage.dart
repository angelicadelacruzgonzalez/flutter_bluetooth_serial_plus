import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:scoped_model/scoped_model.dart';

import './BackgroundCollectedPage.dart';
import './BackgroundCollectingTask.dart';
import './ChatPage.dart';
import './DiscoveryPage.dart';
import './SelectBondedDevicePage.dart';

import 'dart:convert';
import 'dart:typed_data';

class DeviceConnection {
  final BluetoothDevice device;

  BluetoothConnection? _connection;
  bool _isConnecting = false;
  bool _manualDisconnect = false;

  final _dataController = StreamController<String>.broadcast();
  final _stateController = StreamController<bool>.broadcast();

  Stream<String> get onData => _dataController.stream;
  Stream<bool> get onState => _stateController.stream;

  DeviceConnection(this.device);
  bool get isPhone {
    final name = (device.name ?? "").toLowerCase();

    return name.contains("moto") ||
        name.contains("iphone") ||
        name.contains("samsung") ||
        name.contains("xiaomi") ||
        name.contains("huawei") ||
        name.contains("redmi");
  }

  Future<void> connect() async {
    if (_isConnecting) return;

    if (isPhone) {
      print("⛔ ${device.name} es celular → NO SPP");
      _stateController.add(false);
      return;
    }

    _isConnecting = true;
    _manualDisconnect = false;

    try {
      print("🔄 Conectando a ${device.name} (${device.address})");

      _connection = await BluetoothConnection.toAddress(device.address);

      print("✅ Conectado a ${device.name}");

      _stateController.add(true);

      _connection!.input!.listen((data) {
        final text = utf8.decode(data);
        print("📥 ${device.name}: $text");
        _dataController.add(text);
      }).onDone(() {
        _stateController.add(false);

        if (!_manualDisconnect) {
          _reconnect();
        }
      });
    } catch (e) {
      _stateController.add(false);

      _reconnect();
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> send(String text) async {
    if (_connection == null || !_connection!.isConnected) return;

    try {
      _connection!.output.add(
        Uint8List.fromList(utf8.encode(text + "\r\n")),
      );
      await _connection!.output.allSent;
    } catch (e) {
      print("❌ Error enviando: $e");
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    await _connection?.close();
    _stateController.add(false);
  }

  void _reconnect() async {
    if (isPhone) {
      print("⛔ Reconexión cancelada (celular)");
      return;
    }

    print("🔁 Reintentando ${device.name} en 3s...");
    await Future.delayed(Duration(seconds: 3));

    if (!_manualDisconnect) connect();
  }
}

// ================= MANAGER =================

class BluetoothManager {
  static final BluetoothManager _instance = BluetoothManager._internal();
  factory BluetoothManager() => _instance;

  BluetoothManager._internal();

  final Map<String, DeviceConnection> _connections = {};

  Future<DeviceConnection?> connectDevice(BluetoothDevice device) async {
    final temp = DeviceConnection(device);
    if (temp.isPhone) {
      print("📡 ${device.name} → usar WiFi, no Bluetooth");
      return null;
    }

    if (_connections.containsKey(device.address)) {
      return _connections[device.address]!;
    }

    final conn = DeviceConnection(device);
    _connections[device.address] = conn;

    await conn.connect();

    return conn;
  }

  void disconnectAll() {
    for (var c in _connections.values) {
      c.disconnect();
    }
    _connections.clear();
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPage createState() => new _MainPage();
}

class _MainPage extends State<MainPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;

  String _address = "...";
  String _name = "...";

  Timer? _discoverableTimeoutTimer;
  int _discoverableTimeoutSecondsLeft = 0;

  BackgroundCollectingTask? _collectingTask;

  bool _autoAcceptPairingRequests = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBluetooth();
    });
  }

  Future<void> _initializeBluetooth() async {
    ;
    try {
      _bluetoothState = await FlutterBluetoothSerial.instance.state;
      setState(() {});
      print(_bluetoothState);

      bool isEnabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
      if (isEnabled) {
        _address = (await FlutterBluetoothSerial.instance.address) ?? "...";
        _name = (await FlutterBluetoothSerial.instance.name) ?? "...";
        setState(() {});
      }

      FlutterBluetoothSerial.instance
          .onStateChanged()
          .listen((BluetoothState state) {
        setState(() {
          _bluetoothState = state;
          _discoverableTimeoutTimer = null;
          _discoverableTimeoutSecondsLeft = 0;
        });
      });
    } catch (e) {
      print("Error initializing Bluetooth: \$e");
    }
  }

  @override
  void dispose() {
    FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    _collectingTask?.dispose();
    _discoverableTimeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _enableDiscoverable() async {
    print('🔵 Activando modo discoverable');

    final int timeout =
        (await FlutterBluetoothSerial.instance.requestDiscoverable(60))!;

    if (timeout < 0) {
      print('❌ Usuario canceló discoverable');
      return;
    }

    setState(() {
      _discoverableTimeoutTimer?.cancel();
      _discoverableTimeoutSecondsLeft = timeout;
    });

    _startDiscoverableTimer();
  }

  void _startDiscoverableTimer() {
    _discoverableTimeoutTimer =
        Timer.periodic(Duration(seconds: 1), (Timer timer) {
      setState(() {
        if (_discoverableTimeoutSecondsLeft <= 0) {
          timer.cancel();
          _discoverableTimeoutSecondsLeft = 0;
        } else {
          _discoverableTimeoutSecondsLeft--;
        }
      });
    });
  }

  Future<void> _disableDiscoverable() async {
    print('🔴 Desactivando discoverable');

    _discoverableTimeoutTimer?.cancel();

    setState(() {
      _discoverableTimeoutSecondsLeft = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Bluetooth Serial'),
      ),
      body: Container(
        child: ListView(
          children: <Widget>[
            Divider(),
            ListTile(title: const Text('General')),
            SwitchListTile(
              title: const Text('Enable Bluetooth'),
              value: _bluetoothState.isEnabled,
              onChanged: (bool value) {
                future() async {
                  if (value)
                    await FlutterBluetoothSerial.instance.requestEnable();
                  else
                    await FlutterBluetoothSerial.instance.requestDisable();
                }

                future().then((_) {
                  setState(() {});
                });
              },
            ),
            ListTile(
              title: const Text('Bluetooth status'),
              subtitle: Text(_bluetoothState.toString()),
              trailing: ElevatedButton(
                child: const Text('Settings'),
                onPressed: () {
                  FlutterBluetoothSerial.instance.openSettings();
                },
              ),
            ),
            ListTile(
              title: const Text('Local adapter address'),
              subtitle: Text(_address),
            ),
            ListTile(
              title: const Text('Local adapter name'),
              subtitle: Text(_name),
            ),
            ListTile(
              title: _discoverableTimeoutSecondsLeft == 0
                  ? const Text("Discoverable")
                  : Text(
                      "Discoverable for \ ${_discoverableTimeoutSecondsLeft}s"),
              subtitle: const Text("Allow other devices to find this device"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _discoverableTimeoutSecondsLeft != 0,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _enableDiscoverable();
                        } else {
                          _disableDiscoverable();
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      _enableDiscoverable(); // o abrir diálogo si quieres custom tiempo
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      print('Discoverable requested');
                      final int timeout = (await FlutterBluetoothSerial.instance
                          .requestDiscoverable(60))!;
                      if (timeout < 0) {
                        print('Discoverable mode denied');
                      } else {
                        print(
                            'Discoverable mode acquired for \$timeout seconds');
                      }
                      setState(() {
                        _discoverableTimeoutTimer?.cancel();
                        _discoverableTimeoutSecondsLeft = timeout;
                        _discoverableTimeoutTimer =
                            Timer.periodic(Duration(seconds: 1), (Timer timer) {
                          setState(() {
                            if (_discoverableTimeoutSecondsLeft < 0) {
                              FlutterBluetoothSerial.instance.isDiscoverable
                                  .then((isDiscoverable) {
                                if (isDiscoverable ?? false) {
                                  _discoverableTimeoutSecondsLeft += 1;
                                }
                              });
                              timer.cancel();
                              _discoverableTimeoutSecondsLeft = 0;
                            } else {
                              _discoverableTimeoutSecondsLeft -= 1;
                            }
                          });
                        });
                      });
                    },
                  )
                ],
              ),
            ),
            Divider(),
            ListTile(title: const Text('Devices discovery and connection')),
            SwitchListTile(
              title: const Text('Auto-try specific pin when pairing'),
              subtitle: const Text('Pin 1234'),
              value: _autoAcceptPairingRequests,
              onChanged: (bool value) {
                setState(() {
                  _autoAcceptPairingRequests = value;
                });
                if (value) {
                  FlutterBluetoothSerial.instance.setPairingRequestHandler(
                      (BluetoothPairingRequest request) {
                    if (request.pairingVariant == PairingVariant.Pin) {
                      return Future.value("1234");
                    }
                    return Future.value(null);
                  });
                } else {
                  FlutterBluetoothSerial.instance
                      .setPairingRequestHandler(null);
                }
              },
            ),
            ListTile(
              title: ElevatedButton(
                  child: const Text('Explore discovered devices'),
                  onPressed: () async {
                    final BluetoothDevice? selectedDevice =
                        await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return DiscoveryPage();
                        },
                      ),
                    );

                    if (selectedDevice != null) {
                      if (selectedDevice.bondState !=
                          BluetoothBondState.bonded) {
                        _showError("El dispositivo NO está vinculado");
                        return;
                      }

                      _startChat(context, selectedDevice);
                    } else {
                      print('Connect -> no device selected');
                    }
                  }),
            ),
            ListTile(
              title: ElevatedButton(
                child: const Text('Connect to paired device to chat'),
                onPressed: () async {
                  final BluetoothDevice? selectedDevice =
                      await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return SelectBondedDevicePage(checkAvailability: false);
                      },
                    ),
                  );

                  if (selectedDevice != null) {
                    _startChat(context, selectedDevice);
                  } else {
                    print('Connect -> no device selected');
                  }
                },
              ),
            ),
            Divider(),
            ListTile(title: const Text('Multiple connections example')),
            ListTile(
              title: ElevatedButton(
                child: ((_collectingTask?.inProgress ?? false)
                    ? const Text('Disconnect and stop background collecting')
                    : const Text('Connect to start background collecting')),
                onPressed: () async {
                  if (_collectingTask?.inProgress ?? false) {
                    await _collectingTask!.cancel();
                    setState(() {});
                  } else {
                    final BluetoothDevice? selectedDevice =
                        await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return SelectBondedDevicePage(
                              checkAvailability: false);
                        },
                      ),
                    );

                    if (selectedDevice != null) {
                      await _startBackgroundTask(context, selectedDevice);
                      setState(() {});
                    }
                  }
                },
              ),
            ),
            ListTile(
              title: ElevatedButton(
                child: const Text('View background collected data'),
                onPressed: (_collectingTask != null)
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) {
                              return ScopedModel<BackgroundCollectingTask>(
                                model: _collectingTask!,
                                child: BackgroundCollectedPage(),
                              );
                            },
                          ),
                        );
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startChat(BuildContext context, BluetoothDevice device) async {
    try {
      final connection = await BluetoothManager().connectDevice(device);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            return ChatPage(server: device); // puedes luego migrarlo a TITÁN
          },
        ),
      );
    } catch (e) {
      _showError("Error conectando: $e");
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          )
        ],
      ),
    );
  }

  Future<void> _startBackgroundTask(
    BuildContext context,
    BluetoothDevice server,
  ) async {
    try {
      _collectingTask = await BackgroundCollectingTask.connect(server);
      await _collectingTask!.start();
    } catch (ex) {
      print(ex.toString());
      _collectingTask?.cancel();
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error occured while connecting'),
            content: Text("\ ${ex.toString()}"),
            actions: <Widget>[
              TextButton(
                child: const Text("Close"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }
}
