import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ble_mesh/ble_mesh.dart';
import 'screens/home_screen.dart';
import 'services/peer_discovery_service.dart';
import 'services/chat_service.dart';
import 'services/mesh_events_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create BleMesh instance
    final bleMesh = BleMesh();

    return MultiProvider(
      providers: [
        // Provide BleMesh instance
        Provider<BleMesh>.value(value: bleMesh),

        // Provide services as ChangeNotifiers
        ChangeNotifierProvider<PeerDiscoveryService>(
          create: (_) => PeerDiscoveryService(bleMesh),
        ),
        ChangeNotifierProvider<ChatService>(
          create: (_) => ChatService(bleMesh),
        ),
        ChangeNotifierProvider<MeshEventsService>(
          create: (_) => MeshEventsService(bleMesh),
        ),
      ],
      child: MaterialApp(
        title: 'BLE Mesh Example',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: const HomeScreen(),
      ),
    );
  }
}
