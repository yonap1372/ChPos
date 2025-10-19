import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sesion_caja_model.dart';

class SesionCajaService {
  final _supabase = Supabase.instance.client;

  Future<SesionCaja?> obtenerSesionAbierta(String usuarioId) async {
    final res = await _supabase
        .from('sesiones_caja')
        .select()
        .eq('usuario_id', usuarioId)
        .eq('cerrada', false)
        .maybeSingle();

    return res == null ? null : SesionCaja.fromMap(res);
  }
  
  Future<void> abrirCaja(SesionCaja sesion) async {
    await _supabase.from('sesiones_caja').insert(sesion.toMap());
  }

  Future<void> cerrarCaja(int sesionId, double total) async {
    await _supabase.from('sesiones_caja').update({
      'cerrada': true,
      'total': total,
      'hora_cierre': DateTime.now().toIso8601String(),
    }).eq('id', sesionId);
  }

  Future<List<SesionCaja>> obtenerHistorialSesiones(String usuarioId) async {
    final res = await _supabase
        .from('sesiones_caja')
        .select()
        .eq('usuario_id', usuarioId)
        .order('hora_apertura', ascending: false);

    return (res as List).map((e) => SesionCaja.fromMap(e)).toList();
  }

  Future<void> abrirSesion(int usuarioId, double monto) async {
    final sesion = SesionCaja(
      id: 0,
      usuarioId: usuarioId,
      apertura: DateTime.now(),
      montoInicial: monto,
      cierre: null,
      montoFinal: null,
      activa: true,
    );

    await abrirCaja(sesion);
  }
}
