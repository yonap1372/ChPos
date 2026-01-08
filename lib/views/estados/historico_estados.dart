import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoricoEstadosView extends StatefulWidget {
  const HistoricoEstadosView({super.key});

  @override
  State<HistoricoEstadosView> createState() => _HistoricoEstadosViewState();
}

class _HistoricoEstadosViewState extends State<HistoricoEstadosView> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  final _range = ValueNotifier<String>('todo');
  final _metodo = ValueNotifier<String>('Todos');

  _HistAgg _agg = _HistAgg.empty();
  _HistAgg _prevAgg = _HistAgg.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _range.dispose();
    _metodo.dispose();
    super.dispose();
  }

  DateTime _startForRange(String r) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (r == 'hoy') return today;
    if (r == '7d') return today.subtract(const Duration(days: 6));
    if (r == '30d') return today.subtract(const Duration(days: 29));
    if (r == '90d') return today.subtract(const Duration(days: 89));
    if (r == '365d') return today.subtract(const Duration(days: 364));
    return DateTime(2000, 1, 1);
  }

  DateTime _endExclusiveNow() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  DateTime _prevStartForRange(String r, DateTime start) {
    if (r == 'hoy') return start.subtract(const Duration(days: 1));
    if (r == '7d') return start.subtract(const Duration(days: 7));
    if (r == '30d') return start.subtract(const Duration(days: 30));
    if (r == '90d') return start.subtract(const Duration(days: 90));
    if (r == '365d') return start.subtract(const Duration(days: 365));
    return DateTime(2000, 1, 1);
  }

  DateTime _prevEndForRange(String r, DateTime start) {
    if (r == 'hoy') return start;
    if (r == '7d') return start;
    if (r == '30d') return start;
    if (r == '90d') return start;
    if (r == '365d') return start;
    return _endExclusiveNow();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final start = _startForRange(_range.value);
      final endEx = _endExclusiveNow();

      final prevStart = _prevStartForRange(_range.value, start);
      final prevEndEx = _prevEndForRange(_range.value, start);

      final ventas = await _loadVentasBetween(start, endEx);
      final ventasPrev = await _loadVentasBetween(prevStart, prevEndEx);

      final metodo = _metodo.value;
      final ventasFiltradas = metodo == 'Todos'
          ? ventas
          : ventas.where((v) => (v['metodo_pago'] ?? 'Sin método').toString().trim() == metodo).toList();

      final ventasPrevFiltradas = metodo == 'Todos'
          ? ventasPrev
          : ventasPrev.where((v) => (v['metodo_pago'] ?? 'Sin método').toString().trim() == metodo).toList();

      final agg = _calcAgg(ventasFiltradas);
      final prevAgg = _calcAgg(ventasPrevFiltradas);

      setState(() {
        _agg = agg;
        _prevAgg = prevAgg;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadVentasBetween(DateTime start, DateTime endEx) async {
    final res = await _client
        .from('ventas')
        .select('id, total, descuento, metodo_pago, created_at, estado, sodas')
        .gte('created_at', start.toUtc().toIso8601String())
        .lt('created_at', endEx.toUtc().toIso8601String())
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(res);
  }

  _HistAgg _calcAgg(List<Map<String, dynamic>> rows) {
    final validas = <Map<String, dynamic>>[];
    int canceladas = 0;
    for (final r in rows) {
      final estado = (r['estado'] ?? '').toString().trim().toLowerCase();
      if (estado == 'cancelada' || estado == 'cancelado') {
        canceladas += 1;
      } else {
        validas.add(r);
      }
    }

    num bruto = 0;
    num desc = 0;
    int sodas = 0;
    final porMetodo = <String, num>{};
    final porDia = <String, num>{};

    for (final v in validas) {
      final total = (v['total'] ?? 0) as num;
      final descuento = (v['descuento'] ?? 0) as num;

      bruto += total;
      desc += descuento;

      final mp = (v['metodo_pago'] ?? 'Sin método').toString().trim();
      porMetodo[mp] = (porMetodo[mp] ?? 0) + total;

      final s = v['sodas'];
      if (s is int) sodas += s;

      final createdAt = DateTime.tryParse((v['created_at'] ?? '').toString())?.toLocal();
      if (createdAt != null) {
        final key =
            '${createdAt.year.toString().padLeft(4, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        porDia[key] = (porDia[key] ?? 0) + total;
      }
    }

    final neta = bruto - desc;
    final tickets = validas.length;
    final promedio = tickets == 0 ? 0 : (neta / tickets);

    return _HistAgg(
      ventasNetas: neta,
      descuentos: desc,
      tickets: tickets,
      canceladas: canceladas,
      promedio: promedio,
      sodas: sodas,
      ventasPorMetodo: porMetodo,
      ventasPorDia: porDia,
    );
  }

  String _money(num v) => '\$${v.toStringAsFixed(2)}';

  double _pctDelta(num now, num prev) {
    if (prev == 0 && now == 0) return 0;
    if (prev == 0) return 1;
    return ((now - prev) / prev);
  }

  String _fmtDelta(num now, num prev) {
    final d = _pctDelta(now, prev);
    final sign = d >= 0 ? '+' : '';
    return '$sign${(d * 100).toStringAsFixed(0)}%';
  }

  Color? _deltaColor(BuildContext context, num now, num prev) {
    final d = _pctDelta(now, prev);
    final cs = Theme.of(context).colorScheme;
    if (d > 0) return cs.primary;
    if (d < 0) return cs.error;
    return null;
  }

  IconData _deltaIcon(num now, num prev) {
    final d = _pctDelta(now, prev);
    if (d > 0) return Icons.trending_up;
    if (d < 0) return Icons.trending_down;
    return Icons.drag_handle;
  }

  List<DropdownMenuItem<String>> _buildMetodoItems() {
    final base = <String>{'Todos'};
    for (final k in _agg.ventasPorMetodo.keys) {
      base.add(k);
    }
    final items = base.toList();
    items.sort((a, b) {
      if (a == 'Todos') return -1;
      if (b == 'Todos') return 1;
      return a.compareTo(b);
    });
    return items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Wrap(
                            runSpacing: 12,
                            spacing: 12,
                            children: [
                              ValueListenableBuilder<String>(
                                valueListenable: _range,
                                builder: (context, v, _) {
                                  return _RangeChips(
                                    value: v,
                                    onChanged: (x) {
                                      _range.value = x;
                                      _load();
                                    },
                                  );
                                },
                              ),
                              SizedBox(
                                width: 260,
                                child: ValueListenableBuilder<String>(
                                  valueListenable: _metodo,
                                  builder: (context, v, _) {
                                    return DropdownButtonFormField<String>(
                                      value: v,
                                      items: _buildMetodoItems(),
                                      onChanged: (x) {
                                        _metodo.value = x ?? 'Todos';
                                        _load();
                                      },
                                      decoration: const InputDecoration(
                                        labelText: 'Método de pago',
                                        border: OutlineInputBorder(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ComparativaHeader(
                        title: 'Comparativa',
                        subtitle: _range.value == 'todo'
                            ? 'Todo vs todo (sin periodo anterior)'
                            : 'Periodo actual vs periodo anterior',
                      ),
                      const SizedBox(height: 12),
                      _CompareGrid(
                        items: [
                          _CompareItem(
                            title: 'Ventas netas',
                            value: _money(_agg.ventasNetas),
                            delta: _range.value == 'todo' ? null : _fmtDelta(_agg.ventasNetas, _prevAgg.ventasNetas),
                            deltaIcon: _deltaIcon(_agg.ventasNetas, _prevAgg.ventasNetas),
                            deltaColor: _deltaColor(context, _agg.ventasNetas, _prevAgg.ventasNetas),
                            icon: Icons.attach_money,
                          ),
                          _CompareItem(
                            title: 'Tickets',
                            value: _agg.tickets.toString(),
                            delta: _range.value == 'todo' ? null : _fmtDelta(_agg.tickets, _prevAgg.tickets),
                            deltaIcon: _deltaIcon(_agg.tickets, _prevAgg.tickets),
                            deltaColor: _deltaColor(context, _agg.tickets, _prevAgg.tickets),
                            icon: Icons.receipt_long,
                          ),
                          _CompareItem(
                            title: 'Promedio',
                            value: _money(_agg.promedio),
                            delta: _range.value == 'todo' ? null : _fmtDelta(_agg.promedio, _prevAgg.promedio),
                            deltaIcon: _deltaIcon(_agg.promedio, _prevAgg.promedio),
                            deltaColor: _deltaColor(context, _agg.promedio, _prevAgg.promedio),
                            icon: Icons.trending_up,
                          ),
                          _CompareItem(
                            title: 'Descuentos',
                            value: _money(_agg.descuentos),
                            delta: _range.value == 'todo' ? null : _fmtDelta(_agg.descuentos, _prevAgg.descuentos),
                            deltaIcon: _deltaIcon(_agg.descuentos, _prevAgg.descuentos),
                            deltaColor: _deltaColor(context, _agg.descuentos, _prevAgg.descuentos),
                            icon: Icons.percent,
                          ),
                          _CompareItem(
                            title: 'Canceladas',
                            value: _agg.canceladas.toString(),
                            delta: _range.value == 'todo' ? null : _fmtDelta(_agg.canceladas, _prevAgg.canceladas),
                            deltaIcon: _deltaIcon(_agg.canceladas, _prevAgg.canceladas),
                            deltaColor: _deltaColor(context, _agg.canceladas, _prevAgg.canceladas),
                            icon: Icons.cancel,
                          ),
                          _CompareItem(
                            title: 'Sodas',
                            value: _agg.sodas.toString(),
                            delta: _range.value == 'todo' ? null : _fmtDelta(_agg.sodas, _prevAgg.sodas),
                            deltaIcon: _deltaIcon(_agg.sodas, _prevAgg.sodas),
                            deltaColor: _deltaColor(context, _agg.sodas, _prevAgg.sodas),
                            icon: Icons.local_drink,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SectionTitle(title: 'Ventas por método (monto)'),
                      const SizedBox(height: 10),
                      _BreakdownList(map: _agg.ventasPorMetodo),
                      const SizedBox(height: 12),
                      _SectionTitle(title: 'Evolución por día (monto)'),
                      const SizedBox(height: 10),
                      _BarsMoneyByDay(map: _agg.ventasPorDia),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _HistAgg {
  final num ventasNetas;
  final num descuentos;
  final int tickets;
  final int canceladas;
  final num promedio;
  final int sodas;
  final Map<String, num> ventasPorMetodo;
  final Map<String, num> ventasPorDia;

  _HistAgg({
    required this.ventasNetas,
    required this.descuentos,
    required this.tickets,
    required this.canceladas,
    required this.promedio,
    required this.sodas,
    required this.ventasPorMetodo,
    required this.ventasPorDia,
  });

  static _HistAgg empty() => _HistAgg(
        ventasNetas: 0,
        descuentos: 0,
        tickets: 0,
        canceladas: 0,
        promedio: 0,
        sodas: 0,
        ventasPorMetodo: const {},
        ventasPorDia: const {},
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _ComparativaHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ComparativaHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.analytics, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: t.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _RangeChips({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ChoiceChip(
          label: const Text('Todo'),
          selected: value == 'todo',
          onSelected: (_) => onChanged('todo'),
        ),
        ChoiceChip(
          label: const Text('Hoy'),
          selected: value == 'hoy',
          onSelected: (_) => onChanged('hoy'),
        ),
        ChoiceChip(
          label: const Text('7d'),
          selected: value == '7d',
          onSelected: (_) => onChanged('7d'),
        ),
        ChoiceChip(
          label: const Text('30d'),
          selected: value == '30d',
          onSelected: (_) => onChanged('30d'),
        ),
        ChoiceChip(
          label: const Text('90d'),
          selected: value == '90d',
          onSelected: (_) => onChanged('90d'),
        ),
        ChoiceChip(
          label: const Text('1 año'),
          selected: value == '365d',
          onSelected: (_) => onChanged('365d'),
        ),
      ],
    );
  }
}

class _CompareItem {
  final String title;
  final String value;
  final String? delta;
  final IconData deltaIcon;
  final Color? deltaColor;
  final IconData icon;

  _CompareItem({
    required this.title,
    required this.value,
    required this.delta,
    required this.deltaIcon,
    required this.deltaColor,
    required this.icon,
  });
}

class _CompareGrid extends StatelessWidget {
  final List<_CompareItem> items;

  const _CompareGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cols = w >= 900 ? 3 : (w >= 560 ? 2 : 1);

    return LayoutBuilder(
      builder: (context, c) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final it in items)
              SizedBox(
                width: cols == 1
                    ? c.maxWidth
                    : cols == 2
                        ? (c.maxWidth - 12) / 2
                        : (c.maxWidth - 24) / 3,
                child: _CompareCard(item: it),
              ),
          ],
        );
      },
    );
  }
}

class _CompareCard extends StatelessWidget {
  final _CompareItem item;
  const _CompareCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(item.icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: t.labelLarge),
                  const SizedBox(height: 6),
                  Text(item.value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (item.delta != null)
                    Row(
                      children: [
                        Icon(item.deltaIcon, size: 18, color: item.deltaColor),
                        const SizedBox(width: 6),
                        Text(
                          item.delta!,
                          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: item.deltaColor),
                        ),
                        const SizedBox(width: 8),
                        Text('vs anterior', style: t.bodySmall),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownList extends StatelessWidget {
  final Map<String, num> map;
  const _BreakdownList({required this.map});

  @override
  Widget build(BuildContext context) {
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    num total = 0;
    for (final e in entries) {
      total += e.value;
    }
    if (total <= 0) total = 1;

    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sin datos'),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (final e in entries)
            ListTile(
              leading: const Icon(Icons.payments),
              title: Text(e.key),
              subtitle: Text('\$${e.value.toStringAsFixed(2)}'),
              trailing: Text('${((e.value / total) * 100).toStringAsFixed(0)}%'),
            ),
        ],
      ),
    );
  }
}

class _BarsMoneyByDay extends StatelessWidget {
  final Map<String, num> map;
  const _BarsMoneyByDay({required this.map});

  @override
  Widget build(BuildContext context) {
    if (map.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sin datos'),
        ),
      );
    }

    final entries = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxV = max(1, entries.map((e) => e.value).reduce(max));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final e in entries.take(45))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 92, child: Text(e.key.substring(5))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: e.value / maxV,
                          minHeight: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 92, child: Text('\$${e.value.toStringAsFixed(0)}')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
