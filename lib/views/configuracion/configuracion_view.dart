import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConfiguracionView extends StatefulWidget {
  const ConfiguracionView({super.key});

  @override
  State<ConfiguracionView> createState() => _ConfiguracionViewState();
}

class _ConfiguracionViewState extends State<ConfiguracionView> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _me;
  bool _isAdmin = false;

  bool _pushNotifs = true;
  bool _sonido = true;
  bool _vibracion = true;
  bool _confirmaciones = true;
  bool _compactMode = false;

  String _negocioNombre = 'Las Chilascas';
  String _negocioTelefono = '';
  String _negocioDireccion = '';
  String _negocioHorario = '';

  Timer? _debounceSave;
  bool _saving = false;
  DateTime? _lastSavedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounceSave?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final u = _client.auth.currentUser;
      if (u == null) {
        if (!mounted) return;
        setState(() {
          _error = 'No hay sesión activa';
          _loading = false;
        });
        return;
      }

      final meRes = await _client
          .from('usuarios')
          .select('id, nombre, email, telefono, rol, activo, auth_user_id, fecha_registro, ultima_conexion')
          .eq('auth_user_id', u.id)
          .maybeSingle();

      final me = (meRes is Map<String, dynamic>) ? meRes : null;
      final rol = (me?['rol'] ?? '').toString().trim().toLowerCase();

      if (!mounted) return;
      setState(() {
        _me = me;
        _isAdmin = rol == 'admin';
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _queueSave() {
    _debounceSave?.cancel();
    _debounceSave = Timer(const Duration(milliseconds: 450), _save);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() {
        _lastSavedAt = DateTime.now();
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  String _shortId(String? id) {
    if (id == null || id.isEmpty) return '-';
    if (id.length <= 10) return id;
    return '${id.substring(0, 10)}…';
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

  String _whenSaved() {
    final t = _lastSavedAt;
    if (t == null) return '';
    final d = t.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return 'Guardado $hh:$mm';
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(t, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  Widget _card(Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: child,
      ),
    );
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

  Future<void> _confirmDialog(String title, String body, Future<void> Function() onOk) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
          ],
        );
      },
    );

    if (ok == true) {
      await onOk();
    }
  }

  Future<void> _editText({
    required String title,
    required String initial,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    required void Function(String v) onSaved,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
          ],
        );
      },
    );

    if (ok == true) {
      onSaved(ctrl.text.trim());
      _queueSave();
    }
  }

  Future<void> _openMiCuenta() async {
    final me = _me ?? {};
    final nombre = (me['nombre'] ?? '').toString().trim();
    final email = (me['email'] ?? '').toString().trim();
    final telefono = (me['telefono'] ?? '').toString().trim();
    final rol = (me['rol'] ?? '').toString().trim();
    final activo = (me['activo'] == true);
    final authUserId = (me['auth_user_id'] ?? '').toString().trim();
    final creado = _shortDate(me['fecha_registro']);
    final ultima = _shortDate(me['ultima_conexion']);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mi cuenta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _kv('Nombre', nombre.isEmpty ? '-' : nombre),
              _kv('Email', email.isEmpty ? '-' : email),
              _kv('Teléfono', telefono.isEmpty ? '-' : telefono),
              _kv('Rol', rol.isEmpty ? '-' : rol),
              _kv('Activo', activo ? 'Sí' : 'No'),
              _kv('Auth user', authUserId.isEmpty ? '-' : _shortId(authUserId)),
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

  Future<void> _signOut() async {
    try {
      await _client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (e) {
      _snack('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final me = _me;
    final nombre = (me?['nombre'] ?? 'Usuario').toString().trim();
    final email = (me?['email'] ?? '').toString().trim();
    final rol = (me?['rol'] ?? '-').toString().trim();
    final activo = (me?['activo'] == true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else if (_lastSavedAt != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(child: Text(_whenSaved(), style: const TextStyle(fontSize: 12))),
            ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _card(
                      ListTile(
                        onTap: _openMiCuenta,
                        leading: CircleAvatar(
                          backgroundColor: activo
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(nombre.isEmpty ? 'Usuario' : nombre),
                        subtitle: Text('${email.isEmpty ? '-' : email}  •  Rol: ${rol.isEmpty ? '-' : rol}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('ID: ${_shortId((me?['id'] ?? '').toString())}', style: Theme.of(context).textTheme.bodySmall),
                            Text('Auth: ${_shortId((me?['auth_user_id'] ?? '').toString())}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle('Ajustes generales'),
                    _card(
                      SwitchListTile(
                        value: _compactMode,
                        onChanged: (v) {
                          setState(() => _compactMode = v);
                          _queueSave();
                        },
                        secondary: const Icon(Icons.view_compact),
                        title: const Text('Modo compacto'),
                        subtitle: const Text('Reduce espacios y hace la app más rápida'),
                      ),
                    ),
                    _card(
                      SwitchListTile(
                        value: _confirmaciones,
                        onChanged: (v) {
                          setState(() => _confirmaciones = v);
                          _queueSave();
                        },
                        secondary: const Icon(Icons.check_circle_outline),
                        title: const Text('Confirmaciones'),
                        subtitle: const Text('Pedir confirmación antes de acciones importantes'),
                      ),
                    ),
                    _card(
                      SwitchListTile(
                        value: _pushNotifs,
                        onChanged: (v) {
                          setState(() => _pushNotifs = v);
                          _queueSave();
                        },
                        secondary: const Icon(Icons.notifications_active),
                        title: const Text('Notificaciones'),
                        subtitle: const Text('Avisos de eventos del sistema'),
                      ),
                    ),
                    _card(
                      SwitchListTile(
                        value: _sonido,
                        onChanged: (v) {
                          setState(() => _sonido = v);
                          _queueSave();
                        },
                        secondary: const Icon(Icons.volume_up),
                        title: const Text('Sonido'),
                        subtitle: const Text('Sonidos al cobrar o confirmar'),
                      ),
                    ),
                    _card(
                      SwitchListTile(
                        value: _vibracion,
                        onChanged: (v) {
                          setState(() => _vibracion = v);
                          _queueSave();
                        },
                        secondary: const Icon(Icons.vibration),
                        title: const Text('Vibración'),
                        subtitle: const Text('Vibración en confirmaciones y errores'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle('Negocio'),
                    _card(
                      ListTile(
                        leading: const Icon(Icons.store),
                        title: const Text('Nombre del negocio'),
                        subtitle: Text(_negocioNombre.isEmpty ? '-' : _negocioNombre),
                        onTap: () => _editText(
                          title: 'Nombre del negocio',
                          initial: _negocioNombre,
                          hint: 'Ej. Las Chilascas',
                          onSaved: (v) => setState(() => _negocioNombre = v),
                        ),
                      ),
                    ),
                    _card(
                      ListTile(
                        leading: const Icon(Icons.phone),
                        title: const Text('Teléfono'),
                        subtitle: Text(_negocioTelefono.isEmpty ? '-' : _negocioTelefono),
                        onTap: () => _editText(
                          title: 'Teléfono',
                          initial: _negocioTelefono,
                          hint: 'Ej. 7221234567',
                          keyboardType: TextInputType.phone,
                          onSaved: (v) => setState(() => _negocioTelefono = v),
                        ),
                      ),
                    ),
                    _card(
                      ListTile(
                        leading: const Icon(Icons.location_on),
                        title: const Text('Dirección'),
                        subtitle: Text(_negocioDireccion.isEmpty ? '-' : _negocioDireccion),
                        onTap: () => _editText(
                          title: 'Dirección',
                          initial: _negocioDireccion,
                          hint: 'Calle, colonia, ciudad',
                          maxLines: 2,
                          onSaved: (v) => setState(() => _negocioDireccion = v),
                        ),
                      ),
                    ),
                    _card(
                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('Horario'),
                        subtitle: Text(_negocioHorario.isEmpty ? '-' : _negocioHorario),
                        onTap: () => _editText(
                          title: 'Horario',
                          initial: _negocioHorario,
                          hint: 'Ej. Lun-Dom 8:00 a 15:00',
                          onSaved: (v) => setState(() => _negocioHorario = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle('Seguridad'),
                    _card(
                      ListTile(
                        leading: const Icon(Icons.verified_user),
                        title: const Text('Mi cuenta'),
                        subtitle: Text(_isAdmin ? 'Administrador' : 'Empleado'),
                        onTap: _openMiCuenta,
                      ),
                    ),
                    _card(
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Cerrar sesión'),
                        subtitle: const Text('Salir de la cuenta actual'),
                        onTap: () => _confirmDialog('Cerrar sesión', '¿Deseas cerrar sesión?', _signOut),
                      ),
                    ),
                    if (_isAdmin) ...[
                      const SizedBox(height: 14),
                      _sectionTitle('Admin'),
                      _card(
                        ListTile(
                          leading: const Icon(Icons.admin_panel_settings),
                          title: const Text('Auditoría / logs'),
                          subtitle: const Text('Eventos del sistema y cambios'),
                          onTap: () => _snack('Conecta aquí tu vista de auditoría'),
                        ),
                      ),
                      _card(
                        ListTile(
                          leading: const Icon(Icons.cloud),
                          title: const Text('Estado del backend'),
                          subtitle: const Text('Conectividad y diagnóstico'),
                          onTap: () => _snack('Conecta aquí tu diagnóstico real'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}
