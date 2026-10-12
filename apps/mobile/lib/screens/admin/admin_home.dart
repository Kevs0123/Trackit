import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import 'dashboard_page.dart';
import 'parcels_page.dart';
import 'reports_page.dart';
import 'riders_page.dart';

/// Courier staff area: Dashboard, Parcels, Riders, Reports.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;

  static const _titles = ['Dashboard', 'Parcels', 'Riders', 'Reports'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.inventory_2_outlined,
    Icons.two_wheeler,
    Icons.bar_chart,
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final wide = MediaQuery.of(context).size.width >= 800;
    final pages = <Widget>[const DashboardPage(), const ParcelsPage(), const RidersPage(), const ReportsPage()];

    return Scaffold(
      appBar: AppBar(
        title: Text('TrackIt  -  ${_titles[_index]}'),
        actions: [
          Center(child: Text(auth.user?.name ?? '')),
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => auth.logout()),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (var i = 0; i < _titles.length; i++)
                  NavigationRailDestination(icon: Icon(_icons[i]), label: Text(_titles[i])),
              ],
            ),
          Expanded(child: KeyedSubtree(key: ValueKey(_index), child: pages[_index])),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (var i = 0; i < _titles.length; i++)
                  NavigationDestination(icon: Icon(_icons[i]), label: _titles[i]),
              ],
            ),
    );
  }
}
