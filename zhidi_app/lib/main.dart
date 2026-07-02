import 'package:flutter/material.dart';
import 'app/owner_app_scope.dart';
import 'app/owner_app_state.dart';
import 'pages/home/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await OwnerAppState.load();
  runApp(ZhidiApp(state: state));
}

class ZhidiApp extends StatelessWidget {
  const ZhidiApp({super.key, this.state});

  final OwnerAppState? state;

  @override
  Widget build(BuildContext context) {
    final ownerState = state;
    if (ownerState == null || !ownerState.ready) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return OwnerAppScope(
      state: ownerState,
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HomePage(),
      ),
    );
  }
}
