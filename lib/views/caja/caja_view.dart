import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CajaView extends StatefulWidget {
  const CajaView({super.key});

  @override
  State<CajaView> createState() => _CajaViewState();
}

class _CajaViewState extends State<CajaView> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _sesiones = [];
  Map<String, dynamic>? _openSesion;

  int _rangeDays = 30;
  bool _soloMias = true;
  String _estadoFilter = 'Todas';

  int _sesionesAbiertas = 0;
  int _sesionesCerradas = 0;
  num _sumMontoInicial = 0;
  num _sumMontoFinal = 0;
  num _avgInicial = 0;
  num _avgFinal = 0;

  DateTime get _nowLocal => DateTime.now();

  DateTime get _fromLocalMidnight => DateTime(_nowLocal.year, _nowLocal.month, _nowLocal.day)
      .subtract(Duration(days: _rangeDays - 1));

  DateTime get _toLocalExclusive =>
      DateTime(_nowLocal.year, _nowLocal.month, _nowLocal.day).add(const Duration(days: 1));

  String get _fromIsoUtc => _fromLocalMidnight.toUtc().toIso8601String();
  String get _toIsoUtc => _toLocalExclusive.toUtc().toIso8601String();

  @override
  void initState() {
    super.initState();
    _load();
  }

  num _toNum(dynamic v, {num fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return fallback;
    return num.tryParse(s.replaceAll(',', '.')) ?? fallback;
  }

  String _money(num v) => '\$${v.toStringAsFixed(2)}';

  String _shortDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final dl = d.toLocal();
    final y = dl.year.toString().padLeft(4, '0');
    final m = dl.month.toString().padLeft(2, '0');
    final day = dl.day.toString().padLeft(2, '0');
    final hh = dl.hour.toString().padLeft(2, '0');
    final mm = dl.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }

  String _shortId(String? id) {
    if (id == null || id.isEmpty) return '-';
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  bool _isOpen(Map<String, dynamic> s) {
    final estado = (s['estado'] ?? '').toString().trim().toLowerCase();
    if (estado == 'abierta') return true;
    final fc = (s['fecha_cierre'] ?? '').toString().trim();
    if (fc.isEmpty) return true;
    return false;
  }

  String _estadoLabel(Map<String, dynamic> s) {
    final estado = (s['estado'] ?? '').toString().trim().toLowerCase();
    if (estado.isNotEmpty) return estado;
    return _isOpen(s) ? 'abierta' : 'cerrada';
  }

  Duration? _duracion(Map<String, dynamic> s) {
    final fa = DateTime.tryParse((s['fecha_apertura'] ?? '').toString());
    if (fa == null) return null;

    final fcRaw = (s['fecha_cierre'] ?? '').toString().trim();
    final fc = fcRaw.isEmpty ? null : DateTime.tryParse(fcRaw);

    final start = fa.toLocal();
    final end = (fc ?? DateTime.now()).toLocal();
    if (end.isBefore(start)) return null;
    return end.difference(start);
  }

  String _duracionStr(Duration? d) {
    if (d == null) return '-';
    final mins = d.inMinutes;
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h < 24) return '${h}h ${m}m';
    final days = h ~/ 24;
    final hh = h % 24;
    return '${days}d ${hh}h';
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

      PostgrestFilterBuilder<List<Map<String, dynamic>>> q = _client
          .from('sesiones_caja')
          .select('id, auth_id, usuario_id, fecha_apertura, fecha_cierre, monto_inicial, monto_final, estado')
          .gte('fecha_apertura', _fromIsoUtc)
          .lt('fecha_apertura', _toIsoUtc);

      if (_soloMias) {
        q = q.eq('auth_id', user.id);
      }

      if (_estadoFilter == 'abierta') {
        q = q.eq('estado', 'abierta');
      } else if (_estadoFilter == 'cerrada') {
        q = q.eq('estado', 'cerrada');
      }

      final res = await q.order('fecha_apertura', ascending: false).limit(200);
      final list = List<Map<String, dynamic>>.from(res);

      Map<String, dynamic>? openSesion;
      for (final s in list) {
        if (_isOpen(s)) {
          openSesion = s;
          break;
        }
      }

      int abiertas = 0;
      int cerradas = 0;
      num sumIni = 0;
      num sumFin = 0;
      int finCount = 0;

      for (final s in list) {
        final mi = _toNum(s['monto_inicial']);
        final mfRaw = s['monto_final'];
        final mfNum = (mfRaw is num) ? mfRaw : (mfRaw == null ? null : num.tryParse(mfRaw.toString()));

        sumIni += mi;
        if (mfNum != null) {
          sumFin += mfNum;
          finCount += 1;
        }

        if (_isOpen(s)) {
          abiertas += 1;
        } else {
          cerradas += 1;
        }
      }

      if (!mounted) return;
      setState(() {
        _sesiones = list;
        _openSesion = openSesion;

        _sesionesAbiertas = abiertas;
        _sesionesCerradas = cerradas;

        _sumMontoInicial = sumIni;
        _sumMontoFinal = sumFin;

        _avgInicial = list.isEmpty ? 0 : (sumIni / list.length);
        _avgFinal = finCount == 0 ? 0 : (sumFin / finCount);

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

  void _openDetalle(Map<String, dynamic> s) {
    final fa = (s['fecha_apertura'] ?? '').toString();
    final fc = (s['fecha_cierre'] ?? '').toString();
    final mi = _toNum(s['monto_inicial']);
    final mfRaw = s['monto_final'];
    final mfNum = (mfRaw is num) ? mfRaw : (mfRaw == null ? null : num.tryParse(mfRaw.toString()));
    final estado = _estadoLabel(s);
    final authId = (s['auth_id'] ?? '').toString();
    final usuarioId = (s['usuario_id'] ?? '').toString();
    final dur = _duracion(s);

    final diff = (mfNum ?? 0) - mi;
    final diffAbs = diff.abs();
    final diffStr = mfNum == null
        ? '-'
        : (diff > 0 ? '+${_money(diffAbs)}' : diff < 0 ? '-${_money(diffAbs)}' : _money(0));

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Detalle de sesión'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _kv('Estado', estado),
              _kv('Apertura', fa.isEmpty ? '-' : _shortDate(fa)),
              _kv('Cierre', fc.isEmpty ? '-' : _shortDate(fc)),
              _kv('Duración', _duracionStr(dur)),
              const SizedBox(height: 10),
              _kv('Monto inicial', _money(mi)),
              _kv('Monto final', mfNum == null ? '-' : _money(mfNum)),
              _kv('Diferencia', diffStr),
              const SizedBox(height: 10),
              _kv('Auth', _shortId(authId)),
              _kv('Usuario', _shortId(usuarioId)),
              _kv('ID', _shortId(s['id']?.toString())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ],
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 10),
          Text(v),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final abierta = _openSesion != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de caja'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Estado actual', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(abierta ? Icons.lock_open : Icons.lock),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      abierta ? 'Caja abierta' : 'No hay caja abierta',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              if (abierta) ...[
                                const SizedBox(height: 10),
                                Text('Apertura: ${_shortDate((_openSesion?['fecha_apertura'] ?? '').toString())}'),
                                Text('Monto inicial: ${_money(_toNum(_openSesion?['monto_inicial']))}'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Hoy'),
                                    selected: _rangeDays == 1,
                                    onSelected: (_) {
                                      setState(() => _rangeDays = 1);
                                      _load();
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('7 días'),
                                    selected: _rangeDays == 7,
                                    onSelected: (_) {
                                      setState(() => _rangeDays = 7);
                                      _load();
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('30 días'),
                                    selected: _rangeDays == 30,
                                    onSelected: (_) {
                                      setState(() => _rangeDays = 30);
                                      _load();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                value: _soloMias,
                                onChanged: (v) {
                                  setState(() => _soloMias = v);
                                  _load();
                                },
                                title: const Text('Solo mis sesiones'),
                                subtitle: const Text('Filtra por el usuario actual (auth_id)'),
                                secondary: const Icon(Icons.person),
                                contentPadding: EdgeInsets.zero,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _estadoFilter,
                                items: const [
                                  DropdownMenuItem(value: 'Todas', child: Text('Todas')),
                                  DropdownMenuItem(value: 'abierta', child: Text('Abiertas')),
                                  DropdownMenuItem(value: 'cerrada', child: Text('Cerradas')),
                                ],
                                onChanged: (v) {
                                  setState(() => _estadoFilter = v ?? 'Todas');
                                  _load();
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Estado',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Resumen', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _StatChip(icon: Icons.lock_open, label: 'Abiertas', value: '$_sesionesAbiertas'),
                                  _StatChip(icon: Icons.lock, label: 'Cerradas', value: '$_sesionesCerradas'),
                                  _StatChip(icon: Icons.savings, label: 'Suma inicial', value: _money(_sumMontoInicial)),
                                  _StatChip(icon: Icons.account_balance_wallet, label: 'Suma final', value: _money(_sumMontoFinal)),
                                  _StatChip(icon: Icons.trending_up, label: 'Prom. inicial', value: _money(_avgInicial)),
                                  _StatChip(icon: Icons.trending_up, label: 'Prom. final', value: _money(_avgFinal)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Sesiones', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      if (_sesiones.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Sin sesiones en este rango'),
                          ),
                        ),
                      for (final s in _sesiones)
                        _SesionTile(
                          s: s,
                          isOpen: _isOpen(s),
                          estadoLabel: _estadoLabel(s),
                          shortDate: _shortDate,
                          money: _money,
                          shortId: _shortId,
                          duracionStr: _duracionStr(_duracion(s)),
                          toNum: _toNum,
                          onTap: () => _openDetalle(s),
                        ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SesionTile extends StatelessWidget {
  final Map<String, dynamic> s;
  final bool isOpen;
  final String estadoLabel;
  final String Function(String) shortDate;
  final String Function(num) money;
  final String Function(String?) shortId;
  final String duracionStr;
  final num Function(dynamic v, {num fallback}) toNum;
  final VoidCallback onTap;

  const _SesionTile({
    required this.s,
    required this.isOpen,
    required this.estadoLabel,
    required this.shortDate,
    required this.money,
    required this.shortId,
    required this.duracionStr,
    required this.toNum,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fa = (s['fecha_apertura'] ?? '').toString();
    final fc = (s['fecha_cierre'] ?? '').toString();
    final mi = toNum(s['monto_inicial']);

    final mfRaw = s['monto_final'];
    final mfNum = (mfRaw is num) ? mfRaw : (mfRaw == null ? null : num.tryParse(mfRaw.toString()));

    final authId = (s['auth_id'] ?? '').toString();
    final usuarioId = (s['usuario_id'] ?? '').toString();

    final diff = mfNum == null ? null : (mfNum - mi);
    final diffAbs = diff == null ? 0 : diff.abs();
    final diffStr = diff == null ? '-' : (diff > 0 ? '+${money(diffAbs)}' : diff < 0 ? '-${money(diffAbs)}' : money(0));

    final diffColor = diff == null
        ? Theme.of(context).textTheme.bodySmall?.color
        : diff > 0
            ? Colors.green
            : diff < 0
                ? Colors.red
                : Theme.of(context).textTheme.bodySmall?.color;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(isOpen ? Icons.lock_open : Icons.lock),
        title: Text('Estado: ${estadoLabel.isEmpty ? '-' : estadoLabel}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apertura: ${fa.isEmpty ? '-' : shortDate(fa)}'),
            Text('Cierre: ${fc.isEmpty ? '-' : shortDate(fc)}'),
            Text('Duración: $duracionStr'),
            Text('Auth: ${shortId(authId)} | Usuario: ${shortId(usuarioId)}'),
          ],
        ),
        trailing: SizedBox(
          width: 170,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Ini: ${money(mi)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Fin: ${mfNum == null ? '-' : money(mfNum)}'),
              Text('Dif: $diffStr', style: TextStyle(color: diffColor)),
            ],
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}
