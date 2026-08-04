/// eSIM Space — mbaj eSIM-et e tua në një vend.
///
/// 🔑 Furnizuesi zgjidhet KËTU dhe askund tjetër. Sot është i simuluar; kur të
/// vijë çelësi i vërtetë, ndërrohet ky rresht i vetëm.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'app/ads.dart';
import 'furnizuesi/furnizuesi.dart';
import 'pamja/faqja_kryesore.dart';
import 'te_dhena/katalogu.dart';
import 'te_dhena/ruajtja.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final katalogu = await Katalogu.nga();
  final ruajtja = await Ruajtja.hap();
  // 🚨 `unawaited`, jo `await`: nisja e reklamave përfshin formularin e pëlqimit
  // (UMP), pra rrjet. Ky aplikacion hapet pikërisht atëherë kur rrjeti mungon —
  // po ta prisnim, ekrani i parë do të vonohej deri te afati prej 6 sekondash
  // për të parë kodin e vet QR. Shih `lib/app/ads.dart`.
  unawaited(Ads.start());
  runApp(SpaceSim(
    katalogu: katalogu,
    ruajtja: ruajtja,
    // 🔑 Lëshimi NUK shet: një dyqan që merr para dhe jep profile të rreme nuk
    // është provë, është mashtrim. I simuluari mbetet vetëm për zhvillim.
    furnizuesi: kDebugMode ? FurnizuesISimuluar() : const FurnizuesIPaLidhur(),
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
      title: 'eSIM Space',
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
