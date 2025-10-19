import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_extra_model.dart';

final menuExtraProvider = StateNotifierProvider<MenuExtraNotifier, AsyncValue<List<MenuExtra>>>((ref) {
  return MenuExtraNotifier();
});

class MenuExtraNotifier extends StateNotifier<AsyncValue<List<MenuExtra>>> {
  MenuExtraNotifier() : super(const AsyncValue.loading()) {
    cargar();
  }

  Future<void> cargar() async {
    final data = await Supabase.instance.client.from('menu_extras').select();
    final list = (data as List).map((e) => MenuExtra.fromMap(e)).toList();
    state = AsyncValue.data(list);
  }

  Future<void> agregar(MenuExtra extra) async {
    await Supabase.instance.client.from('menu_extras').insert(extra.toMap());
    await cargar();
  }

  Future<void> eliminar(int id) async {
    await Supabase.instance.client.from('menu_extras').delete().eq('id', id);
    await cargar();
  }
}
