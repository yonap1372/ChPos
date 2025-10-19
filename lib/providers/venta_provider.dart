import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/venta_model.dart';
import '../services/venta_service.dart';

final ventaServiceProvider = Provider<VentaService>((ref) {
  return VentaService();
});

final ventasProvider = FutureProvider<List<Venta>>((ref) async {
  final service = ref.watch(ventaServiceProvider);
  return await service.obtenerVentas();
});

final ventaProvider = Provider<VentaService>((ref) {
  return VentaService();
});
