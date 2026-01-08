// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/menu_categoria_provider.dart';
import '../../providers/menu_salsa_provider.dart';
import '../../providers/menu_proteina_provider.dart';
import '../../providers/menu_topping_provider.dart';

import '../../models/menu_categoria_model.dart';
import '../../models/menu_salsa_model.dart';
import '../../models/menu_proteina_model.dart';
import '../../models/menu_topping_model.dart';
import '../../providers/menu_especialidad_provider.dart';
import '../../providers/menu_extra_provider.dart';

import '../../models/menu_especialidad_model.dart';
import '../../models/menu_extra_model.dart';


class EditarMenuView extends ConsumerStatefulWidget {
  const EditarMenuView({super.key});

  @override
  ConsumerState<EditarMenuView> createState() => _EditarMenuViewState();
}

class _EditarMenuViewState extends ConsumerState<EditarMenuView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final especialidades = ref.watch(menuEspecialidadProvider);
    final extras = ref.watch(menuExtraProvider);
    final categorias = ref.watch(menuCategoriaProvider);
    final salsas = ref.watch(menuSalsaProvider);
    final proteinas = ref.watch(menuProteinaProvider);
    final toppings = ref.watch(menuToppingProvider);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: AppBar(
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text('Editar Menú — Chilascas',
              style: TextStyle(fontWeight: FontWeight.w700)),
          bottom: TabBar(
            controller: _tab,
            isScrollable: true,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(icon: Icon(Icons.category), text: 'Categorías base'),
              Tab(icon: Icon(Icons.local_fire_department), text: 'Salsas'),
              Tab(icon: Icon(Icons.restaurant), text: 'Proteínas'),
              Tab(icon: Icon(Icons.checklist), text: '¿Con todo?'),
              Tab(icon: Icon(Icons.star), text: 'Especialidades'),
              Tab(icon: Icon(Icons.add_circle_outline), text: 'Extras'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CategoriasTab(items: categorias, ref: ref),
          _SalsasTab(items: salsas, ref: ref),
          _ProteinasTab(items: proteinas, ref: ref),
          _ToppingsTab(items: toppings, ref: ref),
          _EspecialidadesTab(items: especialidades, ref: ref),
          _ExtrasTab(items: extras, ref: ref),
        ],
      ),
    );
  }
}

class _CategoriasTab extends StatelessWidget {
  final AsyncValue<List<MenuCategoria>> items;
  final WidgetRef ref;
  const _CategoriasTab({required this.items, required this.ref});

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      hint: 'Agrega, consulta o elimina categorías base con precio.',
      onAddPressed: () => _showAddCategoriaSheet(context, ref),
      child: items.when(
        data: (list) => _RefreshableList(
          onRefresh: () async {
              ref.invalidate(menuCategoriaProvider);
              await Future.delayed(const Duration(milliseconds: 150));
            },
          child: list.isEmpty
              ? const _EmptyState(
                  title: 'Sin categorías',
                  subtitle: 'Agrega tu primera categoría base con precio.',
                  icon: Icons.category_outlined,
                )
              : _CardList(
                  count: list.length,
                  itemBuilder: (context, index) {
                    final c = list[index];
                    return _AdminListTile(
                      leadingIcon: Icons.category_outlined,
                      title: c.nombre,
                      subtitle: 'Precio: \$${c.precio.toStringAsFixed(2)}',
                      onDelete: () async {
                        await ref.read(menuCategoriaProvider.notifier).eliminar(c.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Categoría eliminada')),
                        );
                      },
                      // onEdit: () => _showEditCategoriaSheet(context, ref, c), // si implementas actualizar(...)
                    );
                  },
                ),
        ),
        loading: () => const _Loading(),
        error: (e, _) => _ErrorBox(message: e.toString()),
      ),
    );
  }
}

Future<void> _showAddCategoriaSheet(BuildContext context, WidgetRef ref) async {
  final nombre = TextEditingController();
  final precio = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHeader(title: 'Agregar categoría'),
            TextField(
              controller: nombre,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.category_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: precio,
              decoration: const InputDecoration(
                labelText: 'Precio',
                prefixIcon: Icon(Icons.attach_money_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final n = nombre.text.trim();
                  final p = double.tryParse(precio.text.trim()) ?? 0;
                  if (n.isEmpty) return;
                  await ref.read(menuCategoriaProvider.notifier).agregar(
                        MenuCategoria(id: 0, nombre: n, precio: p),
                      );
                  if (context.mounted) Navigator.pop(ctx);
                },
                label: const Text('Agregar'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _SalsasTab extends StatelessWidget {
  final AsyncValue<List<MenuSalsa>> items;
  final WidgetRef ref;
  const _SalsasTab({required this.items, required this.ref});

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      hint: 'Administra las salsas disponibles.',
      onAddPressed: () => _showAddWithPriceSheet(
        context: context,
        title: 'Agregar salsa',
        icon: Icons.local_fire_department_outlined,
        onSave: (nombre, precio) => ref.read(menuSalsaProvider.notifier).agregar(
              MenuSalsa(id: 0, nombre: nombre),
            ),
      ),
      child: items.when(
        data: (list) => _RefreshableList(
          onRefresh: () async {
              ref.invalidate(menuCategoriaProvider);
              await Future.delayed(const Duration(milliseconds: 150));
            },
          child: list.isEmpty
              ? const _EmptyState(
                  title: 'Sin salsas',
                  subtitle: 'Agrega tus salsas para comenzar.',
                  icon: Icons.local_fire_department_outlined,
                )
              : _CardList(
                  count: list.length,
                  itemBuilder: (context, index) {
                    final s = list[index];
                    return _AdminListTile(
                      leadingIcon: Icons.local_fire_department_outlined,
                      title: s.nombre,
                      onDelete: () async {
                        await ref.read(menuSalsaProvider.notifier).eliminar(s.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Salsa eliminada')),
                        );
                      },
                      // onEdit: () => _showEditSimpleSheet(context, 'Editar salsa', s.nombre, (nuevoNombre) => ...)
                    );
                  },
                ),
        ),
        loading: () => const _Loading(),
        error: (e, _) => _ErrorBox(message: e.toString()),
      ),
    );
  }
}

class _ProteinasTab extends StatelessWidget {
  final AsyncValue<List<MenuProteina>> items;
  final WidgetRef ref;
  const _ProteinasTab({required this.items, required this.ref});

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      hint: 'Configura proteínas opcionales.',
      onAddPressed: () => _showAddSimpleSheet(
        context: context,
        title: 'Agregar proteína',
        icon: Icons.restaurant_outlined,
        onSave: (nombre) => ref.read(menuProteinaProvider.notifier).agregar(
              MenuProteina(id: 0, nombre: nombre),
            ),
      ),
      child: items.when(
        data: (list) => _RefreshableList(
          onRefresh: () async {
              ref.invalidate(menuCategoriaProvider);
              await Future.delayed(const Duration(milliseconds: 150));
            },
          child: list.isEmpty
              ? const _EmptyState(
                  title: 'Sin proteínas',
                  subtitle: 'Agrega proteínas para completar el menú.',
                  icon: Icons.restaurant_outlined,
                )
              : _CardList(
                  count: list.length,
                  itemBuilder: (context, index) {
                    final p = list[index];
                    return _AdminListTile(
                      leadingIcon: Icons.restaurant_outlined,
                      title: p.nombre,
                      onDelete: () async {
                        await ref.read(menuProteinaProvider.notifier).eliminar(p.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Proteína eliminada')),
                        );
                      },
                    );
                  },
                ),
        ),
        loading: () => const _Loading(),
        error: (e, _) => _ErrorBox(message: e.toString()),
      ),
    );
  }
}

// ===========================
// Sección: Toppings (¿Con todo?)
// ===========================
class _ToppingsTab extends StatelessWidget {
  final AsyncValue<List<MenuTopping>> items;
  final WidgetRef ref;
  const _ToppingsTab({required this.items, required this.ref});

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      hint: 'Queso, crema, cebolla, cilantro… administra tus toppings.',
      onAddPressed: () => _showAddSimpleSheet(
        context: context,
        title: 'Agregar topping',
        icon: Icons.checklist_outlined,
        onSave: (nombre) => ref.read(menuToppingProvider.notifier).agregar(
              MenuTopping(id: 0, nombre: nombre),
            ),
      ),
      child: items.when(
        data: (list) => _RefreshableList(
          onRefresh: () async {
              ref.invalidate(menuCategoriaProvider);
              await Future.delayed(const Duration(milliseconds: 150));
            },
          child: list.isEmpty
              ? const _EmptyState(
                  title: 'Sin toppings',
                  subtitle: 'Agrega tus toppings disponibles.',
                  icon: Icons.checklist_outlined,
                )
              : _CardList(
                  count: list.length,
                  itemBuilder: (context, index) {
                    final t = list[index];
                    return _AdminListTile(
                      leadingIcon: Icons.checklist_outlined,
                      title: t.nombre,
                      onDelete: () async {
                        await ref.read(menuToppingProvider.notifier).eliminar(t.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Topping eliminado')),
                        );
                      },
                    );
                  },
                ),
        ),
        loading: () => const _Loading(),
        error: (e, _) => _ErrorBox(message: e.toString()),
      ),
    );
  }
}

// ===========================
// Sección: Especialidades
// ===========================
class _EspecialidadesTab extends StatelessWidget {
  final AsyncValue<List<MenuEspecialidad>> items;
  final WidgetRef ref;
  const _EspecialidadesTab({required this.items, required this.ref});

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      hint: 'Agrega especialidades como Arrachera o Chicharrón prensado con precio.',
      onAddPressed: () => _showAddWithPriceSheet(
        context: context,
        title: 'Agregar especialidad',
        icon: Icons.star_outline,
        onSave: (nombre, precio) => ref.read(menuEspecialidadProvider.notifier).agregar(
              MenuEspecialidad(id: 0, nombre: nombre, precio: precio),
            ),
      ),
      child: items.when(
        data: (list) => _RefreshableList(
          onRefresh: () async {
            ref.invalidate(menuEspecialidadProvider);
            await Future.delayed(const Duration(milliseconds: 150));
          },
          child: list.isEmpty
              ? const _EmptyState(
                  title: 'Sin especialidades',
                  subtitle: 'Agrega Arrachera, Chicharrón prensado, etc.',
                  icon: Icons.star_outline,
                )
              : _CardList(
                  count: list.length,
                  itemBuilder: (context, index) {
                    final e = list[index];
                    return _AdminListTile(
                      leadingIcon: Icons.star,
                      title: e.nombre,
                      subtitle: 'Precio: \$${e.precio.toStringAsFixed(2)}',
                      onDelete: () async {
                        await ref.read(menuEspecialidadProvider.notifier).eliminar(e.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Especialidad eliminada')),
                        );
                      },
                    );
                  },
                ),
        ),
        loading: () => const _Loading(),
        error: (e, _) => _ErrorBox(message: e.toString()),
      ),
    );
  }
}

// ===========================
// Sección: Extras
// ===========================
class _ExtrasTab extends StatelessWidget {
  final AsyncValue<List<MenuExtra>> items;
  final WidgetRef ref;
  const _ExtrasTab({required this.items, required this.ref});

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      hint: 'Agrega extras como Pollo extra, Huevo extra, Queso, Crema… con precio.',
      onAddPressed: () => _showAddWithPriceSheet(
        context: context,
        title: 'Agregar extra',
        icon: Icons.add_circle_outline,
        onSave: (nombre, precio) => ref.read(menuExtraProvider.notifier).agregar(
              MenuExtra(id: 0, nombre: nombre, precio: precio),
            ),
      ),
      child: items.when(
        data: (list) => _RefreshableList(
          onRefresh: () async {
            ref.invalidate(menuExtraProvider);
            await Future.delayed(const Duration(milliseconds: 150));
          },
          child: list.isEmpty
              ? const _EmptyState(
                  title: 'Sin extras',
                  subtitle: 'Agrega pollo extra, huevo extra, queso, crema, etc.',
                  icon: Icons.add_circle_outline,
                )
              : _CardList(
                  count: list.length,
                  itemBuilder: (context, index) {
                    final ex = list[index];
                    return _AdminListTile(
                      leadingIcon: Icons.add_circle_outline,
                      title: ex.nombre,
                      subtitle: 'Precio: \$${ex.precio.toStringAsFixed(2)}',
                      onDelete: () async {
                        await ref.read(menuExtraProvider.notifier).eliminar(ex.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Extra eliminado')),
                        );
                      },
                    );
                  },
                ),
        ),
        loading: () => const _Loading(),
        error: (e, _) => _ErrorBox(message: e.toString()),
      ),
    );
  }
}


// ===========================
// Widgets de UI reutilizables
// ===========================
class _SectionScaffold extends StatelessWidget {
  final Widget child;
  final String hint;
  final VoidCallback onAddPressed;

  const _SectionScaffold({
    required this.child,
    required this.hint,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHint(hint: hint),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton.extended(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add),
            label: const Text('Agregar'),
          ),
        ),
      ],
    );
  }
}

class _SectionHint extends StatelessWidget {
  final String hint;
  const _SectionHint({required this.hint});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cs.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(color: cs.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardList extends StatelessWidget {
  final int count;
  final Widget Function(BuildContext, int) itemBuilder;

  const _CardList({required this.count, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ListHeader(count: count),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}

class _ListHeader extends StatelessWidget {
  final int count;
  const _ListHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        const Text('Registros',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count', style: TextStyle(color: cs.onSecondaryContainer)),
        ),
        const Spacer(),
        // Espacio para futuro: buscador / ordenar
      ],
    );
  }
}

class _AdminListTile extends StatelessWidget {
  final IconData leadingIcon;
  final String title;
  final String? subtitle;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const _AdminListTile({
    required this.leadingIcon,
    required this.title,
    this.subtitle,
    required this.onDelete,
    // ignore: unused_element_parameter
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.secondaryContainer,
          child: Icon(leadingIcon, color: cs.onSecondaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: cs.primaryContainer,
            child: Icon(icon, color: cs.onPrimaryContainer, size: 28),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Error: $message', style: const TextStyle(color: Colors.red)),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  const _SheetHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RefreshableList extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  const _RefreshableList({required this.child, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }
}


Future<void> _showAddWithPriceSheet<T>({
  required BuildContext context,
  required String title,
  required IconData icon,
  required Future<void> Function(String nombre, double precio) onSave,
}) async {
  final nombreCtrl = TextEditingController();
  final precioCtrl = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(title: title),
            TextField(
              controller: nombreCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(icon),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: precioCtrl,
              decoration: const InputDecoration(
                labelText: 'Precio',
                prefixIcon: Icon(Icons.attach_money_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final n = nombreCtrl.text.trim();
                  final p = double.tryParse(precioCtrl.text.trim()) ?? 0;
                  if (n.isEmpty) return;
                  await onSave(n, p);
                  if (context.mounted) Navigator.pop(ctx);
                },
                label: const Text('Agregar'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showAddSimpleSheet({
  required BuildContext context,
  required String title,
  required IconData icon,
  required Future<void> Function(String nombre) onSave,
}) async {
  final nombreCtrl = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(title: title),
            TextField(
              controller: nombreCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(icon),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final n = nombreCtrl.text.trim();
                  if (n.isEmpty) return;
                  await onSave(n);
                  if (context.mounted) Navigator.pop(ctx);
                },
                label: const Text('Agregar'),
              ),
            ),
          ],
        ),
      );
    },
  );
}