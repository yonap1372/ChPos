import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_proteina_model.dart';
import '../services/menu_proteina_service.dart';


final menuProteinaProvider = StateNotifierProvider<MenuProteinaNotifier, AsyncValue<List<MenuProteina>>>(
(ref) => MenuProteinaNotifier(),
);


class MenuProteinaNotifier extends StateNotifier<AsyncValue<List<MenuProteina>>> {
final MenuProteinaService _service = MenuProteinaService();


MenuProteinaNotifier() : super(const AsyncLoading()) {
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


Future<void> agregar(MenuProteina p) async {
await _service.agregar(p);
await cargar();
}


Future<void> eliminar(int id) async {
await _service.eliminar(id);
await cargar();
}
}