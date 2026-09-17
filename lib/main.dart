import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const demoSociety = '00000000-0000-0000-0000-000000000001';
const demoBuilding = '00000000-0000-0000-0000-000000000002';
const demoFloor = '00000000-0000-0000-0000-000000000003';
const demoFlat = '00000000-0000-0000-0000-000000000004';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(const TowerAid());
}

SupabaseClient? get sb => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty ? Supabase.instance.client : null;

class TowerAid extends StatelessWidget {
  const TowerAid({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TowerAid',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff073b77)),
        home: const AuthGate(),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final client = sb;
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
  final name = TextEditingController();
  final email = TextEditingController();
  final code = TextEditingController();
  bool register = true;
  bool codeSent = false;
  bool loading = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    code.dispose();
    super.dispose();
  }

  String friendlyError(Object error, {bool verify = false}) {
    final e = error.toString().toLowerCase();
    if (e.contains('failed host lookup') || e.contains('socketexception') || e.contains('network') || e.contains('clientexception')) {
      return 'Unable to connect to TowerAid. Please check your internet connection and try again.';
    }
    if (e.contains('rate limit') || e.contains('too many') || e.contains('429')) {
      return 'Too many attempts. Please wait about 60 seconds and try again.';
    }
    if (e.contains('invalid email')) return 'Please enter a valid email address.';
    if (verify || e.contains('otp') || e.contains('token')) return 'Invalid or expired verification code. Please request a new code.';
    if (e.contains('signup') || e.contains('signups not allowed')) return 'Registration is currently unavailable. Please contact your society administrator.';
    return 'Could not send verification code. Please check your email address and try again.';
  }

  void msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  Future<void> sendCode() async {
    final client = sb;
    final mail = email.text.trim();
    if (client == null) return msg('TowerAid is not configured for this build.');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) return msg('Please enter a valid email address.');
    if (register && name.text.trim().length < 2) return msg('Please enter your full name.');
    setState(() => loading = true);
    try {
      await client.auth.signInWithOtp(
        email: mail,
        shouldCreateUser: register,
        data: register ? {'full_name': name.text.trim()} : null,
      );
      if (mounted) {
        setState(() => codeSent = true);
        msg('Verification code sent to $mail.');
      }
    } catch (e) {
      if (mounted) msg(friendlyError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyCode() async {
    final client = sb;
    if (client == null) return;
    final otp = code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) return msg('Enter the 6-digit verification code.');
    setState(() => loading = true);
    try {
      await client.auth.verifyOTP(email: email.text.trim(), token: otp, type: OtpType.email);
      if (register && client.auth.currentUser != null) {
        try {
          await client.rpc('claim_demo_flat', params: {
            'full_name_input': name.text.trim(),
            'phone_input': email.text.trim(),
          });
        } catch (_) {}
      }
      if (mounted) msg(register ? 'Registration complete. Welcome to TowerAid!' : 'Welcome back to TowerAid.');
    } catch (e) {
      if (mounted) msg(friendlyError(e, verify: true));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 18),
                  SizedBox(height: 190, child: SvgPicture.asset('assets/toweraid_logo.svg', fit: BoxFit.contain)),
                  const SizedBox(height: 12),
                  const Text('Your Society. Our Priority.', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xff073b77))),
                  const SizedBox(height: 8),
                  const Text('Secure access to emergency support and important society contacts.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Register'), icon: Icon(Icons.person_add_outlined)),
                      ButtonSegment(value: false, label: Text('Sign in'), icon: Icon(Icons.login_outlined)),
                    ],
                    selected: {register},
                    onSelectionChanged: loading || codeSent ? null : (v) => setState(() => register = v.first),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(register ? 'Create your resident account' : 'Resident sign in', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(register ? 'Register with your email and verify it with a secure code.' : 'Use your registered email to receive a secure verification code.'),
                          if (register) ...[
                            const SizedBox(height: 18),
                            TextField(controller: name, enabled: !codeSent && !loading, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
                          ],
                          const SizedBox(height: 16),
                          TextField(controller: email, enabled: !codeSent && !loading, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder())),
                          if (codeSent) ...[
                            const SizedBox(height: 16),
                            TextField(controller: code, enabled: !loading, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit verification code', border: OutlineInputBorder())),
                          ],
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: loading ? null : (codeSent ? verifyCode : sendCode),
                              child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(codeSent ? 'Verify & Continue' : (register ? 'Register & Send Code' : 'Send Code')),
                            ),
                          ),
                          if (codeSent) TextButton(onPressed: loading ? null : () => setState(() { codeSent = false; code.clear(); }), child: const Text('Change email address')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Email is used for secure authentication and emergency account identification.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    ['901', 'Amit Shah', 'SAFE'],
    ['902', 'Priya Patil', 'SAFE'],
    ['903', 'Rahul Joshi', 'NEED HELP'],
    ['904', 'Resident', 'SAFE'],
    ['905', 'Neha Kulkarni', 'SAFE'],
    ['906', 'Vikram Deshmukh', 'NO RESPONSE'],
  ];

  @override
  void initState() {
    super.initState();
    final client = sb;
    if (client != null) {
      channel = client.channel('toweraid-emergency-alerts').onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'emergencies',
        callback: (payload) {
          if (!mounted) return;
          final row = payload.newRecord;
          setState(() {
            incident = row['type']?.toString() ?? 'EMERGENCY';
            incidentId = row['id']?.toString();
            status = 'ACTIVE';
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 8), content: Text('🚨 $incident reported — Tower A · Floor 9 · Flat 904')));
        },
      ).subscribe();
    }
  }

  @override
  void dispose() {
    if (channel != null && sb != null) sb!.removeChannel(channel!);
    super.dispose();
  }

  Widget card(String title, Widget child) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10), child])));
  void msg(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  void call() => msg('Calling is available in the production build.');

  Future<void> emergency() async {
    final label = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => Wrap(children: ['🔥 Fire', '🚑 Medical', '🛗 Lift', '💨 Gas leak', '⚠️ Accident', '❓ Other'].map((x) => ListTile(title: Text(x), onTap: () => Navigator.pop(context, x))).toList()),
    );
    if (label == null) return;
    final client = sb;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      setState(() { incident = label; status = 'ACTIVE'; });
      return;
    }
    try {
      await client.rpc('claim_demo_flat', params: {'full_name_input': user.userMetadata?['full_name'] ?? 'TowerAid Resident', 'phone_input': user.email ?? ''});
      final type = label.replaceFirst(RegExp(r'^\S+\s*'), '').toUpperCase().replaceAll(' ', '_');
      final row = await client.from('emergencies').insert({'society_id': demoSociety, 'reported_by': user.id, 'building_id': demoBuilding, 'floor_id': demoFloor, 'flat_id': demoFlat, 'type': type, 'description': 'Emergency activated from TowerAid'}).select('id,type').single();
      if (mounted) {
        setState(() { incident = type; incidentId = row['id'].toString(); status = 'ACTIVE'; });
        msg('🚨 Emergency sent to security.');
      }
    } catch (_) {
      if (mounted) msg('Emergency could not be sent. Please try again.');
    }
  }

  Future<void> respond(String newStatus) async {
    setState(() => status = newStatus);
    final client = sb;
    final user = client?.auth.currentUser;
    if (client == null || user == null || incidentId == null) return;
    try {
      final resident = await client.from('residents').select('id').eq('user_id', user.id).limit(1).single();
      await client.from('emergency_responses').upsert({'emergency_id': incidentId, 'resident_id': resident['id'], 'status': newStatus}, onConflict: 'emergency_id,resident_id');
    } catch (_) {
      if (mounted) msg('Could not update your emergency status. Please try again.');
    }
  }

  Widget resident() {
    if (tab == 1) return ListView(padding: const EdgeInsets.all(16), children: [card('🏠 My Flat', const Text('Tower A · Flat 904\nFloor 9 · Resident')), card('Emergency contacts', Column(children: [ListTile(title: const Text('Society Security'), trailing: FilledButton(onPressed: call, child: const Text('Call'))), ListTile(title: const Text('Emergency contact'), trailing: FilledButton(onPressed: call, child: const Text('Call')))]))]);
    if (tab == 2) return ListView(padding: const EdgeInsets.all(16), children: [card('Emergency status', Text(incident == null ? 'No active emergency' : '$incident · $status')), card('Emergency numbers', Wrap(spacing: 8, children: [OutlinedButton(onPressed: call, child: const Text('112')), OutlinedButton(onPressed: call, child: const Text('108')), OutlinedButton(onPressed: call, child: const Text('101'))]))]);
    if (tab == 3) return ListView(padding: const EdgeInsets.all(16), children: [card('Profile', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${sb?.auth.currentUser?.userMetadata?['full_name'] ?? 'TowerAid Resident'}\nTower A · Flat 904\n${sb?.auth.currentUser?.email ?? ''}'), const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => sb?.auth.signOut(), icon: const Icon(Icons.logout), label: const Text('Sign out'))])), card('Realtime alerts', Text(sb != null ? '🟢 Connected' : '🟡 Demo mode'))]);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xff111827), borderRadius: BorderRadius.circular(22)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('YOUR HOME', style: TextStyle(color: Colors.white54)), SizedBox(height: 6), Text('Tower A · Flat 904', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)), Text('Floor 9 · TowerAid', style: TextStyle(color: Colors.white70))])),
      if (incident != null) card('🚨 Active emergency', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$incident · Tower A · Floor 9'), const SizedBox(height: 8), Wrap(spacing: 8, children: [FilledButton(onPressed: () => respond('SAFE'), child: const Text('🟢 I\'m Safe')), OutlinedButton(onPressed: () => respond('NEED_HELP'), child: const Text('🔴 I Need Help'))])])),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: emergency, style: FilledButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(22)), child: const Text('🚨 EMERGENCY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
      const SizedBox(height: 12),
      card('Emergency Help', const Text('Quick access to emergency support, society contacts and important numbers.')),
    ]);
  }

  Widget security() => ListView(padding: const EdgeInsets.all(16), children: [
    card('🚨 Active emergencies', incident == null ? const Text('No active emergencies') : Text('$incident · ACTIVE · Tower A · Floor 9 · Flat 904')),
    card('Tower A · Floor 9', Column(children: flats.map((f) => ListTile(title: Text('Flat ${f[0]}'), subtitle: Text(f[1]), trailing: Text(f[2], style: TextStyle(fontWeight: FontWeight.bold, color: f[2] == 'NEED HELP' ? Colors.red : null)))).toList())),
  ]);

  Widget admin() => ListView(padding: const EdgeInsets.all(16), children: [
    card('Society dashboard', const Text('TowerAid emergency response overview')),
    card('Buildings', const Text('Tower A · 22 floors')),
    card('Security', const Text('Manage guards and supervisors')),
    card('Emergency settings', const Text('Configure acknowledgement and escalation timers')),
    card('Reports & audit', const Text('Review emergency events and responses')),
  ]);

  @override
  Widget build(BuildContext context) {
    final body = role == Role.resident ? resident() : role == Role.security ? security() : admin();
    return Scaffold(
      appBar: AppBar(
        title: const Text('TowerAid'),
        actions: [
          PopupMenuButton<Role>(
            onSelected: (r) => setState(() { role = r; tab = 0; }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: Role.resident, child: Text('Resident view')),
              PopupMenuItem(value: Role.security, child: Text('Security view')),
              PopupMenuItem(value: Role.admin, child: Text('Admin view')),
            ],
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: role == Role.resident ? NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.apartment_outlined), label: 'My Flat'),
          NavigationDestination(icon: Icon(Icons.warning_amber_outlined), label: 'Emergency'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ) : null,
    );
  }
}
