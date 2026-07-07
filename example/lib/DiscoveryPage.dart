import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

class DiscoveryPage extends StatefulWidget {
  /// If true, discovery starts on page start, otherwise user must press action button.
  final bool start;

  const DiscoveryPage({this.start = true});

  @override
  _DiscoveryPage createState() => new _DiscoveryPage();
}

class _DiscoveryPage extends State<DiscoveryPage> {
  StreamSubscription<BluetoothDiscoveryResult>? _streamSubscription;
  List<BluetoothDiscoveryResult> results =
      List<BluetoothDiscoveryResult>.empty(growable: true);
  bool isDiscovering = false;

  _DiscoveryPage();

  @override
  void initState() {
    super.initState();

    isDiscovering = widget.start;
    if (isDiscovering) {
      _startDiscovery();
    }
  }

  void _restartDiscovery() {
    setState(() {
      results.clear();
      isDiscovering = true;
    });

    _startDiscovery();
  }

  void _startDiscovery() {
    _streamSubscription =
        FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      setState(() {
        final existingIndex = results.indexWhere(
            (element) => element.device.address == r.device.address);
        if (existingIndex >= 0)
          results[existingIndex] = r;
        else
          results.add(r);
      });
    });

    _streamSubscription!.onDone(() {
      setState(() {
        isDiscovering = false;
      });
    });
  }

  // @TODO . One day there should be `_pairDevice` on long tap on something... ;)

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and cancel discovery
    _streamSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isDiscovering
            ? Text('Discovering devices')
            : Text('Discovered devices'),
        actions: <Widget>[
          isDiscovering
              ? FittedBox(
                  child: Container(
                    margin: new EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.replay),
                  onPressed: _restartDiscovery,
                )
        ],
      ),
      body: ListView.builder(
          itemCount: results.length,
          itemBuilder: (BuildContext context, index) {
            BluetoothDiscoveryResult result = results[index];
            final device = result.device;

            final isBonded = device.bondState == BluetoothBondState.bonded;
            final isClassic = device.type == BluetoothDeviceType.classic;

            return ListTile(
              leading: Icon(
                isClassic ? Icons.bluetooth : Icons.bluetooth_disabled,
                color: isClassic ? Colors.blue : Colors.grey,
              ),
              title: Text(device.name ?? "Sin nombre"),
              subtitle: Text("${device.address}\nRSSI: ${result.rssi}"),
              isThreeLine: true,

              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isBonded ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isBonded ? "BONDED" : "NEW",
                  style: TextStyle(color: Colors.white),
                ),
              ),

              onTap: () async {
                if (!isClassic) {
                  _showError("Dispositivo no compatible (no SPP)");
                  return;
                }

                try {
                  // 🔐 AUTO BOND
                  if (!isBonded) {
                    print("🔐 Emparejando ${device.address}...");

                    bool bonded = await FlutterBluetoothSerial.instance
                            .bondDeviceAtAddress(device.address) ??
                        false;

                    if (!bonded) {
                      _showError("No se pudo emparejar");
                      return;
                    }

                    print("✅ Emparejado");

                    setState(() {
                      results[index] = BluetoothDiscoveryResult(
                        device: BluetoothDevice(
                          name: device.name,
                          address: device.address,
                          type: device.type,
                          bondState: BluetoothBondState.bonded,
                        ),
                        rssi: result.rssi,
                      );
                    });
                  }

                  Navigator.of(context).pop(results[index].device);
                } catch (e) {
                  _showError("Error: $e");
                }
              },

              // 🔧 LONG PRESS = toggle bonding
              onLongPress: () async {
                try {
                  if (isBonded) {
                    await FlutterBluetoothSerial.instance
                        .removeDeviceBondWithAddress(device.address);
                    print("❌ Unbonded");
                  } else {
                    await FlutterBluetoothSerial.instance
                        .bondDeviceAtAddress(device.address);
                    print("✅ Bonded");
                  }

                  _restartDiscovery();
                } catch (e) {
                  _showError("Error bonding: $e");
                }
              },
            );
          }),
    );
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
}
