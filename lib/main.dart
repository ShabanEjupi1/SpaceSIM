/// SpaceSIM — blerje pakosh eSIM për udhëtim.
///
/// 🔑 Furnizuesi zgjidhet KËTU dhe askund tjetër. Sot është i simuluar; kur të
/// vijë çelësi i vërtetë, ndërrohet ky rresht i vetëm.
library;

import 'package:flutter/material.dart';

import 'furnizuesi/furnizuesi.dart';
import 'pamja/faqja_kryesore.dart';
import 'te_dhena/katalogu.dart';
import 'te_dhena/ruajtja.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final katalogu = await Katalogu.nga();
  final ruajtja = await Ruajtja.hap();
  runApp(SpaceSim(
    katalogu: katalogu,
    ruajtja: ruajtja,
    furnizuesi: FurnizuesISimuluar(),
  ));
}

class SpaceSim extends StatelessWidget {
  const SpaceSim({
    super.key,
    required this.katalogu,
    required this.ruajtja,
    required this.furnizuesi,
  });

  final Katalogu katalogu;
  final Ruajtja ruajtja;
  final Furnizuesi furnizuesi;

  static const seed = Color(0xFF1F6F5C);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpaceSIM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: FaqjaKryesore(
        katalogu: katalogu,
        ruajtja: ruajtja,
        furnizuesi: furnizuesi,
      ),
    );
  }
}
