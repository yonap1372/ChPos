class MenuExtra {
  final int id;
  final String nombre;
  final double precio;

  MenuExtra({
    required this.id,
    required this.nombre,
    required this.precio,
  });

  factory MenuExtra.fromMap(Map<String, dynamic> map) {
    return MenuExtra(
      id: map['id'] as int,
      nombre: map['nombre'] as String,
      precio: (map['precio'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'precio': precio,
    };
  }
}
