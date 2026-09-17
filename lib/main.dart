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
    if (client == null) return const ResidentAuth();
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (_, __) => client.auth.currentSession == null ? const ResidentAuth() : const Home(),
    );
  }
}

class ResidentAuth extends StatefulWidget {
  const ResidentAuth({super.key});
  @override
  State<ResidentAuth> createState() => _ResidentAuthState();
}

class _ResidentAuthState extends State<ResidentAuth> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final otpController = TextEditingController();
  bool registerMode = true;
  bool otpSent = false;
  bool loading = false;

  String get email => emailController.text.trim();
  String get name => nameController.text.trim();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    otpController.dispose();
    super.dispose();
  }

  void resetOtp() => setState(() {
        otpSent = false;
        otpController.clear();
      });

  Future<void> sendCode() async {
    final client = SupabaseConfig.client;
    if (client == null) return _message('TowerAid is not configured for this build.');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return _message('Enter a valid email address.');
    }
    if (registerMode && name.length < 2) return _message('Enter your full name.');

    setState(() => loading = true);
    try {
      await client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: registerMode,
        data: registerMode ? {'full_name': name} : null,
      );
      if (mounted) {
        setState(() => otpSent = true);
        _message('Verification code sent to $email.');
      }
    } catch (_) {
      if (mounted) _message('Could not reach TowerAid. Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyCode() async {
    final client = SupabaseConfig.client;
    if (client == null) return;
    final code = otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return _message('Enter the 6-digit verification code.');

    setState(() => loading = true);
    try {
      await client.auth.verifyOTP(email: email, token: code, type: OtpType.email);
      if (registerMode && client.auth.currentUser != null) {
        try {
          await client.rpc('claim_demo_flat', params: {
            'full_name_input': name,
            'phone_input': email,
          });
        } catch (_) {}
      }
      if (mounted) _message(registerMode ? 'Registration complete. Welcome to TowerAid!' : 'Welcome back to TowerAid.');
    } catch (_) {
      if (mounted) _message('Invalid or expired code. Please request a new code.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
                      height: 82,
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(24)),
                      child: const Icon(Icons.shield_outlined, color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 28),
                    const Text('TowerAid', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Emergency response for your residential community', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 26),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Register'), icon: Icon(Icons.person_add_outlined)),
                        ButtonSegment(value: false, label: Text('Sign in'), icon: Icon(Icons.login_outlined)),
                      ],
                      selected: {registerMode},
                      onSelectionChanged: loading || otpSent ? null : (s) => setState(() => registerMode = s.first),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(registerMode ? 'Create your resident account' : 'Resident sign in', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(registerMode ? 'Register with your email and verify it with a secure code.' : 'Use your registered email to receive a secure verification code.'),
                            if (registerMode) ...[
                              const SizedBox(height: 20),
                              TextField(
                                controller: nameController,
                                enabled: !otpSent && !loading,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                              ),
                            ],
                            const SizedBox(height: 16),
                            TextField(
                              controller: emailController,
                              enabled: !otpSent && !loading,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'Email address', hintText: 'resident@example.com', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                            ),
                            if (otpSent) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: otpController,
                                enabled: !loading,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: const InputDecoration(labelText: '6-digit verification code', border: OutlineInputBorder()),
                              ),
                            ],
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: loading ? null : (otpSent ? verifyCode : sendCode),
                                child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(otpSent ? 'Verify & Continue' : (registerMode ? 'Register & Send Code' : 'Send Code')),
                              ),
                            ),
                            if (otpSent)
                              TextButton(onPressed: loading ? null : resetOtp, child: const Text('Change email address')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Email is used for secure authentication and emergency account identification.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
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
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Role role = Role.resident;
  int tab = 0;
  String? incident;
  String? incidentId;
  String status = 'ACTIVE';
  RealtimeChannel? channel;

  final flats = const [
    ['901', 'Amit Shah', 'SAFE'], ['902', 'Priya Patil', 'SAFE'], ['903', 'Rahul Joshi', 'NEED HELP'],
    ['904', 'Resident', 'SAFE'], ['905', 'Neha Kulkarni', 'SAFE'], ['906', 'Vikram Deshmukh', 'NO RESPONSE'],
  ];

  @override
  void initState() { super.initState(); _subscribe(); }

  void _subscribe() {
    final client = SupabaseConfig.client;
    if (client == null) return;
    channel = client.channel('toweraid-emergency-alerts').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public', table: 'emergencies',
      callback: (payload) {
        if (!mounted) return;
        final row = payload.newRecord;
        setState(() { incident = row['type']?.toString() ?? 'EMERGENCY'; incidentId = row['id']?.toString(); status = 'ACTIVE'; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 8), content: Text('🚨 $incident reported — Tower A · Floor 9 · Flat 904')));
      },
    ).subscribe();
  }

  @override
  void dispose() { if (channel != null && SupabaseConfig.client != null) SupabaseConfig.client!.removeChannel(channel!); super.dispose(); }

  Widget card(String title, Widget child) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10), child])));

  Future<void> emergency() async {
    final x = await showModalBottomSheet<String>(context: context, builder: (_) => Wrap(children: ['🔥 Fire', '🚑 Medical', '🛗 Lift', '💨 Gas leak', '⚠️ Accident', '❓ Other'].map((e) => ListTile(title: Text(e), onTap: () => Navigator.pop(context, e))).toList()));
    if (x == null) return;
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) { setState(() { incident = x; status = 'ACTIVE'; }); return; }
    try {
      await client.rpc('claim_demo_flat', params: {'full_name_input': user.userMetadata?['full_name'] ?? 'TowerAid Resident', 'phone_input': user.email ?? ''});
      final type = x.replaceFirst(RegExp(r'^\S+\s*'), '').toUpperCase().replaceAll(' ', '_');
      final row = await client.from('emergencies').insert({'society_id': '00000000-0000-0000-0000-000000000001', 'reported_by': user.id, 'building_id': '00000000-0000-0000-0000-000000000002', 'floor_id': '00000000-0000-0000-0000-000000000003', 'flat_id': '00000000-0000-0000-0000-000000000004', 'type': type, 'description': 'Emergency activated from TowerAid'}).select('id,type').single();
      setState(() { incident = type; incidentId = row['id'].toString(); status = 'ACTIVE'; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚨 Emergency sent to security.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Emergency could not be sent: $e'))); }
  }

  Future<void> respond(String newStatus) async {
    setState(() => status = newStatus);
    final client = SupabaseConfig.client; final user = client?.auth.currentUser;
    if (client == null || user == null || incidentId == null) return;
    try {
      final resident = await client.from('residents').select('id').eq('user_id', user.id).limit(1).single();
      await client.from('emergency_responses').upsert({'emergency_id': incidentId, 'resident_id': resident['id'], 'status': newStatus}, onConflict: 'emergency_id,resident_id');
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Response update failed: $e'))); }
  }

  void call() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calling is available in the production build.')));

  Widget resident() {
    if (tab == 1) return ListView(padding: const EdgeInsets.all(16), children: [card('🏠 My Flat', const Text('Tower A · Flat 904\nFloor 9 · Resident')), card('Emergency contacts', Column(children: [ListTile(title: const Text('Society Security'), trailing: FilledButton(onPressed: call, child: const Text('Call'))), ListTile(title: const Text('Emergency contact'), trailing: FilledButton(onPressed: call, child: const Text('Call')))]))]);
    if (tab == 2) return ListView(padding: const EdgeInsets.all(16), children: [card('Emergency status', Text(incident == null ? 'No active emergency' : '$incident · $status')), card('Emergency numbers', Wrap(spacing: 8, children: [OutlinedButton(onPressed: call, child: const Text('112')), OutlinedButton(onPressed: call, child: const Text('108')), OutlinedButton(onPressed: call, child: const Text('101'))]))]);
    if (tab == 3) return ListView(padding: const EdgeInsets.all(16), children: [card('Profile', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${SupabaseConfig.client?.auth.currentUser?.userMetadata?['full_name'] ?? 'TowerAid Resident'}\nTower A · Flat 904\n${SupabaseConfig.client?.auth.currentUser?.email ?? ''}'), const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => SupabaseConfig.client?.auth.signOut(), icon: const Icon(Icons.logout), label: const Text('Sign out'))])), card('Realtime alerts', Text(SupabaseConfig.isConfigured ? '🟢 Connected' : '🟡 Demo mode'))]);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xff111827), borderRadius: BorderRadius.circular(22)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('YOUR HOME', style: TextStyle(color: Colors.white54)), SizedBox(height: 6), Text('Tower A · Flat 904', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)), Text('Floor 9 · TowerAid', style: TextStyle(color: Colors.white70))])),
      if (incident != null) card('🚨 Active emergency', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$incident · Tower A · Floor 9'), const SizedBox(height: 8), Wrap(spacing: 8, children: [FilledButton(onPressed: () => respond('SAFE'), child: const Text('🟢 I\'m Safe')), OutlinedButton(onPressed: () => respond('NEED_HELP'), child: const Text('🔴 I Need Help'))])])),
      const SizedBox(height: 14), SizedBox(width: double.infinity, child: FilledButton(onPressed: emergency, style: FilledButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(22)), child: const Text('🚨 EMERGENCY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
      const SizedBox(height: 14), card('Quick actions', Wrap(spacing: 8, children: [OutlinedButton.icon(onPressed: call, icon: const Icon(Icons.security), label: const Text('Security')), OutlinedButton.icon(onPressed: () => setState(() => tab = 1), icon: const Icon(Icons.home), label: const Text('My Flat')), OutlinedButton.icon(onPressed: () => setState(() => tab = 2), icon: const Icon(Icons.history), label: const Text('History'))])),
    ]);
  }

  Widget security() => ListView(padding: const EdgeInsets.all(16), children: [card('🚨 Active emergencies', incident == null ? const Text('No active emergencies') : Text('$incident · Tower A · Floor 9 · Flat 904')), card('Tower A · Floor 9', Column(children: flats.map((f) => ListTile(leading: CircleAvatar(child: Text(f[0].substring(1))), title: Text('Flat ${f[0]}'), subtitle: Text(f[1]), trailing: Text(f[2], style: TextStyle(fontWeight: FontWeight.bold, color: f[2] == 'NEED HELP' ? Colors.red : null)))).toList()))]);

  Widget admin() => ListView(padding: const EdgeInsets.all(16), children: [card('Society dashboard', const Text('TowerAid emergency response overview')), card('Buildings', const ListTile(title: Text('Tower A'), subtitle: Text('22 floors · Demo configuration'))), card('Security', const ListTile(title: Text('Security team'), subtitle: Text('Manage guards and supervisors'))), card('Emergency settings', const ListTile(title: Text('Escalation'), subtitle: Text('Configure acknowledgement and escalation timers'))), card('Reports & audit', const ListTile(title: Text('Incident history'), subtitle: Text('Review emergency events and responses')))]);

  @override
  Widget build(BuildContext context) {
    final body = role == Role.resident ? resident() : role == Role.security ? security() : admin();
    return Scaffold(
      appBar: AppBar(title: const Text('TowerAid'), actions: [PopupMenuButton<Role>(onSelected: (r) => setState(() { role = r; tab = 0; }), itemBuilder: (_) => const [PopupMenuItem(value: Role.resident, child: Text('Resident view')), PopupMenuItem(value: Role.security, child: Text('Security view')), PopupMenuItem(value: Role.admin, child: Text('Admin view'))])]),
      body: body,
      bottomNavigationBar: role == Role.resident ? NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'), NavigationDestination(icon: Icon(Icons.apartment_outlined), label: 'My Flat'), NavigationDestination(icon: Icon(Icons.warning_amber_outlined), label: 'Emergency'), NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile')]) : null,
    );
  }
}
