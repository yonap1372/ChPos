import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsuariosView extends StatefulWidget {
  const UsuariosView({super.key});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isEmpty) {
        setState(() => _filtered = List<Map<String, dynamic>>.from(_usuarios));
        return;
      }
      final next = _usuarios.where((u) {
        final nombre = (u['nombre'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final telefono = (u['telefono'] ?? '').toString().toLowerCase();
        final rol = (u['rol'] ?? '').toString().toLowerCase();
        final authUserId = (u['auth_user_id'] ?? '').toString().toLowerCase();
        return nombre.contains(q) ||
            email.contains(q) ||
            telefono.contains(q) ||
            rol.contains(q) ||
            authUserId.contains(q);
      }).toList();
      setState(() => _filtered = next);
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _shortDate(dynamic v) {
    if (v == null) return '-';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    final dl = d.toLocal();
    final y = dl.year.toString().padLeft(4, '0');
    final m = dl.month.toString().padLeft(2, '0');
    final day = dl.day.toString().padLeft(2, '0');
    final hh = dl.hour.toString().padLeft(2, '0');
    final mm = dl.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }

  Color _statusColor(bool activo, BuildContext context) {
    if (activo) return Colors.green;
    return Theme.of(context).colorScheme.error;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _error = 'No hay sesión activa';
          _loading = false;
        });
        return;
      }

      final res = await _client
          .from('usuarios')
          .select(
              'id, nombre, email, telefono, rol, activo, fecha_registro, ultima_conexion, auth_user_id')
          .order('fecha_registro', ascending: false)
          .limit(500);

      final list = List<Map<String, dynamic>>.from(res);

      if (!mounted) return;
      setState(() {
        _usuarios = list;
        _filtered = List<Map<String, dynamic>>.from(list);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 10),
          Flexible(child: Text(v, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Future<void> _openDetalle(Map<String, dynamic> u) async {
    final nombre = (u['nombre'] ?? '').toString().trim();
    final email = (u['email'] ?? '').toString().trim();
    final telefono = (u['telefono'] ?? '').toString().trim();
    final rol = (u['rol'] ?? '').toString().trim();
    final activo = (u['activo'] == true);
    final authUserId = (u['auth_user_id'] ?? '').toString().trim();
    final creado = _shortDate(u['fecha_registro']);
    final ultima = _shortDate(u['ultima_conexion']);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Detalle de usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _kv('Nombre', nombre.isEmpty ? '-' : nombre),
              _kv('Email', email.isEmpty ? '-' : email),
              _kv('Teléfono', telefono.isEmpty ? '-' : telefono),
              _kv('Rol', rol.isEmpty ? '-' : rol),
              _kv('Activo', activo ? 'Sí' : 'No'),
              _kv('Auth user', authUserId.isEmpty ? '-' : authUserId),
              _kv('Registro', creado),
              _kv('Última conexión', ultima),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ],
        );
      },
    );
  }

  Future<void> _crearUsuarioDialog() async {
    final nombreCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    String rol = 'empleado';
    bool activo = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Nuevo usuario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: telCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: rol,
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('admin')),
                        DropdownMenuItem(value: 'empleado', child: Text('empleado')),
                      ],
                      onChanged: (v) => setLocal(() => rol = v ?? 'empleado'),
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: activo,
                      onChanged: (v) => setLocal(() => activo = v),
                      title: const Text('Activo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear')),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final nombre = nombreCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final tel = telCtrl.text.trim();

    if (nombre.isEmpty) {
      _snack('Falta el nombre');
      return;
    }

    try {
      await _client.from('usuarios').insert({
        'nombre': nombre,
        'email': email.isEmpty ? null : email,
        'telefono': tel.isEmpty ? null : tel,
        'rol': rol,
        'activo': activo,
        'auth_user_id': _client.auth.currentUser?.id,
      });

      _snack('Usuario creado');
      await _load();
    } catch (e) {
      _snack('Error: $e');
    }
  }

  Future<void> _editarUsuarioDialog(Map<String, dynamic> u) async {
    final id = (u['id'] ?? '').toString();
    if (id.isEmpty) return;

    final nombreCtrl = TextEditingController(text: (u['nombre'] ?? '').toString());
    final emailCtrl = TextEditingController(text: (u['email'] ?? '').toString());
    final telCtrl = TextEditingController(text: (u['telefono'] ?? '').toString());

    String rol = (u['rol'] ?? 'empleado').toString();
    bool activo = (u['activo'] == true);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Editar usuario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: telCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: rol,
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('admin')),
                        DropdownMenuItem(value: 'empleado', child: Text('empleado')),
                      ],
                      onChanged: (v) => setLocal(() => rol = v ?? rol),
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: activo,
                      onChanged: (v) => setLocal(() => activo = v),
                      title: const Text('Activo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final nombre = nombreCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final tel = telCtrl.text.trim();

    if (nombre.isEmpty) {
      _snack('Falta el nombre');
      return;
    }

    try {
      await _client.from('usuarios').update({
        'nombre': nombre,
        'email': email.isEmpty ? null : email,
        'telefono': tel.isEmpty ? null : tel,
        'rol': rol,
        'activo': activo,
      }).eq('id', id);

      _snack('Usuario actualizado');
      await _load();
    } catch (e) {
      _snack('Error: $e');
    }
  }

  Future<void> _eliminarUsuario(Map<String, dynamic> u) async {
    final id = (u['id'] ?? '').toString();
    if (id.isEmpty) return;

    final nombre = (u['nombre'] ?? '').toString().trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar usuario'),
          content: Text('¿Eliminar ${nombre.isEmpty ? 'este usuario' : nombre}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await _client.from('usuarios').delete().eq('id', id);
      _snack('Usuario eliminado');
      await _load();
    } catch (e) {
      _snack('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _crearUsuarioDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gestión de usuarios', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar usuario...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _filtered.isEmpty
                            ? const Center(child: Text('Sin usuarios'))
                            : ListView.builder(
                                itemCount: _filtered.length,
                                itemBuilder: (context, i) {
                                  final u = _filtered[i];
                                  final nombre = (u['nombre'] ?? '').toString().trim();
                                  final email = (u['email'] ?? '').toString().trim();
                                  final rol = (u['rol'] ?? '').toString().trim();
                                  final activo = (u['activo'] == true);

                                  return Card(
                                    child: ListTile(
                                      onTap: () => _openDetalle(u),
                                      leading: CircleAvatar(
                                        backgroundColor: _statusColor(activo, context),
                                        child: const Icon(Icons.person, color: Colors.white),
                                      ),
                                      title: Text(nombre.isEmpty ? 'Sin nombre' : nombre),
                                      subtitle: Text(
                                        '${email.isEmpty ? '-' : email}  •  Rol: ${rol.isEmpty ? '-' : rol}',
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'edit') _editarUsuarioDialog(u);
                                          if (v == 'del') _eliminarUsuario(u);
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                                          PopupMenuItem(value: 'del', child: Text('Eliminar')),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
