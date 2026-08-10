/// eSIM Space — mbaj eSIM-et e tua në një vend.
///
/// 🔑 Furnizuesi zgjidhet KËTU dhe askund tjetër. Sot është i simuluar; kur të
/// vijë çelësi i vërtetë, ndërrohet ky rresht i vetëm.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'app/ads.dart';
import 'app/analitika.dart';
import 'furnizuesi/airalo.dart';
import 'furnizuesi/furnizuesi.dart';
import 'furnizuesi/transporti_http.dart';
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
  // Matja nis PARA reklamave: një hapje që dështon te formulari i pëlqimit
  // duhet numëruar prapë, përndryshe humbasin pikërisht hapjet problematike.
  unawaited(Analitika.nis());
  unawaited(Ads.start());
  runApp(SpaceSim(
    katalogu: katalogu,
    ruajtja: ruajtja,
    furnizuesi: zgjidhFurnizuesin(),
  ));
}

/// Adresa e relesë sonë, e dhënë te ndërtimi:
/// `flutter build … --dart-define=ESIM_RELE=https://esim-api.spacecode.tech`
///
/// 🚨 Këtu jepet adresa e **relesë**, kurrë `client_secret`-i i Airalo-s. Një
/// `--dart-define` nuk është vend i fshehtë: vlera shkon fjalë për fjalë te
/// paketa dhe nxirret prej saj për dy minuta. Relaja e mban të fshehtën te
/// serveri; shih `linux-install/esim-rele/` dhe kreun e `furnizuesi/airalo.dart`.
const String kRelja = String.fromEnvironment('ESIM_RELE');

/// Çelësi me të cilin relaja e njeh këtë aplikacion. Nxirret nga paketa — dhe
/// kjo pranohet: ai nuk blen asgjë vetë, sepse relaja porosit vetëm pas një
/// pagese të verifikuar. Shih [ShenjaEAplikacionit].
const String kCelesiIAplikacionit =
    String.fromEnvironment('ESIM_CELESI', defaultValue: 'zhvillim');

/// 🔑 I VETMI vend ku zgjidhet furnizuesi. Tri gjendje, jo dy:
///
/// 1. **relaja e dhënë** → Airalo i vërtetë (dhe kjo është ajo që ndez shitjen);
/// 2. **zhvillim pa rele** → i simuluari, që dështon një në dhjetë me qëllim;
/// 3. **lëshim pa rele** → [FurnizuesIPaLidhur]: çmime orientuese, pa buton
///    blerjeje. Një dyqan që merr para dhe jep profile të rreme nuk është provë,
///    është mashtrim — dhe Play-i e trajton pikërisht ashtu.
Furnizuesi zgjidhFurnizuesin() {
  if (kRelja.isNotEmpty) {
    final transporti = transportiHttp();
    return FurnizuesiAiralo(
      KlientiAiralo(
        // 🔑 `bazaUrl` është relaja jonë, JO `partners-api.airalo.com`: relaja i
        // vendos vetë kredencialet e partnerit dhe verifikon pagesën. Shtigjet
        // janë të njëjta, ndaj klienti nuk e vëren ndryshimin.
        bazaUrl: kRelja,
        burimi: const ShenjaEAplikacionit(kCelesiIAplikacionit),
        transporti: transporti,
        // Marzha rri mbi çmimin NETO (Airalo jep 20% zbritje mbi listën), jo
        // mbi listën — përndryshe do të shitej nën koston tonë.
        marzhaNePerqindje: kMarzha,
      ),
      // 🟡 Shiriti «PROVË» hiqet vetëm kur kjo jepet shprehimisht te ndërtimi,
      // pra kur çelësat janë të PRODHIMIT dhe kontrata ekziston. Te sandbox-i i
      // Airalo-s porositë janë të simuluara: integrimi punon, profilet jo.
      iVerteteVertete: const bool.fromEnvironment('ESIM_PRODHIM'),
    );
  }
  return kDebugMode ? FurnizuesISimuluar() : const FurnizuesIPaLidhur();
}

/// Marzha jonë mbi çmimin neto, në përqindje.
const int kMarzha = int.fromEnvironment('ESIM_MARZHA', defaultValue: 15);

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
