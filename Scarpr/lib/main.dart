import 'dart:async';
import 'dart:io';
import 'package:circle_wave_progress/circle_wave_progress.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:location/location.dart';
import 'chr_page.dart';
import 'assigned_numbers.dart';
import 'widgets.dart';

enum Connection { connecting, discovering }

class BleDevice {
  ScanResult result;
  DateTime when;
  BleDevice(this.result, this.when);
}

void main() => runApp(App());

class App extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scarpr',
      home: Main(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/chr': (BuildContext context) => ChrPage(),
      },
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[200],
        textTheme: TextTheme(
          button: TextStyle(fontSize: 15, color: Colors.white),
        ),
        cardTheme: CardTheme(color: Colors.white),
        buttonTheme: ButtonThemeData(
          height: 40,
          minWidth: 100,
          buttonColor: Colors.indigo[400],
        ),
      ),
    );
  }
}

class Main extends StatefulWidget {
  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> with WidgetsBindingObserver {
  BleManager _bleManager = BleManager();
  List<BleDevice> _devices = [];
  Connection _connection;
  StreamSubscription<PeripheralConnectionState> _connSub;
  Timer _cleanupTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (ModalRoute.of(context).isCurrent) {
      switch (state) {
        case AppLifecycleState.paused:
          _stopScan();
          break;
        case AppLifecycleState.resumed:
          _startScan();
          break;
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
      }
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    initStateAsync();
    super.initState();
  }

  Future<void> initStateAsync() async {
    await assignedNumbersLoad();
    await _bleManager.createClient();
    _bleManager.setLogLevel(LogLevel.verbose);
    _startScan();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopScan();
    _bleManager.destroyClient();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (Platform.isAndroid) {
      if (await _bleManager.bluetoothState() == BluetoothState.POWERED_OFF) {
        await _bleManager.enableRadio();
      }

      AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 23) {
        Location location = Location();
        while (await location.hasPermission() != PermissionStatus.granted) {
          await location.requestPermission();
        }
        if (!await location.serviceEnabled()) {
          await location.requestService();
        }
      }

      _cleanupTimer = Timer.periodic(Duration(seconds: 2), _cleanup);
    }

    _bleManager
        .startPeripheralScan(scanMode: ScanMode.balanced)
        .listen((ScanResult result) {
      if (result.peripheral.name == 'WiFi Sniffer' ||
          result.peripheral.name == 'raspberrypi') {
        BleDevice device = BleDevice(result, DateTime.now());
        int index = _devices.indexWhere((dynamic _device) =>
            _device.result.peripheral.identifier ==
            device.result.peripheral.identifier);
        setState(() {
          if (index < 0)
            _devices.add(device);
          else
            _devices[index] = device;
        });
      }
    });
  }

  void _cleanup(Timer timer) {
    DateTime limit = DateTime.now().subtract(Duration(seconds: 5));
    for (int i = _devices.length - 1; i >= 0; i--) {
      if (_devices[i].when.isBefore(limit))
        setState(() => _devices.removeAt(i));
    }
  }

  Future<void> _stopScan() async {
    _cleanupTimer?.cancel();
    await _bleManager.stopPeripheralScan();
    setState(() => _devices.clear());
  }

  Future<void> _restartScan() async {
    if (Platform.isAndroid) {
      setState(() => _devices.clear());
    } else {
      await _stopScan();
      _startScan();
    }
  }

  Future<void> _gotoDevice(int index) async {
    ScanResult result = _devices[index].result;
    _stopScan();

    try {
      setState(() => _connection = Connection.connecting);
      await result.peripheral
          .connect(refreshGatt: true, timeout: Duration(seconds: 15));
      _connSub = result.peripheral
          .observeConnectionState(completeOnDisconnect: true)
          .listen((PeripheralConnectionState state) {
        if (state == PeripheralConnectionState.disconnected) {
          Navigator.popUntil(context, ModalRoute.withName('/'));
        }
      });
      await result.peripheral.requestMtu(251);

      setState(() => _connection = Connection.discovering);
      await result.peripheral.discoverAllServicesAndCharacteristics();

      for (Service service in await result.peripheral.services()) {
        if (service.uuid.contains('181a')) {
          for (Characteristic characteristic
              in await service.characteristics()) {
            if (characteristic.uuid.contains('2a3d')) {
              Navigator.pushNamed(context, '/chr',
                  arguments: [result, characteristic]).whenComplete(() async {
                _connSub?.cancel();
                if (await result.peripheral.isConnected()) {
                  result.peripheral.disconnectOrCancelConnection();
                }
                setState(() => _connection = null);
                _startScan();
              });
            }
          }
        }
      }
    } on BleError {
      _connSub?.cancel();
      setState(() => _connection = null);
      _startScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scarpr'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _connection == null ? _restartScan : null,
          )
        ],
      ),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    if (_connection != null) {
      switch (_connection) {
        case Connection.connecting:
          return loader('Connecting ...', 'Wait while connecting');
        case Connection.discovering:
          return loader('Connecting ...', 'Wait while discovering services');
      }
    }
    if (_devices.length == 0) return buildIntro();
    return buildList();
  }

  Widget buildIntro() {
    final screen = MediaQuery.of(context).size;

    return Column(
      children: [
        Stack(
          children: [
            Material(
              child: CircleWaveProgress(
                size: screen.width * .80,
                borderWidth: 10.0,
                backgroundColor: Colors.transparent,
                borderColor: Colors.white,
                waveColor: Colors.white70,
                progress: 50,
              ),
              elevation: 3,
              color: Colors.grey[200],
              shape: CircleBorder(),
            ),
            Opacity(
              child: Padding(
                child: Icon(
                  Icons.bluetooth_searching,
                  color: Colors.indigo,
                  size: screen.width / 2,
                ),
                padding: EdgeInsets.only(left: screen.width / 14),
              ),
              opacity: .90,
            ),
          ],
          alignment: AlignmentDirectional.center,
        ),
        Text(
          'No WiFi Sniffer found',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w500),
        ),
        Padding(
          child: Text(
            'To rescan, press the refresh button on the top left.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.4),
          ),
          padding: EdgeInsets.only(bottom: screen.height * .02),
        ),
      ],
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.stretch,
    );
  }

  Widget buildList() {
    return RefreshIndicator(
      child: ListView.separated(
        itemCount: _devices.length + 1,
        itemBuilder: buildListItem,
        separatorBuilder: (BuildContext context, int index) =>
            Divider(height: 0),
      ),
      onRefresh: _restartScan,
    );
  }

  Widget buildListItem(BuildContext context, int index) {
    if (index == 0) return infobar(context, 'BLE devices');

    ScanResult result = _devices[index - 1].result;
    String vendor = vendorLookup(result.advertisementData.manufacturerData);
    vendor = vendor != null ? '\n' + vendor : '';

    return Card(
      child: ListTile(
        leading: Column(
          children: [Text('${result.rssi.toString()} dB')],
          mainAxisAlignment: MainAxisAlignment.center,
        ),
        title: result.peripheral.name != null
            ? Text(result.peripheral.name)
            : Text('Unnamed',
                style: TextStyle(
                    color: Theme.of(context).textTheme.caption.color)),
        subtitle: Text(result.peripheral.identifier + vendor,
            style: TextStyle(height: 1.35)),
        trailing: Column(
          children: [Icon(Icons.chevron_right)],
          mainAxisAlignment: MainAxisAlignment.center,
        ),
        isThreeLine: vendor.length > 0,
        onTap: () => _gotoDevice(index - 1),
      ),
      margin: EdgeInsets.all(0),
      shape: RoundedRectangleBorder(),
    );
  }
}
