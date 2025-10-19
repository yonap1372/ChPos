class VentaDetalle {
  final int id;
  final int ventaId;
  final String base;
  final String? salsa;
  final String? proteina;
  final String? toppings;
  final double precio;

  VentaDetalle({
    required this.id,
    required this.ventaId,
    required this.base,
    this.salsa,
    this.proteina,
    this.toppings,
    required this.precio,
  });

  Map<String, dynamic> toMap() {
    return {
      'venta_id': ventaId,
      'base': base,
      'salsa': salsa,
      'proteina': proteina,
      'toppings': toppings,
      'precio': precio,
    };
  }

  factory VentaDetalle.fromMap(Map<String, dynamic> map) {
    return VentaDetalle(
      id: map['id'],
      ventaId: map['venta_id'],
      base: map['base'],
      salsa: map['salsa'],
      proteina: map['proteina'],
      toppings: map['toppings'],
      precio: (map['precio'] as num).toDouble(),
    );
  }
}
