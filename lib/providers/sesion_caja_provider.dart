import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sesion_caja_model.dart';
import '../services/sesion_caja_service.dart';

final sesionCajaServiceProvider = Provider<SesionCajaService>((ref) {
  return SesionCajaService();
});

final sesionCajaAbiertaProvider = FutureProvider.family<SesionCaja?, String>((ref, usuarioId) async {
  final service = ref.watch(sesionCajaServiceProvider);
  return await service.obtenerSesionAbierta(usuarioId);
});
