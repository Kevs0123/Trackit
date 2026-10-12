import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models.dart';
import '../../state/auth_state.dart';
import '../../utils.dart';
import '../../widgets/route_dialog.dart';

class RidersPage extends StatefulWidget {
  const RidersPage({super.key});

  @override
  State<RidersPage> createState() => _RidersPageState();
}

class _RidersPageState extends State<RidersPage> {
  List<AppUser> _riders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await context.read<AuthState>().api.get('/riders');
      if (!mounted) return;
      setState(() {
        _riders = (d as List).map((e) => AppUser.fromJson(Map<String, dynamic>.from(e))).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(AppUser r, bool active) async {
    try {
      await context.read<AuthState>().api.put('/riders/${r.id}', {'is_active': active});
      _load();
    } catch (e) {
      if (mounted) showSnack(context, errText(e), error: true);
    }
  }

  Future<void> _addRider() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController();
    String? error;
    bool busy = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: const Text('Add rider'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'Email (login)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password (min 6)', border: OutlineInputBorder()),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: TextStyle(color: Colors.red.shade700)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setS(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await this.context.read<AuthState>().api.post('/riders', {
                          'name': name.text.trim(),
                          'email': email.text.trim(),
                          'phone': phone.text.trim(),
                          'password': password.text,
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } catch (e) {
                        setS(() {
                          busy = false;
                          error = errText(e);
                        });
                      }
                    },
              child: const Text('Add rider'),
            ),
          ],
        ),
      ),
    );

    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRider,
        icon: const Icon(Icons.person_add),
        label: const Text('Add rider'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _riders.isEmpty
                  ? const Center(child: Text('No riders yet. Add your first rider.'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      children: [
                        for (final r in _riders)
                          Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Text(r.name.isEmpty ? '?' : r.name[0].toUpperCase())),
                              title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${r.email}  •  ${r.phone ?? 'no phone'}\n${r.activeParcels} active deliveries'),
                              isThreeLine: true,
                              trailing: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: r.activeParcels == 0
                                        ? null
                                        : () async {
                                            await showRouteDialog(context, riderId: r.id);
                                            _load();
                                          },
                                    icon: const Icon(Icons.route),
                                    label: const Text('Optimize route'),
                                  ),
                                  Tooltip(
                                    message: r.isActive ? 'Active' : 'Deactivated',
                                    child: Switch(value: r.isActive, onChanged: (v) => _toggle(r, v)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}
