import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(const TowerAid());
}

class TowerAid extends StatelessWidget {
  const TowerAid({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TowerAid',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
        home: const Home(),
      );
}

enum Role { resident, security, admin }

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _Home();
}

class _Home extends State<Home> {
  Role role = Role.resident;
  int tab = 0;
  String? incident;
  String status = 'ACTIVE';
  RealtimeChannel? _channel;

  final flats = [
    ['901', 'Amit Shah', 'SAFE'],
    ['902', 'Priya Patil', 'SAFE'],
    ['903', 'Rahul Joshi', 'NEED HELP'],
    ['904', 'Sanket Mahajan', 'SAFE'],
    ['905', 'Neha Kulkarni', 'SAFE'],
    ['906', 'Vikram Deshmukh', 'NO RESPONSE']
  ];

  @override
  void initState() {
    super.initState();
    _subscribeToEmergencies();
  }

  void _subscribeToEmergencies() {
    if (!SupabaseConfig.isConfigured) return;
    _channel = Supabase.instance.client
        .channel('toweraid-emergency-alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'emergencies',
          callback: (payload) {
            final row = payload.newRecord;
            if (!mounted) return;
            final type = row['type']?.toString() ?? 'Emergency';
            final flat = row['flat_id']?.toString();
            setState(() => incident = type);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 8),
                content: Text('🚨 $type reported${flat == null ? '' : ' — Flat $flat'}'),
                action: SnackBarAction(label: 'VIEW', onPressed: () => setState(() => tab = 2)),
              ),
            );
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
    super.dispose();
  }

  Widget card(String t, Widget x) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            x,
          ]),
        ),
      );

  Future<void> emergency() async {
    final x = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => Wrap(
        children: ['🔥 Fire', '🚑 Medical', '🛗 Lift', '💨 Gas leak', '⚠️ Accident', '❓ Other']
            .map((e) => ListTile(
                  title: Text(e),
                  onTap: () => Navigator.pop(context, e),
                ))
            .toList(),
      ),
    );
    if (x == null) return;

    if (!SupabaseConfig.isConfigured) {
      setState(() => incident = x);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo emergency activated. Add Supabase keys to send realtime alerts.')),
      );
      return;
    }

    final type = x.replaceFirst(RegExp(r'^\S+\s*'), '').toUpperCase().replaceAll(' ', '_');
    try {
      // Demo society/flat IDs are not available until resident onboarding is built.
      // For now this creates the local demo alert and keeps the realtime listener ready.
      setState(() => incident = x);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase connected. Complete resident/society setup to create the database emergency.')),
      );
      debugPrint('Emergency selected: $type');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Emergency error: $e')));
    }
  }

  Widget resident() {
    if (tab == 1) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        card('🏠 My Flat', const Text('Tower A · Flat 904\nFloor 9 · Sanket Mahajan\nOwner · 2 occupants')),
        card('Emergency contacts', Column(children: [
          ListTile(title: const Text('Society Security'), trailing: FilledButton(onPressed: call, child: const Text('Call'))),
          ListTile(title: const Text('Family emergency contact'), subtitle: const Text('+91 90000 00000'), trailing: FilledButton(onPressed: call, child: const Text('Call'))),
        ])),
      ]);
    }
    if (tab == 2) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        card('Emergency status', Text(incident == null ? 'No active emergency' : '$incident · $status')),
        card('Emergency numbers', Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: call, child: const Text('112')),
          OutlinedButton(onPressed: call, child: const Text('108')),
          OutlinedButton(onPressed: call, child: const Text('101')),
        ])),
      ]);
    }
    if (tab == 3) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        card('Profile', const Text('Sanket Mahajan\n+91 98765 43210\nOwner · Tower A · Flat 904')),
        card('Realtime alerts', Text(SupabaseConfig.isConfigured ? '🟢 Connected — listening for emergencies' : '🟡 Demo mode — Supabase keys not configured')),
      ]);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: const Color(0xff111827), borderRadius: BorderRadius.circular(22)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('YOUR HOME', style: TextStyle(color: Colors.white54)),
          SizedBox(height: 6),
          Text('Tower A · Flat 904', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
          Text('Floor 9 · Sanket Mahajan', style: TextStyle(color: Colors.white70)),
        ]),
      ),
      if (incident != null)
        card('🚨 Active emergency', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$incident · Tower A · Floor 9'),
          Wrap(spacing: 8, children: [
            FilledButton(onPressed: () => setState(() => status = 'SAFE'), child: const Text('🟢 I\'m Safe')),
            OutlinedButton(onPressed: () => setState(() => status = 'NEED HELP'), child: const Text('🔴 I Need Help')),
          ]),
        ])),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton(
        onPressed: emergency,
        style: FilledButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(22)),
        child: const Text('🚨 EMERGENCY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      )),
      const SizedBox(height: 14),
      card('Quick actions', Wrap(spacing: 8, children: [
        OutlinedButton(onPressed: () => setState(() => tab = 1), child: const Text('🏠 My Flat')),
        OutlinedButton(onPressed: call, child: const Text('📞 Security')),
      ])),
    ]);
  }

  Widget security() => ListView(padding: const EdgeInsets.all(16), children: [
        card('🛡️ Security console', Text(incident == null ? 'No active emergency' : '🚨 $incident · Flat 904 · $status')),
        card('Tower A · Floor 9', Wrap(spacing: 8, runSpacing: 8, children: flats.map((f) => SizedBox(width: 145, child: OutlinedButton(
          onPressed: () => inspect(f),
          child: Column(children: [Text(f[0], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(f[2])]),
        ))).toList())),
      ]);

  Widget admin() => ListView(padding: const EdgeInsets.all(16), children: [
        card('👨‍💼 Admin dashboard', const Text('ABC Residency\nMVP society console')),
        Row(children: [Expanded(child: card('512', const Text('Flats'))), Expanded(child: card('486', const Text('Residents')))]),
        Row(children: [Expanded(child: card(incident == null ? '0' : '1', const Text('Active incidents'))), Expanded(child: card('7', const Text('Pending approvals')))]),
        card('Administration', Wrap(spacing: 8, children: ['👥 Residents', '🏢 Buildings', '📋 Reports', '🛡️ Security'].map((x) => OutlinedButton(onPressed: () {}, child: Text(x))).toList())),
      ]);

  void inspect(List<String> f) => showModalBottomSheet(context: context, builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Flat ${f[0]}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(f[1]), Text('Status: ${f[2]}'),
          FilledButton(onPressed: call, child: const Text('📞 Call resident')),
        ]),
      ));

  void call() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calling… (demo)')));

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('🛡️ TowerAid'), actions: [
          PopupMenuButton<Role>(onSelected: (r) => setState(() => role = r), itemBuilder: (_) => const [
            PopupMenuItem(value: Role.resident, child: Text('Resident')),
            PopupMenuItem(value: Role.security, child: Text('Security')),
            PopupMenuItem(value: Role.admin, child: Text('Admin')),
          ]),
        ]),
        body: role == Role.resident ? resident() : role == Role.security ? security() : admin(),
        bottomNavigationBar: role == Role.resident ? NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.apartment), label: 'My Flat'),
            NavigationDestination(icon: Icon(Icons.warning), label: 'Emergency'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ) : null,
      );
}

class SupabaseConfig {
  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
