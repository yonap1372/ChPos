class ReporteVentas {
  final DateTime fecha;
  final double totalVentas;
  final double totalDescuentos;
  final double totalCambio;
  final int numeroVentas;
  final int productosVendidos;
  final String vendedor;
  final DateTime? horaApertura;
  final DateTime? horaCierre;

  ReporteVentas({
    required this.fecha,
    required this.totalVentas,
    required this.totalDescuentos,
    required this.totalCambio,
    required this.numeroVentas,
    required this.productosVendidos,
    required this.vendedor,
    this.horaApertura,
    this.horaCierre,
  });

  factory ReporteVentas.fromMap(Map<String, dynamic> map) {
    return ReporteVentas(
      fecha: DateTime.parse(map['fecha']),
      totalVentas: (map['total_ventas'] ?? 0).toDouble(),
      totalDescuentos: (map['total_descuentos'] ?? 0).toDouble(),
      totalCambio: (map['total_cambio'] ?? 0).toDouble(),
      numeroVentas: map['numero_ventas'] ?? 0,
      productosVendidos: map['productos_vendidos'] ?? 0,
      vendedor: map['vendedor'] ?? '',
      horaApertura: map['hora_apertura'] != null
          ? DateTime.parse(map['hora_apertura'])
          : null,
      horaCierre: map['hora_cierre'] != null
          ? DateTime.parse(map['hora_cierre'])
          : null,
    );
  }
}
