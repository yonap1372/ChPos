class MenuProteina {
final int id;
final String nombre;


MenuProteina({required this.id, required this.nombre});


factory MenuProteina.fromMap(Map<String, dynamic> map) {
return MenuProteina(
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