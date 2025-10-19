import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_categoria_model.dart';
import '../services/menu_categoria_service.dart';


final menuCategoriaProvider = StateNotifierProvider<MenuCategoriaNotifier, AsyncValue<List<MenuCategoria>>>(
(ref) => MenuCategoriaNotifier(),
);


class MenuCategoriaNotifier extends StateNotifier<AsyncValue<List<MenuCategoria>>> {
final MenuCategoriaService _service = MenuCategoriaService();


MenuCategoriaNotifier() : super(const AsyncLoading()) {
cargar();
}


Future<void> cargar() async {
try {
final data = await _service.obtener();
state = AsyncData(data);
} catch (e, st) {
state = AsyncError(e, st);
}
}


Future<void> agregar(MenuCategoria c) async {
await _service.agregar(c);
await cargar();
}


Future<void> eliminar(int id) async {
await _service.eliminar(id);
await cargar();
}
}