class Venta {
  final int id;
  final String usuarioId;
  final int? sesionCajaId;
  final DateTime fecha;
  final double total;
  final String metodoPago;

  Venta({
    required this.id,
    required this.usuarioId,
    this.sesionCajaId,
    required this.fecha,
    required this.total,
    required this.metodoPago,
  });

  Map<String, dynamic> toMap() {
    return {
      'usuario_id': usuarioId,
      'sesion_caja_id': sesionCajaId,
      'fecha': fecha.toIso8601String(),
      'total': total,
      'metodo_pago': metodoPago,
    };
  }

  factory Venta.fromMap(Map<String, dynamic> map) {
    return Venta(
      id: map['id'],
      usuarioId: map['usuario_id'],
      sesionCajaId: map['sesion_caja_id'],
      fecha: DateTime.parse(map['fecha']),
      total: (map['total'] as num).toDouble(),
      metodoPago: map['metodo_pago'],
    );
  }
}
