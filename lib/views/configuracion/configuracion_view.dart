import 'package:flutter/material.dart';

class ConfiguracionView extends StatelessWidget {
  const ConfiguracionView({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Ajustes generales',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              value: true,
              onChanged: (v) {},
              title: const Text('Modo oscuro (pendiente)'),
              secondary: const Icon(Icons.dark_mode),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Datos del negocio'),
              subtitle: const Text('Nombre, dirección, teléfono, etc.'),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Seguridad'),
              subtitle: const Text('Permisos, roles, sesiones'),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
