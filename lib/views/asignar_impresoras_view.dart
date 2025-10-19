// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/impresora_service.dart';

class AsignarImpresorasView extends StatefulWidget {
  const AsignarImpresorasView({super.key});

  @override
  State<AsignarImpresorasView> createState() => _AsignarImpresorasViewState();
}

class _AsignarImpresorasViewState extends State<AsignarImpresorasView> {
  List<Map<String, dynamic>> impresoras = [];
  String? seleccionCliente;
  String? seleccionCocina;
  bool cargando = false;

  Future<void> cargarImpresoras() async {
    setState(() => cargando = true);
    final lista = await listarImpresoras();
    setState(() {
      impresoras = lista;
      cargando = false;
    });
  }

  Future<void> guardar() async {
    if (seleccionCliente != null) {
      await guardarAsignacion('cliente', seleccionCliente!);
    }
    if (seleccionCocina != null) {
      await guardarAsignacion('cocina', seleccionCocina!);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Impresoras asignadas correctamente')),
      );
    }
  }

  Future<void> imprimirPrueba(String tipo) async {
    final texto = '''
      --------------------------------
          PRUEBA DE IMPRESORA
      Tipo: ${tipo.toUpperCase()}
      Fecha: ${DateTime.now()}
      --------------------------------
      ¡Impresión exitosa!
      ''';
    final ok = await imprimirTicket(texto, tipo: tipo);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? '🖨️ Impresión de prueba enviada a $tipo.'
              : '⚠️ Error al imprimir en $tipo.'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    cargarImpresoras();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignar Impresoras USB'),
        backgroundColor: Color.fromARGB(255, 212, 153, 14),
        foregroundColor: Colors.white,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : impresoras.isEmpty
              ? const Center(child: Text('No se detectaron impresoras.'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '🖨️ Impresoras detectadas (${impresoras.length}):',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: impresoras.length,
                          itemBuilder: (context, index) {
                            final imp = impresoras[index];
                            final serial = imp['serial'] ?? 'sin_serial';
                            return Card(
                              color: Colors.grey.shade100,
                              child: ListTile(
                                title: Text(imp['name']),
                                subtitle: Text('Serial: $serial'),
                                trailing: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() =>
                                            seleccionCliente = serial);
                                      },
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              seleccionCliente == serial
                                                  ? Color.fromARGB(255, 212, 153, 14)
                                                  : Colors.grey),
                                      child: const Text('Cliente'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() =>
                                            seleccionCocina = serial);
                                      },
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              seleccionCocina == serial
                                                  ? Colors.orange
                                                  : Colors.grey),
                                      child: const Text('Cocina'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: guardar,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar Asignación'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 212, 153, 14),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(thickness: 1.5),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => imprimirPrueba('cliente'),
                            icon: const Icon(Icons.print),
                            label: const Text('Probar Cliente'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(150, 50),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => imprimirPrueba('cocina'),
                            icon: const Icon(Icons.print),
                            label: const Text('Probar Cocina'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(150, 50),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}
