import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_topping_model.dart';
import '../services/menu_topping_service.dart';


final menuToppingProvider = StateNotifierProvider<MenuToppingNotifier, AsyncValue<List<MenuTopping>>>(
(ref) => MenuToppingNotifier(),
);


class MenuToppingNotifier extends StateNotifier<AsyncValue<List<MenuTopping>>> {
final MenuToppingService _service = MenuToppingService();


MenuToppingNotifier() : super(const AsyncLoading()) {
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


Future<void> agregar(MenuTopping t) async {
await _service.agregar(t);
await cargar();
}


Future<void> eliminar(int id) async {
await _service.eliminar(id);
await cargar();
}
}