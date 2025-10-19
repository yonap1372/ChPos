import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_salsa_model.dart';
import '../services/menu_salsa_service.dart';


final menuSalsaProvider = StateNotifierProvider<MenuSalsaNotifier, AsyncValue<List<MenuSalsa>>>(
(ref) => MenuSalsaNotifier(),
);


class MenuSalsaNotifier extends StateNotifier<AsyncValue<List<MenuSalsa>>> {
final MenuSalsaService _service = MenuSalsaService();


MenuSalsaNotifier() : super(const AsyncLoading()) {
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


Future<void> agregar(MenuSalsa s) async {
await _service.agregar(s);
await cargar();
}


Future<void> eliminar(int id) async {
await _service.eliminar(id);
await cargar();
}
}

