import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_especialidad_model.dart';

final menuEspecialidadProvider = StateNotifierProvider<MenuEspecialidadNotifier, AsyncValue<List<MenuEspecialidad>>>((ref) {
  return MenuEspecialidadNotifier();
});

class MenuEspecialidadNotifier extends StateNotifier<AsyncValue<List<MenuEspecialidad>>> {
  MenuEspecialidadNotifier() : super(const AsyncValue.loading()) {
    cargar();
  }

  Future<void> cargar() async {
    final data = await Supabase.instance.client.from('menu_especialidades').select();
    final list = (data as List).map((e) => MenuEspecialidad.fromMap(e)).toList();
    state = AsyncValue.data(list);
  }

  Future<void> agregar(MenuEspecialidad especialidad) async {
    await Supabase.instance.client.from('menu_especialidades').insert(especialidad.toMap());
    await cargar();
  }

  Future<void> eliminar(int id) async {
    await Supabase.instance.client.from('menu_especialidades').delete().eq('id', id);
    await cargar();
  }
}
