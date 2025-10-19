// ignore_for_file: avoid_print

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PosPrinterService {
  static const platform = MethodChannel('chilascas/usb_printer');

  static Future<void> printTicket(String data, {required String printer}) async {
    try {
      await platform.invokeMethod('printTicket', {
        "data": data,
        "printer": printer,
      });
    } on PlatformException catch (e) {
      print("Error imprimiendo: ${e.message}");
    }
  }

  static Future<void> openCashDrawer() async {
    try {
      await platform.invokeMethod('openDrawer');
    } on PlatformException catch (e) {
      print("Error abriendo cajón: ${e.message}");
    }
  }

  static Future<void> savePrinterSerial(String type, String serial) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("printer_$type", serial);
  }

  static Future<String?> getPrinterSerial(String type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("printer_$type");
  }
}
