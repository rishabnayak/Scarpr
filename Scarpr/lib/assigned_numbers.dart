import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:grizzly_io/io_loader.dart';

Map<int,String> asgnVendor = {};
Map<int,String> asgnService = {};
Map<int,String> asgnCharacteristic = {};

Future<void> assignedNumbersLoad() async {
  for(List data in parseCsv(await rootBundle.loadString('assets/vendors.csv'))) {
    asgnVendor[int.parse(data[0])] = data[1];
  }

  for(List data in parseCsv(await rootBundle.loadString('assets/services.csv'))) {
    asgnService[int.parse(data[0])] = data[1];
  }

  for(List data in parseCsv(await rootBundle.loadString('assets/characteristics.csv'))) {
    asgnCharacteristic[int.parse(data[0])] = data[1];
  }
}

String vendorLookup(Uint8List data) {
  if(data != null) {
    final int id = data[0] + (data[1] << 8);
    if(asgnVendor.containsKey(id)) return asgnVendor[id];
  }
  return null;
}

String serviceLookup(String uuid) {
  RegExp pattern = new RegExp(r'^0000([0-9a-f]{4})-0000-1000-8000-00805f9b34fb$', caseSensitive: false);
  RegExpMatch match = pattern.firstMatch(uuid);
  if(match != null) {
    final int id = int.parse(match.group(1), radix: 16);
    if(asgnService.containsKey(id)) return asgnService[id];
  }
  return null;
}

String characteristicLookup(String uuid) {
  RegExp pattern = new RegExp(r'^0000([0-9a-f]{4})-0000-1000-8000-00805f9b34fb$', caseSensitive: false);
  RegExpMatch match = pattern.firstMatch(uuid);
  if(match != null) {
    final int id = int.parse(match.group(1), radix: 16);
    if(asgnCharacteristic.containsKey(id)) return asgnCharacteristic[id];
  }
  return null;
}
