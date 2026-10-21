import 'package:flutter/material.dart';

class AccountMenu extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onSignOut;

  const AccountMenu({
    super.key,
    required this.name,
    required this.email,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return PopupMenuButton<String>(
      tooltip: 'Account',
      onSelected: (value) {
        if (value == 'sign_out') onSignOut();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            width: 210,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'sign_out',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20),
              SizedBox(width: 12),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: CircleAvatar(
          radius: 18,
          child: Text(initial,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
