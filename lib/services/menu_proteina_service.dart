import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_proteina_model.dart';

class MenuProteinaService {
  final _supabase = Supabase.instance.client;

  Future<List<MenuProteina>> obtener() async {
    final res = await _supabase
        .from('menu_proteinas')
        .select()
        .order('id', ascending: true);

    return (res as List).map((e) => MenuProteina.fromMap(e)).toList();
  }

  Future<void> agregar(MenuProteina p) async {
    await _supabase.from('menu_proteinas').insert(p.toMap());
  }

  Future<void> actualizar(MenuProteina p) async {
    await _supabase.from('menu_proteinas').update(p.toMap()).eq('id', p.id);
  }

  Future<void> eliminar(int id) async {
    await _supabase.from('menu_proteinas').delete().eq('id', id);
  }
}
