class ResumenPunto {
  final DateTime periodo;
  final int numeroVentas;
  final double totalVentas;
  final double totalDescuentos;
  final double totalCambio;
  final int productosVendidos;

  ResumenPunto({
    required this.periodo,
    required this.numeroVentas,
    required this.totalVentas,
    required this.totalDescuentos,
    required this.totalCambio,
    required this.productosVendidos,
  });

  factory ResumenPunto.fromMap(Map<String, dynamic> m) => ResumenPunto(
    periodo: DateTime.parse(m['periodo']),
    numeroVentas: (m['numero_ventas'] ?? 0) as int,
    totalVentas: (m['total_ventas'] ?? 0).toDouble(),
    totalDescuentos: (m['total_descuentos'] ?? 0).toDouble(),
    totalCambio: (m['total_cambio'] ?? 0).toDouble(),
    productosVendidos: (m['productos_vendidos'] ?? 0) as int,
  );
}

class KVNum {
  final String key;
  final double value;
  KVNum(this.key, this.value);
}

class Breakdowns {
  final List<KVNum> categorias;   // qty por categoría
  final List<KVNum> productos;    // qty por producto
  final List<KVNum> pagos;        // total por método
  final int ventasConDescuento;
  final double totalDescuentos;
  final List<KVNum> horas;        // total por hora

  Breakdowns({
    required this.categorias,
    required this.productos,
    required this.pagos,
    required this.ventasConDescuento,
    required this.totalDescuentos,
    required this.horas,
  });

  factory Breakdowns.fromJson(Map<String, dynamic> j) {
    List<KVNum> parseList(List data, String keyName, String valName) =>
        data.map<KVNum>((e) => KVNum(e[keyName]?.toString() ?? '-', (e[valName] ?? 0).toDouble())).toList();

    final descs = (j['descuentos'] ?? {}) as Map<String, dynamic>;
    return Breakdowns(
      categorias: parseList((j['categorias'] ?? []) as List, 'categoria_base', 'qty'),
      productos:  parseList((j['productos']  ?? []) as List, 'producto_nombre', 'qty'),
      pagos:      parseList((j['pagos']      ?? []) as List, 'metodo_pago', 'total'),
      ventasConDescuento: (descs['ventas_con_descuento'] ?? 0) as int,
      totalDescuentos: (descs['total_descuentos'] ?? 0).toDouble(),
      horas:      parseList((j['horas']      ?? []) as List, 'hora', 'total'),
    );
  }
}

class SesionCajaResumen {
  final String id;
  final String usuarioId;
  final DateTime apertura;
  final DateTime? cierre;
  final int ventasCount;
  final double totalVentas;
  final double totalCambio;

  SesionCajaResumen({
    required this.id,
    required this.usuarioId,
    required this.apertura,
    required this.cierre,
    required this.ventasCount,
    required this.totalVentas,
    required this.totalCambio,
  });

  factory SesionCajaResumen.fromMap(Map<String, dynamic> m) => SesionCajaResumen(
    id: m['sesion_id'],
    usuarioId: m['usuario_id'],
    apertura: DateTime.parse(m['hora_apertura']),
    cierre: m['hora_cierre'] != null ? DateTime.parse(m['hora_cierre']) : null,
    ventasCount: (m['ventas_count'] ?? 0) as int,
    totalVentas: (m['total_ventas'] ?? 0).toDouble(),
    totalCambio: (m['total_cambio'] ?? 0).toDouble(),
  );
}
