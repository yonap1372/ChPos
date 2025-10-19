import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_categoria_model.dart';

class MenuCategoriaService {
  final _supabase = Supabase.instance.client;

  Future<List<MenuCategoria>> obtener() async {
    final res = await _supabase
        .from('menu_categorias_base')
        .select()
        .order('id', ascending: true);

    return (res as List).map((e) => MenuCategoria.fromMap(e)).toList();
  }

  Future<void> agregar(MenuCategoria c) async {
    await _supabase.from('menu_categorias_base').insert(c.toMap());
  }

  Future<void> actualizar(MenuCategoria c) async {
    await _supabase
        .from('menu_categorias_base')
        .update(c.toMap())
        .eq('id', c.id);
  }

  Future<void> eliminar(int id) async {
    await _supabase
        .from('menu_categorias_base')
        .delete()
        .eq('id', id);
  }
}
