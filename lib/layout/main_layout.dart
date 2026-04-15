import 'package:control_emap/features/auth/screens/perfil_screen.dart';
import 'package:control_emap/features/misiones/screens/historial_lista_screen.dart';
import 'package:control_emap/features/misiones/screens/historial_mapa_screen.dart';
import 'package:flutter/material.dart';
import '../features/users/screens/users_screen.dart';
import '../features/misiones/screens/solicitar_mision_screen.dart';
import '../core/theme/app_theme.dart';
import '../core/services/session.dart';
import '../core/widgets/custom_app_bar.dart';
import '../features/misiones/screens/bandeja_jefe_screen.dart';

// 👇 IMPORTAMOS LA NUEVA PANTALLA (Ajusta la ruta si la guardaste en otra carpeta)
import '../features/jefe/screens/monitoreo_lista_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  late List<Widget> _pages;
  late List<NavigationDestination> _destinations;
  late List<String> _titulos;

  @override
  void initState() {
    super.initState();
    _configurarMenuPorRol();
  }

  void _configurarMenuPorRol() {
    final rol = Session.rol ?? 'trabajador';

    if (rol == 'admin') {
      _titulos = [
        "Bandeja de Solicitudes",
        "Monitoreo en Vivo",
        "Historial del Equipo",
        "Usuarios",
        "Perfil",
      ];
      _pages = [
        const BandejaJefeScreen(),
        const MonitoreoListaScreen(), // 👈 Ya enlazado
        const HistorialListaScreen(),
        const UsersScreen(),
        const PerfilScreen(),
      ];
      _destinations = const [
        NavigationDestination(
          icon: Icon(Icons.inbox_outlined),
          selectedIcon: Icon(Icons.inbox_rounded),
          label: "Bandeja",
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map_rounded),
          label: "Monitoreo",
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history_rounded),
          label: "Historial",
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people_rounded),
          label: "Usuarios",
        ),

        NavigationDestination(
          icon: Icon(Icons.person_outlined),
          selectedIcon: Icon(Icons.person_rounded),
          label: "Perfil",
        ),
      ];
    } else if (rol == 'jefe') {
      _titulos = [
        "Bandeja de Solicitudes",
        "Monitoreo en Vivo",
        "Historial del Equipo",
        "Usuarios",
        "Perfil",
      ];
      _pages = [
        const BandejaJefeScreen(),
        const MonitoreoListaScreen(), // 👈 Ya enlazado
        const HistorialListaScreen(),
        const UsersScreen(),
        const PerfilScreen(),
      ];
      _destinations = const [
        NavigationDestination(
          icon: Icon(Icons.inbox_outlined),
          selectedIcon: Icon(Icons.inbox_rounded),
          label: "Bandeja",
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map_rounded),
          label: "Monitoreo",
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history_rounded),
          label: "Historial",
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people_rounded),
          label: "Usuarios",
        ),

        NavigationDestination(
          icon: Icon(Icons.person_outlined),
          selectedIcon: Icon(Icons.person_rounded),
          label: "Perfil",
        ),
      ];
    } else {
      // ==========================================================
      // 👷 MODO TRABAJADOR (Con modo espía temporal)
      // ==========================================================
      _titulos = ["Solicitar Salida", "Mi Historial", "Perfil"];
      _pages = [
        const SolicitarMisionScreen(),
        const HistorialListaScreen(),
        const PerfilScreen(),
      ];
      _destinations = const [
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment_rounded),
          label: "Mi Misión",
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history_rounded),
          label: "Historial",
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person_rounded),
          label: "Perfil",
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: _titulos[_selectedIndex]),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: AppTheme.accentYellow,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                );
              }
              return TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.normal,
                fontSize: 13,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(
                  color: AppTheme.primaryGreen,
                  size: 28,
                );
              }
              return IconThemeData(
                color: Colors.white.withValues(alpha: 0.7),
                size: 24,
              );
            }),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: NavigationBar(
            backgroundColor: AppTheme.primaryGreen,
            indicatorColor: AppTheme.accentYellow,
            selectedIndex: _selectedIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: _destinations,
          ),
        ),
      ),
    );
  }
}
