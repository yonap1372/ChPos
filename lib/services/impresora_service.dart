// ignore_for_file: avoid_print

import 'package:flutter/services.dart';

const platform = MethodChannel("chilascas/usb_printer");

Future<bool> imprimirTicket(String ticket, {String tipo = 'cliente'}) async {
  try {
    final result = await platform.invokeMethod('printTicket', {
      'data': ticket,
      'tipo': tipo,
    });
    print('✅ Ticket enviado a $tipo: $result');
    return true;
  } on PlatformException catch (e) {
    print('❌ Error al imprimir en $tipo: ${e.message}');
    return false;
  } catch (e) {
    print('⚠️ Error inesperado al imprimir en $tipo: $e');
    return false;
  }
}

Future<bool> abrirCajon() async {
  try {
    final result = await platform.invokeMethod('openDrawer');
    print('✅ Cajón abierto correctamente: $result');
    return true;
  } on PlatformException catch (e) {
    print('❌ Error al abrir cajón: ${e.message}');
    return false;
  } catch (e) {
    print('⚠️ Error inesperado al abrir cajón: $e');
    return false;
  }
}

Future<List<Map<String, dynamic>>> listarImpresoras() async {
  try {
    final result = await platform.invokeMethod('listarImpresoras');
    if (result is List) {
      final impresoras = result
          .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(Map<String, dynamic>.from(e)))
          .toList();
      print('🖨️ Impresoras detectadas: $impresoras');
      return impresoras;
    } else {
      print('⚠️ No se obtuvo una lista válida de impresoras');
      return [];
    }
  } on PlatformException catch (e) {
    print('❌ Error al listar impresoras: ${e.message}');
    return [];
  } catch (e) {
    print('⚠️ Error inesperado al listar impresoras: $e');
    return [];
  }
}

Future<bool> guardarAsignacion(String tipo, String serial) async {
  try {
    await platform.invokeMethod('guardarAsignacion', {
      'tipo': tipo,
      'serial': serial,
    });
    print('💾 Asignación guardada: $tipo → $serial');
    return true;
  } on PlatformException catch (e) {
    print('❌ Error al guardar asignación: ${e.message}');
    return false;
  } catch (e) {
    print('⚠️ Error inesperado al guardar asignación: $e');
    return false;
  }
}
