// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/impresora_service.dart';

class RealizarVentaView extends StatefulWidget {
  const RealizarVentaView({super.key});

  @override
  State<RealizarVentaView> createState() => _RealizarVentaViewState();
}

class _RealizarVentaViewState extends State<RealizarVentaView> {
  Map<String, dynamic>? cajaAbierta;

  final List<Map<String, dynamic>> carrito = [];
  String? baseSeleccionada;
  String? salsaSeleccionada;
  String? proteinaSeleccionada;
  String? especialidadSeleccionada;
  String? huevoTipo;
  final List<String> toppingsSeleccionados = [];
  final List<Map<String, dynamic>> extrasSeleccionados = [];

  double total = 0;
  bool cargando = false;

  int? ventaMesaId;
  String? nombreMesaActual;
  List<Map<String, dynamic>> mesasAbiertas = [];

  static const _bases = ['Sencillo', 'Con proteína', 'Especialidad', 'Vegetariano'];
  static const _salsas = ['Verde', 'Roja', 'Mole', 'Salsa crema Chipotle', 'Sin salsa'];
  static const _proteinas = ['Pollo', 'Huevo', 'Carnitas', 'Sin proteína'];
  static const _especialidades = ['Arrachera', 'Chicharrón prensado'];
  static const _toppings = ['Queso', 'Crema', 'Cebolla', 'Cilantro'];

  static const Map<String, double> _precioBase = {
    'Sencillo': 120,
    'Con proteína': 160,
    'Especialidad': 195,
    'Vegetariano': 160,
  };

  static const Map<String, double> _preciosExtras = {
    'Pollo extra': 30,
    'Huevo extra': 30,
    'Carnitas': 30,
    'Arrachera': 50,
    'Chicharrón prensado': 50,
    'Crema': 10,
    'Queso': 10,
  };

  static const Map<String, double> _recargoProteina = {
    'Pollo': 0,
    'Huevo': 0,
    'Carnitas': 5,
    'Sin proteína': 0,
  };

  static const double _precioRefresco = 30.0;
  static const double _descuentoPorcentajeFijo = 15.0;

  @override
  void initState() {
    super.initState();
    toppingsSeleccionados.addAll(_toppings);
    verificarCaja();
  }

  Future<void> verificarCaja() async {
    setState(() => cargando = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => cargando = false);
      return;
    }

    final resp = await Supabase.instance.client
        .from('sesiones_caja')
        .select()
        .eq('auth_id', userId)
        .eq('estado', 'abierta')
        .maybeSingle();

    setState(() {
      cajaAbierta = resp;
      cargando = false;
    });

    if (cajaAbierta != null) {
      await _cargarMesasAbiertas();
    }
  }

  Future<void> abrirCaja(double monto) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client.from('sesiones_caja').insert({
      'auth_id': userId,
      'monto_inicial': monto,
      'estado': 'abierta',
      'fecha_apertura': DateTime.now().toIso8601String(),
    });

    await verificarCaja();
  }


  Future<void> _cargarMesasAbiertas() async {
    if (cajaAbierta == null) return;
    final sesionId = cajaAbierta!['id'];
    final ventas = await Supabase.instance.client
        .from('ventas')
        .select('id, mesa, total, estado, descuento_percent, created_at')
        .eq('sesion_caja_id', sesionId)
        .eq('estado', 'abierta')
        .order('created_at');

    setState(() {
      mesasAbiertas = List<Map<String, dynamic>>.from(ventas);
    });
  }

  Future<void> _crearOModificarMesaDialog() async {
    final ctrl = TextEditingController(text: nombreMesaActual ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<_MesaAccion>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Guardar en mesa abierta'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Nombre/No. de mesa (ej. Mesa 1)',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Ingresa un nombre de mesa'
                : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, _MesaAccion.guardar);
              }
            },
            label: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == _MesaAccion.guardar) {
      await _guardarEnMesa(ctrl.text.trim());
    }
  }

  Future<void> _guardarEnMesa(String mesaNombre) async {
    if (carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos en el carrito')),
      );
      return;
    }
    if (cajaAbierta == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final sesionId = cajaAbierta!['id'];

    dynamic venta;
    if (ventaMesaId == null) {
      venta = await Supabase.instance.client.from('ventas').insert({
        'auth_id': user.id,
        'sesion_caja_id': sesionId,
        'mesa': mesaNombre,
        'estado': 'abierta',
        'fecha': DateTime.now().toIso8601String(),
        'total': total,
      }).select().single();

      ventaMesaId = venta['id'] as int;
      nombreMesaActual = mesaNombre;
    } else {
      await Supabase.instance.client
          .from('detalle_ventas')
          .delete()
          .eq('venta_id', ventaMesaId!);

      await Supabase.instance.client
          .from('ventas')
          .update({
            'mesa': mesaNombre,
            'total': total,
            'estado': 'abierta',
          })
          .eq('id', ventaMesaId!);
    }

    for (final item in carrito) {
      await Supabase.instance.client.from('detalle_ventas').insert({
        'venta_id': ventaMesaId,
        'base': item['base'],
        'salsa': item['salsa'],
        'proteina': item['proteina'],
        'especialidad': item['especialidad'],
        'huevo_tipo': item['huevoTipo'],
        'toppings': item['toppings'],
        'extras': item['extras'],
        'precio': item['precio'],
        'is_drink': item['isDrink'] == true,
      });
    }

    await _cargarMesasAbiertas();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Guardado en "$nombreMesaActual"')),
    );
  }

  Future<void> _seleccionarMesaParaCargar() async {
    await _cargarMesasAbiertas();
    final mesaIdElegida = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mesas abiertas'),
        content: SizedBox(
          width: 420,
          child: mesasAbiertas.isEmpty
              ? const Text('No hay mesas abiertas por ahora.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (_, i) {
                    final m = mesasAbiertas[i];
                    return ListTile(
                      leading: const Icon(Icons.table_bar),
                      title: Text(m['mesa'] ?? '(Sin nombre)'),
                      subtitle: Text('Total parcial: \$${(m['total'] ?? 0).toStringAsFixed(2)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, m['id'] as int),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 8),
                  itemCount: mesasAbiertas.length,
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );

    if (mesaIdElegida != null) {
      await _cargarMesa(mesaIdElegida);
    }
  }

  Future<void> _cargarMesa(int idVenta) async {
    final venta = await Supabase.instance.client
        .from('ventas')
        .select('id, mesa, total, estado')
        .eq('id', idVenta)
        .maybeSingle();

    if (venta == null) return;

    final detalles = await Supabase.instance.client
        .from('detalle_ventas')
        .select()
        .eq('venta_id', idVenta);

    ventaMesaId = venta['id'] as int;
    nombreMesaActual = (venta['mesa'] as String?) ?? 'Mesa';

    carrito
      ..clear()
      ..addAll(
        List<Map<String, dynamic>>.from(detalles.map<Map<String, dynamic>>((d) {
          return {
            'base': d['base'],
            'salsa': d['salsa'],
            'proteina': d['proteina'],
            'especialidad': d['especialidad'],
            'huevoTipo': d['huevo_tipo'],
            'toppings': (d['toppings'] as List?)?.cast<String>() ?? <String>[],
            'extras': (d['extras'] is List)
              ? List<Map<String, dynamic>>.from(
                  (d['extras'] as List).map((e) {
                    if (e is Map) return Map<String, dynamic>.from(e);
                    return {'nombre': e.toString(), 'precio': 0};
                  }),
                )
              : [],
            'precio': (d['precio'] as num?)?.toDouble() ?? 0.0,
            'isDrink': d['is_drink'] == true,
          };
        })),
      );

    calcularTotal();

    setState(() {
      baseSeleccionada = null;
      salsaSeleccionada = null;
      proteinaSeleccionada = null;
      especialidadSeleccionada = null;
      huevoTipo = null;
      toppingsSeleccionados
        ..clear()
        ..addAll(_toppings);
      extrasSeleccionados.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mesa "$nombreMesaActual" cargada')),
    );
  }


  void calcularTotal() {
    total = carrito.fold<double>(0, (sum, item) {
      final p = (item['precio'] as num?)?.toDouble() ?? 0.0;
      return sum + p;
    });
    setState(() {});
  }

  double _calcularPrecioPedido({
    required String base,
    required String? proteina,
    List<Map<String, dynamic>> extras = const [],
  }) {
    final basePrice = _precioBase[base] ?? 0;
    final recargo = _recargoProteina[proteina ?? 'Sin proteína'] ?? 0;
    double tot = basePrice + recargo;
    for (final e in extras) {
      tot += (e['precio'] as num).toDouble();
    }
    return tot;
  }

  Future<void> _mostrarDialogoExtras() async {
    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("¿Deseas agregar extras?"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _preciosExtras.keys.map((extra) {
                    final precio = _preciosExtras[extra]!;
                    final selected = extrasSeleccionados.any((e) => e['nombre'] == extra);
                    return CheckboxListTile(
                      title: Text("$extra (\$$precio)"),
                      value: selected,
                      onChanged: (v) {
                        setStateDialog(() {
                          if (v == true) {
                            extrasSeleccionados.add({'nombre': extra, 'precio': precio});
                          } else {
                            extrasSeleccionados.removeWhere((e) => e['nombre'] == extra);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Aceptar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> agregarProductoActual() async {
    if (baseSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos la base')),
      );
      return;
    }
    if (baseSeleccionada == 'Especialidad' && especialidadSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la especialidad')),
      );
      return;
    }
    if (proteinaSeleccionada == 'Huevo' && huevoTipo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el tipo de huevo')),
      );
      return;
    }

    extrasSeleccionados.clear();
    await _mostrarDialogoExtras();

    final precio = _calcularPrecioPedido(
      base: baseSeleccionada!,
      proteina: proteinaSeleccionada,
      extras: extrasSeleccionados,
    );

    carrito.add({
      'base': baseSeleccionada,
      'salsa': salsaSeleccionada,
      'proteina': proteinaSeleccionada,
      'especialidad': especialidadSeleccionada,
      'huevoTipo': huevoTipo,
      'toppings': List<String>.from(toppingsSeleccionados),
      'extras': List<Map<String, dynamic>>.from(extrasSeleccionados),
      'precio': precio,
      'isDrink': false,
    });

    calcularTotal();

    setState(() {
      baseSeleccionada = null;
      salsaSeleccionada = null;
      proteinaSeleccionada = null;
      especialidadSeleccionada = null;
      toppingsSeleccionados
        ..clear()
        ..addAll(_toppings);
      huevoTipo = null;
      extrasSeleccionados.clear();
    });
  }

  void _agregarRefresco() {
    carrito.add({
      'base': 'Refresco',
      'salsa': null,
      'proteina': null,
      'especialidad': null,
      'huevoTipo': null,
      'toppings': <String>[],
      'extras': <Map<String, dynamic>>[],
      'precio': _precioRefresco,
      'isDrink': true,
    });
    calcularTotal();
  }

  Future<void> _editarItemDialog(int index) async {
    final item = Map<String, dynamic>.from(carrito[index]);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final tmpExtras = List<Map<String, dynamic>>.from(item['extras'] ?? []);
        final tmpToppings = List<String>.from(item['toppings'] ?? []);
        String? tmpSalsa = item['salsa'];
        String? tmpProteina = item['proteina'];
        String? tmpHuevoTipo = item['huevoTipo'];
        String? tmpEspecialidad = item['especialidad'];
        final isDrink = item['isDrink'] == true;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Editar: ${item['base']}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!isDrink) ...[
                        const Text('Salsa', style: TextStyle(fontWeight: FontWeight.w600)),
                        Wrap(
                          spacing: 8,
                          children: _salsas.map((s) {
                            final sel = s == tmpSalsa;
                            return ChoiceChip(
                              label: Text(s),
                              selected: sel,
                              onSelected: (_) => setStateDialog(() => tmpSalsa = s),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        const Text('Proteína', style: TextStyle(fontWeight: FontWeight.w600)),
                        Wrap(
                          spacing: 8,
                          children: _proteinas.map((p) {
                            final sel = p == tmpProteina;
                            return ChoiceChip(
                              label: Text(p),
                              selected: sel,
                              onSelected: (_) => setStateDialog(() {
                                tmpProteina = p;
                                if (p != 'Huevo') tmpHuevoTipo = null;
                              }),
                            );
                          }).toList(),
                        ),
                        if (tmpProteina == 'Huevo') ...[
                          const SizedBox(height: 12),
                          const Text('Tipo de huevo', style: TextStyle(fontWeight: FontWeight.w600)),
                          Wrap(
                            spacing: 8,
                            children: [
                              'Estrellado - Tierno',
                              'Estrellado - Bien cocido',
                              'Revuelto',
                            ].map((h) {
                              final sel = h == tmpHuevoTipo;
                              return ChoiceChip(
                                label: Text(h),
                                selected: sel,
                                onSelected: (_) => setStateDialog(() => tmpHuevoTipo = h),
                              );
                            }).toList(),
                          ),
                        ],
                        if ((item['base'] as String?) == 'Especialidad') ...[
                          const SizedBox(height: 12),
                          const Text('Especialidad', style: TextStyle(fontWeight: FontWeight.w600)),
                          Wrap(
                            spacing: 8,
                            children: _especialidades.map((e) {
                              final sel = e == tmpEspecialidad;
                              return ChoiceChip(
                                label: Text(e),
                                selected: sel,
                                onSelected: (_) => setStateDialog(() => tmpEspecialidad = e),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text('Toppings', style: TextStyle(fontWeight: FontWeight.w600)),
                        Wrap(
                          spacing: 8,
                          children: _toppings.map((t) {
                            final sel = tmpToppings.contains(t);
                            return FilterChip(
                              label: Text(t),
                              selected: sel,
                              onSelected: (v) => setStateDialog(() {
                                if (v) {
                                  tmpToppings.add(t);
                                } else {
                                  tmpToppings.remove(t);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        ExpansionTile(
                          title: const Text('Extras'),
                          children: _preciosExtras.entries.map((e) {
                            final selected = tmpExtras.any((x) => x['nombre'] == e.key);
                            return CheckboxListTile(
                              title: Text('${e.key} (\$${e.value})'),
                              value: selected,
                              onChanged: (v) {
                                setStateDialog(() {
                                  if (v == true) {
                                    tmpExtras.add({'nombre': e.key, 'precio': e.value});
                                  } else {
                                    tmpExtras.removeWhere((x) => x['nombre'] == e.key);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() {
                                  carrito.removeAt(index);
                                  calcularTotal();
                                });
                              },
                              label: const Text('Eliminar ítem'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.check),
                              onPressed: () {
                                if (!isDrink) {
                                  item['salsa'] = tmpSalsa;
                                  item['proteina'] = tmpProteina;
                                  item['huevoTipo'] = tmpHuevoTipo;
                                  item['especialidad'] = tmpEspecialidad;
                                  item['toppings'] = tmpToppings;
                                  item['extras'] = tmpExtras;
                                  item['precio'] = _calcularPrecioPedido(
                                    base: item['base'] as String,
                                    proteina: tmpProteina,
                                    extras: tmpExtras,
                                  );
                                }
                                carrito[index] = item;
                                calcularTotal();
                                Navigator.pop(context);
                              },
                              label: const Text('Guardar cambios'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }


  Future<void> finalizarVenta() async {
    if (carrito.isEmpty || cajaAbierta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos o no hay caja abierta')),
      );
      return;
    }

    final CobroResultado? cobro = await _dialogoCobro(totalInicial: total);
    if (cobro == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final sesionId = cajaAbierta!['id'];
    dynamic venta;

    if (ventaMesaId == null) {
      venta = await Supabase.instance.client.from('ventas').insert({
        'auth_id': user.id,
        'sesion_caja_id': sesionId,
        'mesa': nombreMesaActual,
        'estado': 'cerrada',
        'fecha': DateTime.now().toIso8601String(),
        'metodo_pago': cobro.metodoPago,
        'descuento_percent': cobro.aplicarDescuento ? _descuentoPorcentajeFijo : 0,
        'sodas': _contarRefrescos(),
        'monto_recibido': cobro.montoRecibido,
        'cambio': cobro.cambio,
        'total': cobro.totalFinal,
      }).select().single();

      final ventaId = venta['id'];

      for (final item in carrito) {
        await Supabase.instance.client.from('detalle_ventas').insert({
          'venta_id': ventaId,
          'base': item['base'],
          'salsa': item['salsa'],
          'proteina': item['proteina'],
          'especialidad': item['especialidad'],
          'huevo_tipo': item['huevoTipo'],
          'toppings': item['toppings'],
          'extras': item['extras'],
          'precio': item['precio'],
          'is_drink': item['isDrink'] == true,
        });
      }
    } else {
      await Supabase.instance.client
          .from('ventas')
          .update({
            'estado': 'cerrada',
            'fecha': DateTime.now().toIso8601String(),
            'metodo_pago': cobro.metodoPago,
            'descuento_percent': cobro.aplicarDescuento ? _descuentoPorcentajeFijo : 0,
            'sodas': _contarRefrescos(),
            'monto_recibido': cobro.montoRecibido,
            'cambio': cobro.cambio,
            'total': cobro.totalFinal,
          })
          .eq('id', ventaMesaId!);

      await Supabase.instance.client
          .from('detalle_ventas')
          .delete()
          .eq('venta_id', ventaMesaId!);

      for (final item in carrito) {
        await Supabase.instance.client.from('detalle_ventas').insert({
          'venta_id': ventaMesaId,
          'base': item['base'],
          'salsa': item['salsa'],
          'proteina': item['proteina'],
          'especialidad': item['especialidad'],
          'huevo_tipo': item['huevoTipo'],
          'toppings': item['toppings'],
          'extras': item['extras'],
          'precio': item['precio'],
          'is_drink': item['isDrink'] == true,
        });
      }
    }

    await _imprimirTickets(
      metodoPago: cobro.metodoPago,
      totalFinal: cobro.totalFinal,
      descuento: cobro.aplicarDescuento ? _descuentoPorcentajeFijo : 0,
      refrescosGratis: false,
    );

    await abrirCajon();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Venta realizada e impresa')),
    );

    setState(() {
      carrito.clear();
      total = 0;
      ventaMesaId = null;
      nombreMesaActual = null;
    });

    await _cargarMesasAbiertas();
  }

  int _contarRefrescos() {
    return carrito.where((e) => e['isDrink'] == true).length;
  }

  Future<void> _imprimirTickets({
    required String metodoPago,
    required double totalFinal,
    required double descuento,
    required bool refrescosGratis,
  }) async {
    final hora = DateTime.now();
    final userEmail = Supabase.instance.client.auth.currentUser?.email ?? '-';

    final ticketCliente = StringBuffer();
    ticketCliente.writeln('*** CHILASCAS ***');
    ticketCliente.writeln('--------------------------');
    if (nombreMesaActual != null) ticketCliente.writeln('Mesa: $nombreMesaActual');
    ticketCliente.writeln('Usuario: $userEmail');
    ticketCliente.writeln('Hora: ${hora.hour}:${hora.minute.toString().padLeft(2, '0')}');
    ticketCliente.writeln('Método de pago: $metodoPago');
    ticketCliente.writeln('--------------------------');

    for (final item in carrito) {
      ticketCliente.writeln('${item['base']} ${item['especialidad'] ?? ''} ${item['proteina'] ?? ''}'
          .replaceAll(RegExp(r'\s+'), ' ').trim());
      if (item['huevoTipo'] != null) ticketCliente.writeln('  Huevo: ${item['huevoTipo']}');
      if (item['salsa'] != null && item['salsa'] != 'Sin salsa') {
        ticketCliente.writeln('  Salsa: ${item['salsa']}');
      }
      final tops = (item['toppings'] as List?)?.cast<String>() ?? [];
      if (tops.isNotEmpty) ticketCliente.writeln('  Toppings: ${tops.join(", ")}');
      final ex = (item['extras'] as List?) ?? [];
      if (ex.isNotEmpty) ticketCliente.writeln('  Extras: ${ex.map((e) => e['nombre']).join(", ")}');
      ticketCliente.writeln('  \$${(item['precio'] as num).toStringAsFixed(2)}');
      ticketCliente.writeln('--------------------------');
    }

    if (descuento > 0) ticketCliente.writeln('Descuento: ${descuento.toStringAsFixed(0)}%');
    ticketCliente.writeln('TOTAL: \$${totalFinal.toStringAsFixed(2)}');
    ticketCliente.writeln('--------------------------');
    ticketCliente.writeln('¡Gracias por su compra!');
    ticketCliente.writeln('\n\n\n');

    final ticketCocina = StringBuffer();
    ticketCocina.writeln('*** CHILASCAS - COCINA ***');
    ticketCocina.writeln('--------------------------');
    if (nombreMesaActual != null) ticketCocina.writeln('Mesa: $nombreMesaActual');
    ticketCocina.writeln('Hora: ${hora.hour}:${hora.minute.toString().padLeft(2, '0')}');
    ticketCocina.writeln('--------------------------');

    for (final item in carrito) {
      if (item['isDrink'] == true) continue;
      ticketCocina.writeln('> ${item['base']} ${item['especialidad'] ?? ''}'.trim());
      if (item['proteina'] != null && item['proteina'] != 'Sin proteína') {
        ticketCocina.writeln('  - Proteína: ${item['proteina']}');
      }
      if (item['huevoTipo'] != null) {
        ticketCocina.writeln('  - Tipo de huevo: ${item['huevoTipo']}');
      }
      if (item['salsa'] != null && item['salsa'] != 'Sin salsa') {
        ticketCocina.writeln('  - Salsa: ${item['salsa']}');
      }
      final tops = (item['toppings'] as List?)?.cast<String>() ?? [];
      if (tops.isNotEmpty) ticketCocina.writeln('  - Toppings: ${tops.join(", ")}');
      final ex = (item['extras'] as List?) ?? [];
      if (ex.isNotEmpty) ticketCocina.writeln('  - Extras: ${ex.map((e) => e['nombre']).join(", ")}');
      ticketCocina.writeln('--------------------------');
    }

    ticketCocina.writeln('Preparar con cuidado 🍽️');
    ticketCocina.writeln('\n\n\n');

    final clienteOk = await imprimirTicket(ticketCliente.toString(), tipo: 'cliente');
    final cocinaOk = await imprimirTicket(ticketCocina.toString(), tipo: 'cocina');

    if (!(clienteOk && cocinaOk)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al imprimir ${!clienteOk ? "cliente" : "cocina"}')),
      );
    }
  }


  Future<CobroResultado?> _dialogoCobro({required double totalInicial}) async {
    bool aplicarDescuento = false;
    String metodoPago = 'efectivo';
    final ctrlRecibido = TextEditingController();
    double totalConDescuento = totalInicial;

    double calcularTotal() {
      totalConDescuento = aplicarDescuento
          ? totalInicial * (1 - _descuentoPorcentajeFijo / 100)
          : totalInicial;
      return totalConDescuento;
    }

    double cambio = 0.0;

    return showDialog<CobroResultado>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final t = calcularTotal();
            final recibido = double.tryParse(ctrlRecibido.text.replaceAll(',', '.')) ?? 0.0;
            cambio = (metodoPago == 'efectivo') ? (recibido - t) : 0.0;

            return AlertDialog(
              title: const Text('Cobro'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Total: \$${t.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    value: aplicarDescuento,
                    title: const Text('Aplicar descuento 15%'),
                    onChanged: (v) => setStateDialog(() => aplicarDescuento = v),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Método de pago', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      'efectivo', 'tarjeta', 'transferencia'
                    ].map((m) {
                      final sel = m == metodoPago;
                      return ChoiceChip(
                        label: Text(m[0].toUpperCase() + m.substring(1)),
                        selected: sel,
                        onSelected: (_) => setStateDialog(() => metodoPago = m),
                      );
                    }).toList(),
                  ),
                  if (metodoPago == 'efectivo') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: ctrlRecibido,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto recibido',
                        prefixIcon: Icon(Icons.payments),
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Cambio: \$${cambio < 0 ? "0.00" : cambio.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cambio < 0 ? Colors.red : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    if (metodoPago == 'efectivo') {
                      final recibido = double.tryParse(ctrlRecibido.text.replaceAll(',', '.')) ?? 0.0;
                      if (recibido + 1e-9 < totalConDescuento) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('El monto recibido es menor al total')),
                        );
                        return;
                      }
                      cambio = recibido - totalConDescuento;
                      Navigator.pop(
                        context,
                        CobroResultado(
                          aplicarDescuento: aplicarDescuento,
                          metodoPago: metodoPago,
                          montoRecibido: recibido,
                          cambio: cambio < 0 ? 0 : cambio,
                          totalFinal: totalConDescuento,
                        ),
                      );
                    } else {
                      Navigator.pop(
                        context,
                        CobroResultado(
                          aplicarDescuento: aplicarDescuento,
                          metodoPago: metodoPago,
                          montoRecibido: null,
                          cambio: 0.0,
                          totalFinal: totalConDescuento,
                        ),
                      );
                    }
                  },
                  label: const Text('Cobrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> mostrarDialogoAbrirCaja() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Abrir caja'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Monto inicial'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton.icon(
            icon: const Icon(Icons.lock_open),
            onPressed: () {
              final monto = double.tryParse(controller.text.replaceAll(',', '.'));
              if (monto != null) {
                abrirCaja(monto);
                Navigator.pop(context);
              }
            },
            label: const Text('Abrir'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarMesasDialogo() async {
  final mesas = await Supabase.instance.client
      .from('ventas')
      .select('id, mesa_id, mesa_nombre, cliente_nombre, total, estado')
      .eq('estado', 'abierta')
      .order('created_at');

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Gestión de mesas'),
      content: SizedBox(
        width: 400,
        child: mesas.isEmpty
            ? const Text('No hay mesas abiertas actualmente.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: mesas.map<Widget>((m) {
                  return ListTile(
                    leading: const Icon(Icons.table_bar),
                    title: Text('Mesa: ${m['mesa_nombre'] ?? '(sin nombre)'}'),
                    subtitle: Text('Cliente: ${m['cliente_nombre'] ?? '-'}'),
                    trailing: Text('\$${(m['total'] ?? 0).toString()}'),
                    onTap: () {
                      Navigator.pop(context);
                      _cargarMesa(m['id']);
                    },
                  );
                }).toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _mostrarDialogoNuevaMesa();
          },
          child: const Text('➕ Agregar nueva mesa'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

  Future<void> _mostrarDialogoNuevaMesa() async {
  final nombreMesaCtrl = TextEditingController();
  final nombreClienteCtrl = TextEditingController();

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Nueva mesa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nombreMesaCtrl,
            decoration: const InputDecoration(labelText: 'Nombre de la mesa (opcional)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nombreClienteCtrl,
            decoration: const InputDecoration(labelText: 'Nombre del cliente (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Crear mesa'),
          onPressed: () async {
            final user = Supabase.instance.client.auth.currentUser;
            if (user == null) return;

            final nueva = await Supabase.instance.client
                .from('ventas')
                .insert({
                  'auth_id': user.id,
                  'sesion_caja_id': cajaAbierta!['id'],
                  'estado': 'abierta',
                  'mesa_nombre': nombreMesaCtrl.text.isNotEmpty
                      ? nombreMesaCtrl.text
                      : 'Mesa ${DateTime.now().millisecondsSinceEpoch % 1000}',
                  'cliente_nombre': nombreClienteCtrl.text,
                  'total': 0,
                })
                .select()
                .single();

            if (context.mounted) Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Mesa creada: ${nueva['mesa_nombre']}')),
            );

            await _cargarMesa(nueva['id']);
          },
        ),
      ],
    ),
  );
}



  Future<void> mostrarDialogoCerrarCaja() async {
    if (cajaAbierta == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    if (userId == null) return;

    final sesionId = cajaAbierta!['id'];
    final montoInicial = (cajaAbierta!['monto_inicial'] as num?)?.toDouble() ?? 0;
    final apertura = DateTime.tryParse(cajaAbierta!['fecha_apertura']?.toString() ?? '') ?? DateTime.now();

    final ventas = await Supabase.instance.client
        .from('ventas')
        .select('id, total, metodo_pago')
        .eq('sesion_caja_id', sesionId)
        .eq('estado', 'cerrada');

    double totalVentas = 0;
    int totalTickets = ventas.length;
    final Map<String, double> totalesPorMetodo = {};

    for (final v in ventas) {
      final t = (v['total'] as num?)?.toDouble() ?? 0;
      final m = (v['metodo_pago'] ?? 'efectivo') as String;
      totalVentas += t;
      totalesPorMetodo[m] = (totalesPorMetodo[m] ?? 0) + t;
    }

    final montoFinal = montoInicial + totalVentas;
    final cierre = DateTime.now();
    final promedio = totalTickets > 0 ? totalVentas / totalTickets : 0;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resumen de caja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Apertura', '${apertura.toLocal()}'),
            _kv('Cierre', '${cierre.toLocal()}'),
            _kv('Usuario', user?.email ?? '-'),
            const Divider(),
            _kv('Monto inicial', '\$${montoInicial.toStringAsFixed(2)}'),
            _kv('Total ventas', '\$${totalVentas.toStringAsFixed(2)}'),
            _kv('Monto final', '\$${montoFinal.toStringAsFixed(2)}', valueStyle: const TextStyle(fontWeight: FontWeight.bold)),
            _kv('Tickets', '$totalTickets'),
            _kv('Promedio venta', '\$${promedio.toStringAsFixed(2)}'),
            const Divider(),
            const Text('Por método de pago:', style: TextStyle(fontWeight: FontWeight.w600)),
            for (final e in totalesPorMetodo.entries) _kv(' - ${e.key}', '\$${e.value.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            const Text('¿Deseas cerrar la caja e imprimir el resumen?'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton.icon(
            icon: const Icon(Icons.lock_outline),
            onPressed: () async {
              await Supabase.instance.client
                  .from('sesiones_caja')
                  .update({
                    'estado': 'cerrada',
                    'fecha_cierre': cierre.toIso8601String(),
                  })
                  .eq('id', sesionId);

              final resumen = StringBuffer();
              resumen.writeln('*** RESUMEN DEL DÍA ***');
              resumen.writeln('--------------------------');
              resumen.writeln('Usuario: ${user?.email ?? '-'}');
              resumen.writeln('Fecha: ${cierre.day}/${cierre.month}/${cierre.year}');
              resumen.writeln('Apertura: ${apertura.hour}:${apertura.minute.toString().padLeft(2, '0')}');
              resumen.writeln('Cierre:   ${cierre.hour}:${cierre.minute.toString().padLeft(2, '0')}');
              resumen.writeln('--------------------------');
              resumen.writeln('Monto inicial: \$${montoInicial.toStringAsFixed(2)}');
              resumen.writeln('Total ventas:  \$${totalVentas.toStringAsFixed(2)}');
              resumen.writeln('Monto final:   \$${montoFinal.toStringAsFixed(2)}');
              resumen.writeln('Tickets: $totalTickets');
              resumen.writeln('Promedio venta: \$${promedio.toStringAsFixed(2)}');
              resumen.writeln('--------------------------');
              resumen.writeln('Por método de pago:');
              for (final e in totalesPorMetodo.entries) {
                resumen.writeln(' - ${e.key}: \$${e.value.toStringAsFixed(2)}');
              }
              resumen.writeln('--------------------------');
              resumen.writeln('Fin del turno ✔️');
              resumen.writeln('\n\n\n');

              await imprimirTicket(resumen.toString(), tipo: 'cliente');

              setState(() {
                cajaAbierta = null;
                carrito.clear();
                total = 0;
                ventaMesaId = null;
                nombreMesaActual = null;
              });

              if (context.mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Caja cerrada e impresa correctamente')),
              );
            },
            label: const Text('Cerrar e imprimir'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (cajaAbierta == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromARGB(255, 212, 153, 14), Color(0xFFFFB100)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.point_of_sale, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    const Text('Chilascas POS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('Abre la caja para comenzar a vender', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.lock_open),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(280, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: mostrarDialogoAbrirCaja,
                      label: const Text('Abrir caja'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromARGB(255, 212, 153, 14), Color(0xFFFFB100)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          (ventaMesaId != null && nombreMesaActual != null)
              ? 'Ventas — ${nombreMesaActual!} (abierta)'
              : 'Ventas — Chilascas',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_restaurant),
            tooltip: 'Mesas abiertas',
            onPressed: _mostrarMesasDialogo,
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Cerrar caja',
            onPressed: mostrarDialogoCerrarCaja,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 980;

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        title: 'Armar pedido',
                        subtitle: 'Selecciona base, salsa, proteína y toppings',
                        icon: Icons.restaurant,
                      ),
                      const SizedBox(height: 12),

                      _SectionCard(
                        title: 'Base',
                        subtitle: 'Obligatorio',
                        child: _ChipWrap<String>(
                          options: _bases,
                          value: baseSeleccionada,
                          onSelected: (v) => setState(() {
                            baseSeleccionada = v;
                            proteinaSeleccionada = null;
                            huevoTipo = null;
                            especialidadSeleccionada = null;

                            if (v == 'Vegetariano') {
                              toppingsSeleccionados
                                ..clear()
                                ..addAll(_toppings);
                            }
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _SectionCard(
                        title: 'Salsa',
                        subtitle: 'Opcional',
                        child: _ChipWrap<String>(
                          options: _salsas,
                          value: salsaSeleccionada,
                          onSelected: (v) => setState(() => salsaSeleccionada = v),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (baseSeleccionada != 'Especialidad' && baseSeleccionada != 'Vegetariano')
                        _SectionCard(
                          title: 'Proteína',
                          subtitle: baseSeleccionada == 'Sencillo' ? 'No aplica para Sencillo' : 'Opcional',
                          child: AbsorbPointer(
                            absorbing: baseSeleccionada == 'Sencillo',
                            child: Opacity(
                              opacity: baseSeleccionada == 'Sencillo' ? 0.4 : 1.0,
                              child: _ChipWrap<String>(
                                options: _proteinas,
                                value: proteinaSeleccionada,
                                onSelected: (v) => setState(() {
                                  if (baseSeleccionada != 'Sencillo') proteinaSeleccionada = v;
                                }),
                              ),
                            ),
                          ),
                        ),

                      if (proteinaSeleccionada == "Huevo")
                        _SectionCard(
                          title: "Tipo de huevo",
                          subtitle: "Obligatorio",
                          child: _ChipWrap<String>(
                            options: ["Estrellado - Tierno", "Estrellado - Bien cocido", "Revuelto"],
                            value: huevoTipo,
                            onSelected: (v) => setState(() => huevoTipo = v),
                          ),
                        ),

                      if (baseSeleccionada == 'Especialidad')
                        _SectionCard(
                          title: 'Especialidad',
                          subtitle: 'Obligatorio',
                          child: _ChipWrap<String>(
                            options: _especialidades,
                            value: especialidadSeleccionada,
                            onSelected: (v) => setState(() => especialidadSeleccionada = v),
                          ),
                        ),

                      const SizedBox(height: 12),

                      _SectionCard(
                        title: '¿Con todo?',
                        subtitle: 'Toppings preseleccionados (quita los que NO desee)',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _toppings.map((t) {
                            final selected = toppingsSeleccionados.contains(t);
                            return FilterChip(
                              label: Text(t),
                              selected: selected,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    toppingsSeleccionados.add(t);
                                  } else {
                                    toppingsSeleccionados.remove(t);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.add_shopping_cart),
                              style: FilledButton.styleFrom(
                                minimumSize: Size(isWide ? 300 : double.infinity, 56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: agregarProductoActual,
                              label: const Text('Agregar al carrito'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.local_drink),
                            onPressed: _agregarRefresco,
                            label: const Text('Refresco \$30'),
                            style: FilledButton.styleFrom(minimumSize: const Size(160, 56)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.table_bar),
                              onPressed: _crearOModificarMesaDialog,
                              label: Text(ventaMesaId == null
                                  ? 'Guardar en mesa abierta'
                                  : 'Actualizar mesa abierta'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh),
                            onPressed: _seleccionarMesaParaCargar,
                            label: const Text('Cargar mesa'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      if (!isWide)
                        _CarritoPanel(
                          carrito: carrito,
                          total: total,
                          onEditar: _editarItemDialog,
                          onEliminar: (index) {
                            setState(() {
                              carrito.removeAt(index);
                              calcularTotal();
                            });
                          },
                          onCobrar: finalizarVenta,
                          etiquetaMesa: nombreMesaActual,
                        ),
                    ],
                  ),
                ),
              ),

              if (isWide)
                Expanded(
                  flex: 2,
                  child: Container(
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(-2, 0),
                        ),
                      ],
                    ),
                    child: _CarritoPanel(
                      carrito: carrito,
                      total: total,
                      onEditar: _editarItemDialog,
                      onEliminar: (index) {
                        setState(() {
                          carrito.removeAt(index);
                          calcularTotal();
                        });
                      },
                      onCobrar: finalizarVenta,
                      etiquetaMesa: nombreMesaActual,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static Widget _kv(String k, String v, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(color: Colors.black54))),
          Text(v, style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _sectionHeader({required String title, required String subtitle, required IconData icon}) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
        ]),
      ],
    );
  }
}


class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 6,
                height: 28,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.black54)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChipWrap<T> extends StatelessWidget {
  final List<T> options;
  final T? value;
  final ValueChanged<T?> onSelected;

  const _ChipWrap({required this.options, required this.value, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final selected = value == o;
        return ChoiceChip(
          label: Text(o.toString()),
          selected: selected,
          onSelected: (_) => onSelected(selected ? null : o),
        );
      }).toList(),
    );
  }
}

class _CarritoPanel extends StatelessWidget {
  final List<Map<String, dynamic>> carrito;
  final double total;
  final void Function(int index) onEliminar;
  final void Function(int index) onEditar;
  final VoidCallback onCobrar;
  final String? etiquetaMesa;

  const _CarritoPanel({
    required this.carrito,
    required this.total,
    required this.onEliminar,
    required this.onEditar,
    required this.onCobrar,
    required this.etiquetaMesa,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = Supabase.instance.client.auth.currentUser;
    final hora = DateTime.now();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.06))),
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_bag_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  etiquetaMesa == null ? 'Carrito' : 'Carrito — ${etiquetaMesa!}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${carrito.length}',
                  style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: carrito.isEmpty
              ? const Center(child: Text('Tu carrito está vacío', style: TextStyle(color: Colors.black54)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: carrito.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = carrito[i];
                    final toppings = (item['toppings'] as List?)?.cast<String>() ?? [];
                    final isDrink = item['isDrink'] == true;
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: cs.secondaryContainer,
                          child: Text(
                            (i + 1).toString(),
                            style: TextStyle(color: cs.onSecondaryContainer),
                          ),
                        ),
                        title: Text(
                          '${item['base']} — \$${(item['precio'] as num).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: isDrink
                            ? const Text('Bebida', style: TextStyle(color: Colors.black54))
                            : Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text([
                                  'Salsa: ${item['salsa'] ?? '-'}',
                                  'Proteína: ${item['proteina'] ?? '-'}',
                                  if (item['huevoTipo'] != null) 'Huevo: ${item['huevoTipo']}',
                                  if (item['especialidad'] != null) 'Especialidad: ${item['especialidad']}',
                                  'Toppings: ${toppings.isEmpty ? '-' : toppings.join(', ')}',
                                  'Extras: ${(item['extras'] as List).isEmpty ? '-' : (item['extras'] as List).map((e) => e['nombre']).join(', ')}',
                                ].join('\n')),
                              ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Editar',
                              onPressed: () => onEditar(i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Eliminar',
                              onPressed: () => onEliminar(i),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total: \$${total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Usuario: ${user?.email ?? '-'}'),
                    Text('Hora: ${hora.hour}:${hora.minute.toString().padLeft(2, '0')}'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.payments),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onCobrar,
                label: const Text('Cobrar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class CobroResultado {
  final bool aplicarDescuento;
  final String metodoPago;
  final double? montoRecibido;
  final double cambio;
  final double totalFinal;

  CobroResultado({
    required this.aplicarDescuento,
    required this.metodoPago,
    required this.montoRecibido,
    required this.cambio,
    required this.totalFinal,
  });
}

enum _MesaAccion { guardar }
