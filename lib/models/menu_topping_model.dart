class MenuTopping {
final int id;
final String nombre;


MenuTopping({required this.id, required this.nombre});


factory MenuTopping.fromMap(Map<String, dynamic> map) {
return MenuTopping(
id: map['id'],
nombre: map['nombre'],
);
}


Map<String, dynamic> toMap() {
return {
'nombre': nombre,
};
}
}