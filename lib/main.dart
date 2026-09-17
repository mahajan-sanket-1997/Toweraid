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

class SupabaseConfig {
  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static SupabaseClient? get client => isConfigured ? Supabase.instance.client : null;
}

class TowerAid extends StatelessWidget {
  const TowerAid({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'TowerAid',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
    home: const AuthGate(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = SupabaseConfig.client;
    if (client == null) return const ResidentSignIn();
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = client.auth.currentSession;
        return session == null ? const ResidentSignIn() : const Home();
      },
    );
  }
}

class ResidentSignIn extends StatefulWidget {
  const ResidentSignIn({super.key});
  @override
  State<ResidentSignIn> createState() => _ResidentSignInState();
}

class _ResidentSignInState extends State<ResidentSignIn> {
  final phoneController = TextEditingController();
  final otpController = TextEditingController();
  bool otpSent = false;
  bool loading = false;

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  String get phone {
    final value = phoneController.text.trim();
    if (value.startsWith('+')) return value;
    return '+91${value.replaceAll(RegExp(r'\D'), '')}';
  }

  Future<void> sendOtp() async {
    final client = SupabaseConfig.client;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supabase is not configured for this build.')));
      return;
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid mobile number.')));
      return;
    }
    setState(() => loading = true);
    try {
      await client.auth.signInWithOtp(phone: phone);
      if (mounted) {
        setState(() => otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to your mobile number.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send OTP: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyOtp() async {
    final client = SupabaseConfig.client;
    if (client == null) return;
    if (otpController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the 6-digit OTP.')));
      return;
    }
    setState(() => loading = true);
    try {
      await client.auth.verifyOTP(phone: phone, token: otpController.text.trim(), type: OtpType.sms);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Welcome to TowerAid.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid or expired OTP: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 30),
                Container(
                  width: 82, height: 82,
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(24)),
                  child: const Icon(Icons.shield_outlined, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 28),
                const Text('TowerAid', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Emergency response for your residential community', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 36),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('Resident sign in', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Use your registered mobile number to receive a secure OTP.'),
                      const SizedBox(height: 22),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        enabled: !otpSent && !loading,
                        decoration: const InputDecoration(labelText: 'Mobile number', hintText: '9876543210', prefixText: '+91 ', border: OutlineInputBorder()),
                      ),
                      if (otpSent) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(labelText: '6-digit OTP', border: OutlineInputBorder()),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: loading ? null : (otpSent ? verifyOtp : sendOtp),
                          child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(otpSent ? 'Verify & Continue' : 'Send OTP'),
                        ),
                      ),
                      if (otpSent) ...[
                        const SizedBox(height: 12),
                        TextButton(onPressed: loading ? null : () => setState(() { otpSent = false; otpController.clear(); }), child: const Text('Change mobile number')),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Your phone number is used only for secure authentication and emergency account identification.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    ),
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
  String? incidentId;
  String status = 'ACTIVE';
  String? alertText;
  RealtimeChannel? _channel;

  final flats = [
    ['901', 'Amit Shah', 'SAFE'], ['902', 'Priya Patil', 'SAFE'],
    ['903', 'Rahul Joshi', 'NEED HELP'], ['904', 'Sanket Mahajan', 'SAFE'],
    ['905', 'Neha Kulkarni', 'SAFE'], ['906', 'Vikram Deshmukh', 'NO RESPONSE']
  ];

  @override
  void initState() { super.initState(); _subscribeToEmergencies(); }

  void _subscribeToEmergencies() {
    final client = SupabaseConfig.client;
    if (client == null) return;
    _channel = client.channel('toweraid-emergency-alerts')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public', table: 'emergencies',
        callback: (payload) {
          final row = payload.newRecord;
          if (!mounted) return;
          final type = row['type']?.toString() ?? 'EMERGENCY';
          final id = row['id']?.toString();
          setState(() { incident = type; incidentId = id; status = 'ACTIVE'; alertText = '🚨 $type reported'; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 8),
            content: Text('🚨 $type reported — Tower A · Floor 9 · Flat 904'),
            action: SnackBarAction(label: 'VIEW', onPressed: () => setState(() => tab = 2)),
          ));
        },
      ).subscribe();
  }

  @override
  void dispose() {
    if (_channel != null && SupabaseConfig.client != null) SupabaseConfig.client!.removeChannel(_channel!);
    super.dispose();
  }

  Widget card(String title, Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10), child],
    )),
  );

  Future<void> emergency() async {
    final x = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => Wrap(children: ['🔥 Fire', '🚑 Medical', '🛗 Lift', '💨 Gas leak', '⚠️ Accident', '❓ Other']
        .map((e) => ListTile(title: Text(e), onTap: () => Navigator.pop(context, e))).toList()),
    );
    if (x == null) return;

    final client = SupabaseConfig.client;
    if (client == null) {
      setState(() { incident = x; status = 'ACTIVE'; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo emergency activated. Configure Supabase to send realtime alerts.')));
      return;
    }

    try {
      final type = x.replaceFirst(RegExp(r'^\S+\s*'), '').toUpperCase().replaceAll(' ', '_');
      final user = client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in before activating an emergency.')));
        return;
      }
      await client.rpc('claim_demo_flat', params: {'full_name_input': 'TowerAid Resident', 'phone_input': user.phone ?? ''});
      final row = await client.from('emergencies').insert({
        'society_id': '00000000-0000-0000-0000-000000000001',
        'reported_by': user.id,
        'building_id': '00000000-0000-0000-0000-000000000002',
        'floor_id': '00000000-0000-0000-0000-000000000003',
        'flat_id': '00000000-0000-0000-0000-000000000004',
        'type': type,
        'description': 'Emergency activated from TowerAid',
      }).select('id,type').single();
      setState(() { incident = type; incidentId = row['id'].toString(); status = 'ACTIVE'; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚨 Emergency sent. Security devices listening in realtime.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Emergency could not be sent: $e')));
    }
  }

  Future<void> respond(String newStatus) async {
    setState(() => status = newStatus);
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null || incidentId == null) return;
    try {
      final resident = await client.from('residents').select('id').eq('user_id', user.id).limit(1).single();
      await client.from('emergency_responses').upsert({
        'emergency_id': incidentId, 'resident_id': resident['id'], 'status': newStatus,
      }, onConflict: 'emergency_id,resident_id');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Response update failed: $e')));
    }
  }

  Widget resident() {
    if (tab == 1) return ListView(padding: const EdgeInsets.all(16), children: [
      card('🏠 My Flat', const Text('Tower A · Flat 904\nFloor 9 · Resident\nRealtime emergency monitoring enabled')),
      card('Emergency contacts', Column(children: [
        ListTile(title: const Text('Society Security'), trailing: FilledButton(onPressed: call, child: const Text('Call'))),
        ListTile(title: const Text('Family emergency contact'), subtitle: const Text('+91 90000 00000'), trailing: FilledButton(onPressed: call, child: const Text('Call'))),
      ])),
    ]);
    if (tab == 2) return ListView(padding: const EdgeInsets.all(16), children: [
      card('Emergency status', Text(incident == null ? 'No active emergency' : '$incident · $status${incidentId == null ? '' : '\nIncident: ${incidentId!.substring(0, 8)}'}')),
      card('Emergency numbers', Wrap(spacing: 8, children: [
        OutlinedButton(onPressed: call, child: const Text('112')), OutlinedButton(onPressed: call, child: const Text('108')), OutlinedButton(onPressed: call, child: const Text('101')),
      ])),
    ]);
    if (tab == 3) return ListView(padding: const EdgeInsets.all(16), children: [
      card('Profile', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TowerAid Resident\nTower A · Flat 904'),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () async { await SupabaseConfig.client?.auth.signOut(); }, icon: const Icon(Icons.logout), label: const Text('Sign out')),
      ])),
      card('Realtime alerts', Text(SupabaseConfig.isConfigured ? '🟢 Connected — listening for emergencies' : '🟡 Demo mode — Supabase keys not configured')),
    ]);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xff111827), borderRadius: BorderRadius.circular(22)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('YOUR HOME', style: TextStyle(color: Colors.white54)), SizedBox(height: 6), Text('Tower A · Flat 904', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)), Text('Floor 9 · TowerAid', style: TextStyle(color: Colors.white70)),
      ])),
      if (incident != null) card('🚨 Active emergency', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$incident · Tower A · Floor 9'), const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          FilledButton(onPressed: () => respond('SAFE'), child: const Text('🟢 I\'m Safe')),
          OutlinedButton(onPressed: () => respond('NEED_HELP'), child: const Text('🔴 I Need Help')),
        ]),
      ])),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: emergency, style: FilledButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(22)), child: const Text('🚨 EMERGENCY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
      const SizedBox(height: 14), card('Quick actions', Wrap(spacing: 8, children: [
        OutlinedButton(onPressed: () => setState(() => tab = 1), child: const Text('🏠 My Flat')), OutlinedButton(onPressed: call, child: const Text('📞 Security')),
      ])),
    ]);
  }

  Widget security() => ListView(padding: const EdgeInsets.all(16), children: [
    card('🛡️ Security console', Text(alertText ?? (incident == null ? 'No active emergency' : '🚨 $incident · Flat 904 · $status'))),
    card('Tower A · Floor 9', Wrap(spacing: 8, runSpacing: 8, children: flats.map((f) => SizedBox(width: 145, child: OutlinedButton(onPressed: () => inspect(f), child: Column(children: [Text(f[0], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(f[2])])))).toList())),
  ]);

  Widget admin() => ListView(padding: const EdgeInsets.all(16), children: [
    card('👨‍💼 Admin dashboard', const Text('ABC Residency\nEmergency operations console')),
    Row(children: [Expanded(child: card('512', const Text('Flats'))), Expanded(child: card('486', const Text('Residents')))]),
    Row(children: [Expanded(child: card(incident == null ? '0' : '1', const Text('Active incidents'))), Expanded(child: card('Realtime', const Text('Alerts')))]),
  ]);

  void inspect(List<String> f) => showModalBottomSheet(context: context, builder: (_) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Flat ${f[0]}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text(f[1]), Text('Status: ${f[2]}'), FilledButton(onPressed: call, child: const Text('📞 Call resident')),
  ])));

  void call() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calling… (demo)')));

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('🛡️ TowerAid'), actions: [PopupMenuButton<Role>(onSelected: (r) => setState(() => role = r), itemBuilder: (_) => const [
      PopupMenuItem(value: Role.resident, child: Text('Resident')), PopupMenuItem(value: Role.security, child: Text('Security')), PopupMenuItem(value: Role.admin, child: Text('Admin')),
    ])]),
    body: role == Role.resident ? resident() : role == Role.security ? security() : admin(),
    bottomNavigationBar: role == Role.resident ? NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
      NavigationDestination(icon: Icon(Icons.home), label: 'Home'), NavigationDestination(icon: Icon(Icons.apartment), label: 'My Flat'), NavigationDestination(icon: Icon(Icons.warning), label: 'Emergency'), NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
    ]) : null,
  );
}
