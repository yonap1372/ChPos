import 'package:flutter/material.dart';
//port 'package:chilascas_pos/views/home/home_page.dart';
import 'package:chilascas_pos/views/ventas/realizar_venta_view.dart';
import 'package:chilascas_pos/views/estados/estados_view.dart';
import 'package:chilascas_pos/views/caja/caja_view.dart';
import 'package:chilascas_pos/views/usuarios/usuarios_view.dart';
import 'package:chilascas_pos/views/configuracion/configuracion_view.dart';
import 'package:chilascas_pos/views/impresoras/asignar_impresoras_view.dart';
import 'package:chilascas_pos/views/menu/editar_menu_view.dart';
import 'package:chilascas_pos/views/auth/login_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chilascas POS'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      drawer: const _MenuLateral(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFB100),
              Color(0xFFFFB100),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restaurant, size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Bienvenido a Chilascas POS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuLateral extends StatelessWidget {
  const _MenuLateral();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Drawer(
      backgroundColor: Colors.grey.shade900,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: color),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.restaurant_menu, size: 48, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'Chilascas POS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildMenuItem(
            icon: Icons.home,
            title: 'Inicio',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.point_of_sale,
            title: 'Realizar venta',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RealizarVentaView()),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.query_stats,
            title: 'Estados',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EstadosView()),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.payments,
            title: 'Caja',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CajaView()),
              );
            },
          ),
          const Divider(color: Colors.grey),
          _buildMenuItem(
            icon: Icons.people,
            title: 'Usuarios',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UsuariosView()),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.settings,
            title: 'Configuración',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConfiguracionView()),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.print,
            title: 'Impresoras',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AsignarImpresorasView()),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.restaurant,
            title: 'Editar menú',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditarMenuView()),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.logout,
            title: 'Cerrar sesión',
            iconColor: Colors.red,
            textColor: Colors.red,
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    Color textColor = Colors.white,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(color: textColor),
      ),
      onTap: onTap,
    );
  }
}
