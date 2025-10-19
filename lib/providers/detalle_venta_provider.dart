import 'package:chilascas_pos/providers/venta_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/detalle_venta_model.dart';

final detalleVentaProvider = FutureProvider.family<List<VentaDetalle>, int>((ref, ventaId) async {
  final service = ref.watch(ventaServiceProvider);
  return await service.obtenerDetallesPorVenta(ventaId);
});
