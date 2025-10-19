import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_salsa_model.dart';

class MenuSalsaService {
  final _supabase = Supabase.instance.client;

  Future<List<MenuSalsa>> obtener() async {
    final res = await _supabase
        .from('menu_salsas')
        .select()
        .order('id', ascending: true);

    return (res as List).map((e) => MenuSalsa.fromMap(e)).toList();
  }

  Future<void> agregar(MenuSalsa s) async {
    await _supabase.from('menu_salsas').insert(s.toMap());
  }

  Future<void> actualizar(MenuSalsa s) async {
    await _supabase.from('menu_salsas').update(s.toMap()).eq('id', s.id);
  }

  Future<void> eliminar(int id) async {
    await _supabase.from('menu_salsas').delete().eq('id', id);
  }
}
