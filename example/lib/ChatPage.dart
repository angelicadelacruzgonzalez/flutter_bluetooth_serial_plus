/* import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

class ChatPage extends StatefulWidget {
  final BluetoothDevice server;

  const ChatPage({required this.server});

  @override
  _ChatPage createState() => new _ChatPage();
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class _ChatPage extends State<ChatPage> {
  static final clientID = 0;
  BluetoothConnection? connection;

  List<_Message> messages = List<_Message>.empty(growable: true);
  String _messageBuffer = '';

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);

  bool isDisconnecting = false;

  @override
  void initState() {
    super.initState();

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      print(widget.server.address);
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection!.input!.listen(_onDataReceived).onDone(() {
        // Example: Detect which side closed the connection
        // There should be `isDisconnecting` flag to show are we are (locally)
        // in middle of disconnecting process, should be set before calling
        // `dispose`, `finish` or `close`, which all causes to disconnect.
        // If we except the disconnection, `onDone` should be fired as result.
        // If we didn't except this (no flag set), it means closing by remote.
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Row> list = messages.map((_message) {
      return Row(
        children: <Widget>[
          Container(
            child: Text(
                (text) {
                  return text == '/shrug' ? '¯\\_(ツ)_/¯' : text;
                }(_message.text.trim()),
                style: TextStyle(color: Colors.white)),
            padding: EdgeInsets.all(12.0),
            margin: EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
            width: 222.0,
            decoration: BoxDecoration(
                color:
                    _message.whom == clientID ? Colors.blueAccent : Colors.grey,
                borderRadius: BorderRadius.circular(7.0)),
          ),
        ],
        mainAxisAlignment: _message.whom == clientID
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
      );
    }).toList();

    final serverName = widget.server.name ?? "Unknown";
    return Scaffold(
      appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting chat to ' + serverName + '...')
              : isConnected
                  ? Text('Live chat with ' + serverName)
                  : Text('Chat log with ' + serverName))),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Flexible(
              child: ListView(
                  padding: const EdgeInsets.all(12.0),
                  controller: listScrollController,
                  children: list),
            ),
            Row(
              children: <Widget>[
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.only(left: 16.0),
                    child: TextField(
                      style: const TextStyle(fontSize: 15.0),
                      controller: textEditingController,
                      decoration: InputDecoration.collapsed(
                        hintText: isConnecting
                            ? 'Wait until connected...'
                            : isConnected
                                ? 'Type your message...'
                                : 'Chat got disconnected',
                        hintStyle: const TextStyle(color: Colors.grey),
                      ),
                      enabled: isConnected,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(8.0),
                  child: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: isConnected
                          ? () => _sendMessage(textEditingController.text)
                          : null),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        messages.add(
          _Message(
            1,
            backspacesCounter > 0
                ? _messageBuffer.substring(
                    0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index),
          ),
        );
        _messageBuffer = dataString.substring(index);
      });
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
              0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();
    textEditingController.clear();

    if (text.length > 0) {
      try {
        connection!.output.add(Uint8List.fromList(utf8.encode(text + "\r\n")));
        await connection!.output.allSent;

        setState(() {
          messages.add(_Message(clientID, text));
        });

        Future.delayed(Duration(milliseconds: 333)).then((_) {
          listScrollController.animateTo(
              listScrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 333),
              curve: Curves.easeOut);
        });
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }
}
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

class ChatPage extends StatefulWidget {
  final BluetoothDevice server;

  const ChatPage({required this.server});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _Message {
  final bool mine;
  final String text;

  _Message(this.mine, this.text);
}

class _ChatPageState extends State<ChatPage> {
  // ===== BLUETOOTH =====
  BluetoothConnection? connection;

  // ===== WIFI =====
  ServerSocket? tcpServer;
  Socket? tcpSocket;
  RawDatagramSocket? udpSocket;

  static const int tcpPort = 4040;
  static const int udpPort = 4041;
  static const String discoveryMsg = "DISCOVER_CHAT_V1";

  // ===== UI =====
  List<_Message> messages = [];
  TextEditingController controller = TextEditingController();
  ScrollController scroll = ScrollController();

  bool isPhoneDevice = false;

  bool isConnecting = true;
  bool isWifiMode = false;

  @override
  void initState() {
    super.initState();
    _initHybrid();
  }

  // =========================
  // 🔥 DETECTOR AUTOMÁTICO
  // =========================
  bool isPhone(String name) {
    final n = name.toLowerCase();
    return n.contains("moto") ||
        n.contains("iphone") ||
        n.contains("samsung") ||
        n.contains("xiaomi") ||
        n.contains("huawei") ||
        n.contains("redmi");
  }

  void _initHybrid() {
    final name = widget.server.name ?? "";

    isPhoneDevice = isPhone(name);

    if (isPhoneDevice) {
      print("📡 Modo WiFi (celular detectado)");
      isWifiMode = true;
      _initWiFi();
    } else {
      print("🔵 Modo Bluetooth");
      _initBluetooth();
    }
  }

  // =========================
  // 🔵 BLUETOOTH SPP
  // =========================
  void _initBluetooth() async {
    try {
      connection = await BluetoothConnection.toAddress(widget.server.address);

      setState(() => isConnecting = false);

      connection!.input!.listen((data) {
        _addMessage(false, String.fromCharCodes(data));
      });
    } catch (e) {
      _addSystem("❌ Error BT: $e");
    }
  }

  // =========================
  // 📡 WIFI AUTO DISCOVERY
  // =========================
  void _initWiFi() async {
    _addSystem("🔍 Buscando peers...");

    await _startUDPListener();
    await _startTCPServer();
    _broadcastDiscovery();

    setState(() => isConnecting = false);
  }
/* 
  Future<void> _startUDPListener() async {
    //udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort);
    udpSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      udpPort,
      reuseAddress: true,
      reusePort: true,
    );

// 🔥 ESTA LÍNEA ES CLAVE
    udpSocket!.broadcastEnabled = true;

    udpSocket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = udpSocket!.receive();
        final msg = utf8.decode(datagram!.data);

        if (msg == discoveryMsg) {
          final senderIP = datagram.address.address;

          _addSystem("📡 Peer encontrado: $senderIP");

          _connectToPeer(senderIP);
        }
      }
    });
  }
 */

  Future<void> _startUDPListener() async {
    udpSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      udpPort,
      reuseAddress: true,
      reusePort: true,
    );

    udpSocket!.broadcastEnabled = true; // 🔥 clave

    udpSocket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = udpSocket!.receive();
        final msg = utf8.decode(datagram!.data);

        if (msg == discoveryMsg) {
          final senderIP = datagram.address.address;
          _addSystem("📡 Peer encontrado: $senderIP");
          _connectToPeer(senderIP);
        }
      }
    });
  }

  void _broadcastDiscovery() async {
    final interfaces = await NetworkInterface.list();

    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 &&
            !addr.isLoopback &&
            !addr.address.startsWith("127")) {
          final ipParts = addr.address.split('.');
          if (ipParts.length != 4) continue;

          //final broadcast = "${ipParts[0]}.${ipParts[1]}.${ipParts[2]}.255";
          final broadcast = InternetAddress("255.255.255.255").toString();

          try {
            udpSocket?.send(
              utf8.encode(discoveryMsg),
              InternetAddress(broadcast),
              udpPort,
            );

            print("📡 Broadcast enviado a $broadcast");
          } catch (e) {
            print("❌ Error broadcast: $e");
          }
        }
      }
    }
  }

  Future<void> _startTCPServer() async {
    tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort);

    tcpServer!.listen((client) {
      tcpSocket = client;

      _addSystem("📲 Cliente conectado");

      client.listen((data) {
        _addMessage(false, String.fromCharCodes(data));
      });
    });
  }

  Future<void> _connectToPeer(String ip) async {
    if (tcpSocket != null) return;

    try {
      tcpSocket = await Socket.connect(ip, tcpPort);

      _addSystem("✅ Conectado a $ip");

      tcpSocket!.listen((data) {
        _addMessage(false, String.fromCharCodes(data));
      });
    } catch (e) {
      _addSystem("❌ Error conexión WiFi");
    }
  }

  // =========================
  // 💬 MENSAJES
  // =========================
  void _addMessage(bool mine, String text) {
    setState(() {
      messages.add(_Message(mine, text.trim()));
    });

    Future.delayed(Duration(milliseconds: 100), () {
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _addSystem(String text) {
    _addMessage(false, text);
  }

  void send() {
    final text = controller.text.trim();
    controller.clear();

    if (text.isEmpty) return;

    if (isWifiMode) {
      tcpSocket?.write(text);
    } else {
      connection?.output.add(Uint8List.fromList(utf8.encode(text + "\r\n")));
    }

    _addMessage(true, text);
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final name = widget.server.name ?? "Device";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isWifiMode ? "📡 WiFi Chat ($name)" : "🔵 Bluetooth Chat ($name)",
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];

                return Align(
                  alignment:
                      m.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.all(6),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: m.mine ? Colors.blueAccent : Colors.grey[700],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(child: TextField(controller: controller)),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: send,
              )
            ],
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    connection?.dispose();
    tcpSocket?.destroy();
    tcpServer?.close();
    udpSocket?.close();
    super.dispose();
  }
}
