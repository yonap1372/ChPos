import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reporte_models.dart';

class ReporteService {
  final supabase = Supabase.instance.client;

  Future<List<ResumenPunto>> resumen({
    required DateTime desde,
    required DateTime hasta,
    required String group,          // 'day' | 'week' | 'month'
    String? usuarioId,
  }) async {
    final resp = await supabase.rpc('reporte_resumen', params: {
      'p_desde': desde.toIso8601String(),
      'p_hasta': hasta.toIso8601String(),
      'p_group': group,
      'p_usuario': usuarioId,
    });
    final data = (resp as List).cast<Map<String, dynamic>>();
    return data.map((m) => ResumenPunto.fromMap(m)).toList();
  }

  Future<Breakdowns> breakdowns({
    required DateTime desde,
    required DateTime hasta,
    String? usuarioId,
  }) async {
    final resp = await supabase.rpc('reporte_breakdowns', params: {
      'p_desde': desde.toIso8601String(),
      'p_hasta': hasta.toIso8601String(),
      'p_usuario': usuarioId,
    });
    return Breakdowns.fromJson((resp as Map<String, dynamic>));
  }

  Future<List<SesionCajaResumen>> sesionesCaja({
    required DateTime desde,
    required DateTime hasta,
    String? usuarioId,
  }) async {
    final resp = await supabase.rpc('reporte_sesiones_caja', params: {
      'p_desde': desde.toIso8601String(),
      'p_hasta': hasta.toIso8601String(),
      'p_usuario': usuarioId,
    });
    final data = (resp as List).cast<Map<String, dynamic>>();
    return data.map((m) => SesionCajaResumen.fromMap(m)).toList();
  }
}
