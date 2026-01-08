import 'dart:math';
import 'package:chilascas_pos/views/estados/historico_estados.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EstadosView extends StatefulWidget {
  const EstadosView({super.key});

  @override
  State<EstadosView> createState() => _EstadosViewState();
}

class _EstadosViewState extends State<EstadosView> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  int _rangeDays = 7;
  String _metodoPagoFilter = 'Todos';
  bool _vistaGlobal = true;

  num _descuentos = 0;
  num _ventasNetas = 0;

  int _tickets = 0;
  int _canceladas = 0;

  num _promedio = 0;
  int _sodas = 0;

  bool _hasOpenCash = false;
  num _cashOpenMontoInicial = 0;

  Map<String, int> _ticketsPorDia = {};
  Map<String, int> _ticketsPorHora = {};
  Map<String, num> _ventasPorMetodo = {};

  List<_TopItem> _topBases = [];
  List<_TopItem> _topEspecialidades = [];
  List<_TopItem> _topSalsas = [];
  List<_TopItem> _topProteinas = [];
  List<_TopItem> _topToppings = [];
  int _drinksCount = 0;

  List<Map<String, dynamic>> _ultimasVentas = [];

  DateTime get _nowLocal => DateTime.now();

  DateTime get _fromLocalMidnight =>
      DateTime(_nowLocal.year, _nowLocal.month, _nowLocal.day).subtract(Duration(days: _rangeDays - 1));

  DateTime get _toLocalExclusive =>
      DateTime(_nowLocal.year, _nowLocal.month, _nowLocal.day).add(const Duration(days: 1));

  String get _fromIsoUtc => _fromLocalMidnight.toUtc().toIso8601String();
  String get _toIsoUtc => _toLocalExclusive.toUtc().toIso8601String();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _setRange(int days) {
    setState(() => _rangeDays = days);
    _loadAll();
  }

  void _setMetodoPago(String v) {
    setState(() => _metodoPagoFilter = v);
    _loadAll();
  }

  void _toggleVistaGlobal(bool v) {
    setState(() => _vistaGlobal = v);
  }

  void _goHistorico() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HistoricoEstadosView(),
      ),
    );
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ventasAll = await _loadVentasInRange(includeCanceladas: true);

      final ventasFiltered = _metodoPagoFilter == 'Todos'
          ? ventasAll
          : ventasAll
              .where((v) => (v['metodo_pago'] ?? 'Sin método').toString().trim() == _metodoPagoFilter)
              .toList();

      final canceladas = ventasFiltered.where((r) {
        final estado = (r['estado'] ?? '').toString().trim().toLowerCase();
        return estado == 'cancelada' || estado == 'cancelado';
      }).toList();

      final ventasValidas = ventasFiltered.where((r) {
        final estado = (r['estado'] ?? '').toString().trim().toLowerCase();
        return estado != 'cancelada' && estado != 'cancelado';
      }).toList();

      final calc = _calcVentas(ventasValidas);
      final calcCancel = _calcCanceladas(canceladas);

      final openCash = await _loadOpenCash();

      final top = await _loadTopFromDetalle(ventasValidas);
      final ultimas = await _loadUltimasVentas();

      setState(() {
        _descuentos = calc.descuentos;
        _ventasNetas = calc.ventasNetas;

        _tickets = calc.tickets;
        _canceladas = calcCancel;

        _promedio = calc.tickets == 0 ? 0 : (calc.ventasNetas / calc.tickets);
        _sodas = calc.sodas;

        _ticketsPorDia = calc.ticketsPorDia;
        _ticketsPorHora = calc.ticketsPorHora;
        _ventasPorMetodo = calc.ventasPorMetodo;

        _hasOpenCash = openCash.hasOpen;
        _cashOpenMontoInicial = openCash.montoInicial;

        _topBases = top.topBases;
        _topEspecialidades = top.topEspecialidades;
        _topSalsas = top.topSalsas;
        _topProteinas = top.topProteinas;
        _topToppings = top.topToppings;
        _drinksCount = top.drinksCount;

        _ultimasVentas = ultimas;

        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadVentasInRange({required bool includeCanceladas}) async {
    final res = await _client
        .from('ventas')
        .select(
            'id, total, metodo_pago, created_at, estado, descuento, descuento_percent, refresco_gratis, sodas, mesa_nombre, cliente_nombre, monto_recibido, cambio')
        .gte('created_at', _fromIsoUtc)
        .lt('created_at', _toIsoUtc)
        .order('created_at', ascending: true);

    final rows = List<Map<String, dynamic>>.from(res);

    if (includeCanceladas) return rows;

    return rows.where((r) {
      final estado = (r['estado'] ?? '').toString().trim().toLowerCase();
      return estado != 'cancelada' && estado != 'cancelado';
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadUltimasVentas() async {
    final res = await _client
        .from('ventas')
        .select('id, total, metodo_pago, created_at, estado, mesa_nombre, cliente_nombre, descuento, descuento_percent, sodas')
        .order('created_at', ascending: false)
        .limit(20);

    return List<Map<String, dynamic>>.from(res);
  }

  _VentasAgg _calcVentas(List<Map<String, dynamic>> ventasValidas) {
    num bruto = 0;
    num desc = 0;
    int sodas = 0;

    final ticketsPorDia = <String, int>{};
    final ticketsPorHora = <String, int>{};
    final ventasPorMetodo = <String, num>{};

    for (final v in ventasValidas) {
      final total = (v['total'] ?? 0) as num;
      final descuento = (v['descuento'] ?? 0) as num;

      bruto += total;
      desc += descuento;

      final mp = (v['metodo_pago'] ?? 'Sin método').toString().trim();
      ventasPorMetodo[mp] = (ventasPorMetodo[mp] ?? 0) + total;

      final s = v['sodas'];
      if (s is int) sodas += s;

      final createdAt = DateTime.tryParse((v['created_at'] ?? '').toString())?.toLocal();
      if (createdAt != null) {
        final dayKey =
            '${createdAt.year.toString().padLeft(4, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        ticketsPorDia[dayKey] = (ticketsPorDia[dayKey] ?? 0) + 1;

        final hourKey = '${createdAt.hour.toString().padLeft(2, '0')}:00';
        ticketsPorHora[hourKey] = (ticketsPorHora[hourKey] ?? 0) + 1;
      }
    }

    final neta = bruto - desc;

    return _VentasAgg(
      ventasBrutas: bruto,
      descuentos: desc,
      ventasNetas: neta,
      tickets: ventasValidas.length,
      sodas: sodas,
      ticketsPorDia: ticketsPorDia,
      ticketsPorHora: ticketsPorHora,
      ventasPorMetodo: ventasPorMetodo,
    );
  }

  int _calcCanceladas(List<Map<String, dynamic>> canceladas) => canceladas.length;

  Future<_OpenCashResult> _loadOpenCash() async {
    final user = _client.auth.currentUser;
    if (user == null) return const _OpenCashResult(false, 0);

    final res = await _client
        .from('sesiones_caja')
        .select('id, estado, monto_inicial')
        .eq('auth_id', user.id)
        .eq('estado', 'abierta')
        .order('fecha_apertura', ascending: false)
        .limit(1);

    final rows = List<Map<String, dynamic>>.from(res);
    if (rows.isEmpty) return const _OpenCashResult(false, 0);

    final montoInicial = (rows.first['monto_inicial'] ?? 0) as num;
    return _OpenCashResult(true, montoInicial);
  }

  Future<_TopAgg> _loadTopFromDetalle(List<Map<String, dynamic>> ventasValidas) async {
    final ids = <int>[];
    for (final v in ventasValidas) {
      final id = v['id'];
      if (id is int) ids.add(id);
    }
    if (ids.isEmpty) return _TopAgg.empty();

    final det = await _client
        .from('detalle_ventas')
        .select('venta_id, base, especialidad, salsa, proteina, toppings, is_drink')
        .inFilter('venta_id', ids);

    final rows = List<Map<String, dynamic>>.from(det);

    final bases = <String, int>{};
    final esp = <String, int>{};
    final salsas = <String, int>{};
    final prot = <String, int>{};
    final tops = <String, int>{};
    int drinks = 0;

    for (final r in rows) {
      final isDrink = (r['is_drink'] ?? false) == true;
      if (isDrink) {
        drinks += 1;
        continue;
      }

      final b = (r['base'] ?? '').toString().trim();
      final e = (r['especialidad'] ?? '').toString().trim();
      final s = (r['salsa'] ?? '').toString().trim();
      final p = (r['proteina'] ?? '').toString().trim();
      final t = r['toppings'];

      if (b.isNotEmpty) bases[b] = (bases[b] ?? 0) + 1;
      if (e.isNotEmpty) esp[e] = (esp[e] ?? 0) + 1;
      if (s.isNotEmpty) salsas[s] = (salsas[s] ?? 0) + 1;
      if (p.isNotEmpty) prot[p] = (prot[p] ?? 0) + 1;

      if (t is List) {
        for (final x in t) {
          final label = (x ?? '').toString().trim();
          if (label.isEmpty) continue;
          tops[label] = (tops[label] ?? 0) + 1;
        }
      }
    }

    List<_TopItem> top(Map<String, int> m) {
      final list = m.entries.map((e) => _TopItem(e.key, e.value)).toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      return list.take(8).toList();
    }

    return _TopAgg(
      topBases: top(bases),
      topEspecialidades: top(esp),
      topSalsas: top(salsas),
      topProteinas: top(prot),
      topToppings: top(tops),
      drinksCount: drinks,
    );
  }

  String _money(num v) => '\$${v.toStringAsFixed(2)}';

  Widget _buildVistaGlobal(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final maxMetodo = _ventasPorMetodo.entries.isEmpty
        ? null
        : (_ventasPorMetodo.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;

    final maxDia = _ticketsPorDia.entries.isEmpty
        ? null
        : (_ticketsPorDia.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;

    final maxHora = _ticketsPorHora.entries.isEmpty
        ? null
        : (_ticketsPorHora.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;

    final topBase = _topBases.isEmpty ? null : _topBases.first;
    final topSalsa = _topSalsas.isEmpty ? null : _topSalsas.first;
    final topProt = _topProteinas.isEmpty ? null : _topProteinas.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.dashboard, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vista global', style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Resumen simple para entender rápido.', style: t.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              runSpacing: 12,
              spacing: 12,
              children: [
                _BigStat(icon: Icons.attach_money, title: 'Ventas netas', value: _money(_ventasNetas)),
                _BigStat(icon: Icons.receipt_long, title: 'Tickets', value: _tickets.toString()),
                _BigStat(icon: Icons.percent, title: 'Descuentos', value: _money(_descuentos)),
                _BigStat(icon: Icons.cancel, title: 'Canceladas', value: _canceladas.toString()),
                _BigStat(icon: Icons.trending_up, title: 'Promedio', value: _money(_promedio)),
                _BigStat(icon: Icons.local_drink, title: 'Sodas', value: _sodas.toString()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(_hasOpenCash ? Icons.lock_open : Icons.lock),
            title: Text(_hasOpenCash ? 'Caja abierta' : 'Caja cerrada'),
            subtitle: _hasOpenCash ? Text('Monto inicial: \$${_cashOpenMontoInicial.toStringAsFixed(2)}') : null,
            trailing: Icon(_hasOpenCash ? Icons.check_circle : Icons.info),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lo más importante', style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _InsightLine(
                  icon: Icons.payments,
                  label: 'Método más usado',
                  value: maxMetodo == null ? 'Sin datos' : '${maxMetodo.key} (${_money(maxMetodo.value)})',
                ),
                _InsightLine(
                  icon: Icons.calendar_today,
                  label: 'Día con más tickets',
                  value: maxDia == null ? 'Sin datos' : '${maxDia.key.substring(5)} (${maxDia.value})',
                ),
                _InsightLine(
                  icon: Icons.schedule,
                  label: 'Hora pico',
                  value: maxHora == null ? 'Sin datos' : '${maxHora.key} (${maxHora.value})',
                ),
                _InsightLine(
                  icon: Icons.restaurant,
                  label: 'Top base',
                  value: topBase == null ? 'Sin datos' : '${topBase.label} (${topBase.count})',
                ),
                _InsightLine(
                  icon: Icons.soup_kitchen,
                  label: 'Top salsa',
                  value: topSalsa == null ? 'Sin datos' : '${topSalsa.label} (${topSalsa.count})',
                ),
                _InsightLine(
                  icon: Icons.set_meal,
                  label: 'Top proteína',
                  value: topProt == null ? 'Sin datos' : '${topProt.label} (${topProt.count})',
                ),
                _InsightLine(
                  icon: Icons.local_drink,
                  label: 'Bebidas',
                  value: _drinksCount.toString(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goHistorico,
        icon: const Icon(Icons.timeline),
        label: const Text('Histórico'),
      ),
      appBar: AppBar(
        title: const Text('Estados'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _loadAll)
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _SectionTitle(title: 'Filtros'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ChoiceChip(
                            label: const Text('Hoy'),
                            selected: _rangeDays == 1,
                            onSelected: (_) => _setRange(1),
                          ),
                          ChoiceChip(
                            label: const Text('7 días'),
                            selected: _rangeDays == 7,
                            onSelected: (_) => _setRange(7),
                          ),
                          ChoiceChip(
                            label: const Text('30 días'),
                            selected: _rangeDays == 30,
                            onSelected: (_) => _setRange(30),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: DropdownButtonFormField<String>(
                            value: _metodoPagoFilter,
                            items: _buildMetodoItems(),
                            onChanged: (v) => _setMetodoPago(v ?? 'Todos'),
                            decoration: const InputDecoration(
                              labelText: 'Método de pago',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: SwitchListTile(
                          value: _vistaGlobal,
                          onChanged: _toggleVistaGlobal,
                          title: const Text('Vista global'),
                          subtitle: const Text('Muestra un resumen simple y fácil de entender'),
                          secondary: const Icon(Icons.dashboard),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_vistaGlobal) ...[
                        _buildVistaGlobal(context),
                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 8),
                        _SectionTitle(title: 'Detalle'),
                        const SizedBox(height: 12),
                      ],
                      _SectionTitle(title: 'Resumen'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              title: 'Ventas netas',
                              value: _money(_ventasNetas),
                              icon: Icons.attach_money,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _KpiCard(
                              title: 'Tickets',
                              value: _tickets.toString(),
                              icon: Icons.receipt_long,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              title: 'Descuentos',
                              value: _money(_descuentos),
                              icon: Icons.percent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _KpiCard(
                              title: 'Canceladas',
                              value: _canceladas.toString(),
                              icon: Icons.cancel,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              title: 'Promedio',
                              value: _money(_promedio),
                              icon: Icons.trending_up,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _KpiCard(
                              title: 'Sodas',
                              value: _sodas.toString(),
                              icon: Icons.local_drink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _CajaStatusCard(
                        abierta: _hasOpenCash,
                        montoInicial: _cashOpenMontoInicial,
                      ),
                      const SizedBox(height: 18),
                      _SectionTitle(title: 'Ventas por día (tickets)'),
                      const SizedBox(height: 12),
                      _BarsByDay(data: _ticketsPorDia, from: _fromLocalMidnight, days: _rangeDays),
                      const SizedBox(height: 18),
                      _SectionTitle(title: 'Ventas por hora (tickets)'),
                      const SizedBox(height: 12),
                      _BarsByHour(data: _ticketsPorHora),
                      const SizedBox(height: 18),
                      _SectionTitle(title: 'Métodos de pago (monto)'),
                      const SizedBox(height: 12),
                      _BreakdownList(map: _ventasPorMetodo),
                      const SizedBox(height: 18),
                      _SectionTitle(title: 'Top del menú'),
                      const SizedBox(height: 12),
                      _TopGroup(title: 'Bases', items: _topBases),
                      _TopGroup(title: 'Especialidades', items: _topEspecialidades),
                      _TopGroup(title: 'Salsas', items: _topSalsas),
                      _TopGroup(title: 'Proteínas', items: _topProteinas),
                      _TopGroup(title: 'Toppings', items: _topToppings),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.local_drink),
                          title: const Text('Bebidas'),
                          trailing: Text(_drinksCount.toString()),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SectionTitle(title: 'Últimas ventas'),
                      const SizedBox(height: 12),
                      _UltimasVentasTable(rows: _ultimasVentas),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  List<DropdownMenuItem<String>> _buildMetodoItems() {
    final base = <String>{'Todos'};
    for (final k in _ventasPorMetodo.keys) {
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
}

class _BigStat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _BigStat({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 170,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.labelMedium),
                    const SizedBox(height: 6),
                    Text(value, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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

class _InsightLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InsightLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: t.bodyMedium)),
          const SizedBox(width: 10),
          Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _VentasAgg {
  final num ventasBrutas;
  final num descuentos;
  final num ventasNetas;
  final int tickets;
  final int sodas;
  final Map<String, int> ticketsPorDia;
  final Map<String, int> ticketsPorHora;
  final Map<String, num> ventasPorMetodo;

  _VentasAgg({
    required this.ventasBrutas,
    required this.descuentos,
    required this.ventasNetas,
    required this.tickets,
    required this.sodas,
    required this.ticketsPorDia,
    required this.ticketsPorHora,
    required this.ventasPorMetodo,
  });
}

class _OpenCashResult {
  final bool hasOpen;
  final num montoInicial;
  const _OpenCashResult(this.hasOpen, this.montoInicial);
}

class _TopAgg {
  final List<_TopItem> topBases;
  final List<_TopItem> topEspecialidades;
  final List<_TopItem> topSalsas;
  final List<_TopItem> topProteinas;
  final List<_TopItem> topToppings;
  final int drinksCount;

  _TopAgg({
    required this.topBases,
    required this.topEspecialidades,
    required this.topSalsas,
    required this.topProteinas,
    required this.topToppings,
    required this.drinksCount,
  });

  static _TopAgg empty() => _TopAgg(
        topBases: const [],
        topEspecialidades: const [],
        topSalsas: const [],
        topProteinas: const [],
        topToppings: const [],
        drinksCount: 0,
      );
}

class _TopItem {
  final String label;
  final int count;
  _TopItem(this.label, this.count);
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.labelLarge),
                  const SizedBox(height: 6),
                  Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CajaStatusCard extends StatelessWidget {
  final bool abierta;
  final num montoInicial;

  const _CajaStatusCard({
    required this.abierta,
    required this.montoInicial,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(abierta ? Icons.lock_open : Icons.lock),
        title: Text(abierta ? 'Caja abierta' : 'Caja cerrada'),
        subtitle: abierta ? Text('Monto inicial: \$${montoInicial.toStringAsFixed(2)}') : null,
      ),
    );
  }
}

class _BarsByDay extends StatelessWidget {
  final Map<String, int> data;
  final DateTime from;
  final int days;

  const _BarsByDay({
    required this.data,
    required this.from,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final list = <MapEntry<String, int>>[];
    for (int i = 0; i < days; i++) {
      final d = from.add(Duration(days: i));
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      list.add(MapEntry(key, data[key] ?? 0));
    }

    final maxV = list.isEmpty ? 1 : max(1, list.map((e) => e.value).reduce(max));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final e in list)
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
                    SizedBox(width: 32, child: Text(e.value.toString())),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarsByHour extends StatelessWidget {
  final Map<String, int> data;
  const _BarsByHour({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sin datos'),
        ),
      );
    }

    final maxV = max(1, entries.map((e) => e.value).reduce(max));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 70, child: Text(e.key)),
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
                    SizedBox(width: 32, child: Text(e.value.toString())),
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

class _TopGroup extends StatelessWidget {
  final String title;
  final List<_TopItem> items;

  const _TopGroup({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(
        child: ListTile(
          title: Text(title),
          subtitle: const Text('Sin datos'),
        ),
      );
    }

    final maxV = max(1, items.map((e) => e.count).reduce(max));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(it.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: it.count / maxV,
                          minHeight: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 30, child: Text(it.count.toString())),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UltimasVentasTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _UltimasVentasTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sin ventas'),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Hora')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Pago')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Mesa')),
            DataColumn(label: Text('Cliente')),
          ],
          rows: rows.map((v) {
            final id = v['id'];
            final createdAt = DateTime.tryParse((v['created_at'] ?? '').toString())?.toLocal();
            final hora = createdAt == null
                ? '-'
                : '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
            final total = (v['total'] ?? 0) as num;
            final pago = (v['metodo_pago'] ?? 'Sin método').toString();
            final estado = (v['estado'] ?? '').toString();
            final mesa = (v['mesa_nombre'] ?? '').toString();
            final cliente = (v['cliente_nombre'] ?? '').toString();

            return DataRow(
              cells: [
                DataCell(Text(id.toString())),
                DataCell(Text(hora)),
                DataCell(Text('\$${total.toStringAsFixed(2)}')),
                DataCell(Text(pago)),
                DataCell(Text(estado.isEmpty ? '-' : estado)),
                DataCell(Text(mesa.isEmpty ? '-' : mesa)),
                DataCell(Text(cliente.isEmpty ? '-' : cliente)),
              ],
            );
          }).toList(),
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
