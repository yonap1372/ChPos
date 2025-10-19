class MenuCategoria {
final int id;
final String nombre;
final double precio;


MenuCategoria({required this.id, required this.nombre, required this.precio});


factory MenuCategoria.fromMap(Map<String, dynamic> map) {
return MenuCategoria(
id: map['id'],
nombre: map['nombre'],
precio: (map['precio'] as num).toDouble(),
);
}


Map<String, dynamic> toMap() {
return {
'nombre': nombre,
'precio': precio,
};
}
}

