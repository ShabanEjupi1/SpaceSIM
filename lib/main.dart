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
import 'pagesa/pagesa.dart';
import 'pamja/faqja_kryesore.dart';
import 'te_dhena/katalogu.dart';
import 'te_dhena/ruajtja.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final emrat = await Katalogu.nga();
  final ruajtja = await Ruajtja.hap();

  // ═══════════════════════════════════════════════════════════════════════════
  // 🚨🚨 Katalogu vjen NGA FURNIZUESI, kurrë nga aseti (17-08-2026)
  //
  // Deri sot ekrani i parë mbushej nga `assets/katalogu.json`, i cili e
  // shpallte vetë se çmimet ishin të shpikura — dhe që nga 12-08 aplikacioni
  // shiste me to. Shih [Katalogu.bashko] për matjet.
  //
  // Rendi këtu është zgjedhur për një aplikacion udhëtimi:
  //   1. kopja e ruajtur shfaqet MENJËHERË (edhe pa rrjet, edhe në avion);
  //   2. rrjeti rifreskon në sfond dhe ekrani përditësohet kur mbërrin;
  //   3. vetëm kur s'ka fare kopje pritet rrjeti — sepse atëherë s'ka çfarë
  //      të tregohet.
  final furnizuesi = zgjidhFurnizuesin();
  var katalogu = Katalogu.ngaCache(ruajtja.katalogu(), emrat) ?? emrat;
  final rifreskimi = terhiqKatalogun(emrat: emrat, ruajtja: ruajtja);
  if (katalogu.bosh) {
    // 🚨 Afat: pa të, një rrjet i ngadaltë (aeroport) e mban ekranin e nisjes
    // pa fund. Me të, aplikacioni hapet bosh dhe rifreskimi vazhdon vetë.
    katalogu = await rifreskimi
        .timeout(const Duration(seconds: 12), onTimeout: () => null)
        .then((k) => k ?? emrat);
  }
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
    furnizuesi: furnizuesi,
    pagesa: zgjidhPagesen(),
    rifreskimi: rifreskimi,
  ));
}

/// Tërheq katalogun e vërtetë dhe e ruan. Kthen `null` nëse nuk ia doli.
///
/// 🚨 `null` e jo hedhje gabimi: dështimi këtu është i pritshëm (pa rrjet) dhe
/// nuk guxon ta ndalë nisjen. Kush e thërret vendos vetë ç'të bëjë.
///
/// 🔑 Merren TË DYJA llojet: `local` (paketa për një shtet) dhe `global`
/// (rajonale). Pa `global`, një udhëtar nëpër disa shtete nuk gjen kurrë
/// paketën që i duhet, dhe lista duket e mangët pa asnjë shenjë përse.
Future<Katalogu?> terhiqKatalogun({
  required Katalogu emrat,
  required Ruajtja ruajtja,
}) async {
  if (kRelja.isEmpty) return null;
  try {
    final klienti = KlientiAiralo(
      bazaUrl: kRelja,
      burimi: const ShenjaEAplikacionit(kCelesiIAplikacionit),
      transporti: transportiHttp(),
      marzhaNePerqindje: kMarzha,
    );
    final r = await klienti.katalogu();
    if (r.paketat.isEmpty) return null;
    final k = Katalogu.bashko(
      paketat: r.paketat,
      titujt: r.titujt,
      emrat: emrat,
    );
    await ruajtja.ruajKatalogun(k.teCache(r.titujt));
    return k;
  } catch (_) {
    return null;
  }
}

/// 🔑 I VETMI vend ku zgjidhet pagesa, dhe ai është i njëjti kusht si te
/// [zgjidhFurnizuesin]: pa relenë, nuk ka as furnizues as pagesë. Të dyja
/// mbahen të ndara sepse dështojnë ndryshe — dhe blerësi duhet ta dijë cila
/// nga të dyat mungon.
Pagesa zgjidhPagesen() {
  if (kRelja.isEmpty) return const PagesaEPaLidhur();
  return PagesaPermesReleje(
    bazaUrl: kRelja,
    celesi: kCelesiIAplikacionit,
    transporti: transportiHttp(),
  );
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
        // Marzha rri mbi çmimin NETO, dhe **vetëm** atje: llogaria jonë është
        // te modeli `discount_pricing`, ku i vetmi çmim që kthehet është ai i
        // rekomanduar i Airalo-s. Shih `_euroCenta` te airalo.dart.
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
///
/// 🚨 **0, jo 15** që nga 11-08-2026. Llogaria jonë e vërtetë kthen vetëm
/// `recommended_retail_price` (modeli `discount_pricing`), pra çmimin e shitjes
/// së vetë Airalo-s; fitimi vjen nga zbritja 20% te faturimi. Një marzhë mbi atë
/// numër do ta bënte dyqanin tonë gjithmonë më të shtrenjtë se aplikacioni i
/// Airalo-s — pra pa asnjë arsye për ta zgjedhur. Vlera lexohet prapë nga
/// ndërtimi, po parazgjedhja nuk guxon të jetë ajo që shet mbi listë.
const int kMarzha = int.fromEnvironment('ESIM_MARZHA', defaultValue: 0);

class SpaceSim extends StatelessWidget {
  const SpaceSim({
    super.key,
    required this.katalogu,
    required this.ruajtja,
    required this.furnizuesi,
    required this.pagesa,
    this.rifreskimi,
  });

  final Katalogu katalogu;
  final Ruajtja ruajtja;
  final Furnizuesi furnizuesi;
  final Pagesa pagesa;

  /// Katalogu i freskët, kur të mbërrijë. Shih [terhiqKatalogun].
  final Future<Katalogu?>? rifreskimi;

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
        pagesa: pagesa,
        rifreskimi: rifreskimi,
      ),
    );
  }
}
