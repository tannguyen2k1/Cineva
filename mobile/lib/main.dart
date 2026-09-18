import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app_router.dart';
import 'src/services/api_client.dart';
import 'src/state/auth_state.dart';
import 'src/theme/cineva_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  final auth = AuthState(api);
  await auth.bootstrap();
  runApp(CinevaApp(api: api, auth: auth));
}

class CinevaApp extends StatelessWidget {
  const CinevaApp({super.key, required this.api, required this.auth});

  final ApiClient api;
  final AuthState auth;

  @override
  Widget build(BuildContext context) {
    final router = createRouter(auth);
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: MaterialApp.router(
        title: 'Cineva',
        debugShowCheckedModeBanner: false,
        theme: buildCinevaTheme(),
        routerConfig: router,
      ),
    );
  }
}
