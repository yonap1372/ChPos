import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_topping_model.dart';

class MenuToppingService {
  final _supabase = Supabase.instance.client;

  Future<List<MenuTopping>> obtener() async {
    final res = await _supabase
        .from('menu_toppings')
        .select()
        .order('id', ascending: true);

    return (res as List).map((e) => MenuTopping.fromMap(e)).toList();
  }

  Future<void> agregar(MenuTopping t) async {
    await _supabase.from('menu_toppings').insert(t.toMap());
  }

  Future<void> actualizar(MenuTopping t) async {
    await _supabase.from('menu_toppings').update(t.toMap()).eq('id', t.id);
  }

  Future<void> eliminar(int id) async {
    await _supabase.from('menu_toppings').delete().eq('id', id);
  }
}
