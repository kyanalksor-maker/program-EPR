import 'package:flutter/material.dart';

class SetupRequiredPage extends StatelessWidget {
  const SetupRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.settings_ethernet_outlined, size: 44),
                  SizedBox(height: 18),
                  Text(
                    'Supabase Configuration Required',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This build no longer includes demo data. Start the app with real Supabase credentials using --dart-define for SUPABASE_URL and SUPABASE_ANON_KEY, then apply the SQL migration and deploy the employee management edge function.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
