class MenuSalsa {
final int id;
final String nombre;


MenuSalsa({required this.id, required this.nombre});


factory MenuSalsa.fromMap(Map<String, dynamic> map) {
return MenuSalsa(
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

