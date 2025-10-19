import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/venta_model.dart';
import '../models/detalle_venta_model.dart';

class VentaService {
  final _supabase = Supabase.instance.client;

  Future<int> crearVenta(Venta venta) async {
    final res = await _supabase.from('ventas').insert(venta.toMap()).select().single();
    return res['id'];
  }

  Future<void> agregarDetalleVenta(List<VentaDetalle> detalles) async {
    final data = detalles.map((d) => d.toMap()).toList();
    await _supabase.from('ventas_detalle').insert(data);
  }

  Future<List<Venta>> obtenerVentas() async {
    final res = await _supabase.from('ventas').select().order('fecha', ascending: false);
    return (res as List).map((e) => Venta.fromMap(e)).toList();
  }

  Future<List<VentaDetalle>> obtenerDetallesPorVenta(int ventaId) async {
    final res = await _supabase
        .from('ventas_detalle')
        .select()
        .eq('venta_id', ventaId);

    return (res as List).map((e) => VentaDetalle.fromMap(e)).toList();
  }
}
