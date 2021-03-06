import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'assigned_numbers.dart';

class ChrPage extends StatefulWidget {
  @override
  _ChrPageState createState() => _ChrPageState();
}

class _ChrPageState extends State<ChrPage> {
  ScanResult _result;
  Characteristic _chr;
  StreamSubscription<Uint8List> _notifySub;
  HashMap deviceData = new HashMap<String, double>();
  TextEditingController _notifyCtrl = TextEditingController();
  double rssiHighThreshold = -20;
  double rssiLowThreshold = -95;
  double txPower = -20;
  int numPeopleAround = 0;

  @override
  Future<void> didChangeDependencies() async {
    if (_result == null || _chr == null) {
      List args = ModalRoute.of(context).settings.arguments;
      _result = args[0];
      _chr = args[1];

      setState(() {});
    }
    super.didChangeDependencies();
  }

  @override
  Future<void> dispose() async {
    _notifySub?.cancel();
    super.dispose();
  }

  void _onNotify() async {
    if (_notifySub == null) {
      _notifySub = _chr.monitor().listen((Uint8List data) {
        String macAddress = String.fromCharCodes(data).split(",")[0];
        double rssi = double.tryParse(String.fromCharCodes(data).split(",")[1]);
        if (rssi < rssiHighThreshold && rssi > rssiLowThreshold) {
          if (!deviceData.containsKey(macAddress)) {
            numPeopleAround++;
            setState(() => _notifyCtrl.text = numPeopleAround.toString());
          }
          double distance = pow(10, ((txPower - rssi) / (10 * 2)));
          deviceData[macAddress] = double.tryParse(distance.toStringAsFixed(2));
          setState(() {});
        }
      });
    } else {
      await _notifySub.cancel();
      setState(() => _notifySub = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_result.peripheral.name ?? _result.peripheral.identifier),
      ),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    String service = serviceLookup(_chr.service.uuid);
    service = service != null ? '\n' + service : '';
    String characteristic = characteristicLookup(_chr.uuid);
    characteristic = characteristic != null ? '\n' + characteristic : '';

    return Column(children: [buildNotify(), buildTable()]);
  }

  Widget buildNotify() {
    return Card(
      child: Padding(
        child: Row(
          children: [
            RaisedButton(
              child: _notifySub != null
                  ? new Text('Unsubscribe')
                  : new Text('Subscribe'),
              textColor: Theme.of(context).textTheme.button.color,
              color: _notifySub != null ? Colors.red[400] : Colors.green[400],
              onPressed: _onNotify,
            ),
            SizedBox(width: 12),
            Expanded(
                child: TextField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'People Around',
              ),
              controller: _notifyCtrl,
              readOnly: true,
              style: TextStyle(fontFamily: 'monospace'),
            )),
          ],
        ),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      margin: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    );
  }

  Widget buildTable() {
    return new ListView.builder(
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      itemCount: deviceData.length,
      itemBuilder: (BuildContext context, int index) {
        String key = deviceData.keys.elementAt(index);
        return new Column(
          children: <Widget>[
            new ListTile(
              title: new Text("$key"),
              subtitle: new Text("${deviceData[key]}"),
            ),
            new Divider(
              height: 2.0,
            ),
          ],
        );
      },
    );
  }
}
