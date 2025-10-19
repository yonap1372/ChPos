class SesionCaja {
  final int id;
  final int usuarioId;
  final DateTime apertura;
  final double montoInicial;
  final DateTime? cierre;
  final double? montoFinal;
  final bool activa;

  SesionCaja({
    required this.id,
    required this.usuarioId,
    required this.apertura,
    required this.montoInicial,
    this.cierre,
    this.montoFinal,
    required this.activa,
  });

  factory SesionCaja.fromMap(Map<String, dynamic> map) => SesionCaja(
        id: map['id'],
        usuarioId: map['usuario_id'],
        apertura: DateTime.parse(map['apertura']),
        montoInicial: (map['monto_inicial'] as num).toDouble(),
        cierre: map['cierre'] != null ? DateTime.parse(map['cierre']) : null,
        montoFinal: map['monto_final'] != null ? (map['monto_final'] as num).toDouble() : null,
        activa: map['activa'],
      );

  Map<String, dynamic> toMap() => {
        'usuario_id': usuarioId,
        'apertura': apertura.toIso8601String(),
        'monto_inicial': montoInicial,
        'cierre': cierre?.toIso8601String(),
        'monto_final': montoFinal,
        'activa': activa,
      };
}
