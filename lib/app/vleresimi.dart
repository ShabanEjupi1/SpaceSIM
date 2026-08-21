/// Vlerësimi te Google Play — **In-App Review API**, i njëjti skedar te ÇDO
/// aplikacion Flutter i SpaceCode-it.
///
/// 🚨 Ky skedar është KOPJE. Burimi i vetëm është
/// `linux-install/tools/vleresimi/vleresimi.dart`, dhe vendoset kudo me
/// `python3 linux-install/tools/vleresimi/vendos-vleresimin.py`. Mos e ndrysho
/// kopjen te një aplikacion i vetëm: ndryshimi humbet te vendosja e parë.
///
/// # Pse fare
///
/// Renditja te Play varet nga **numri dhe mesatarja e vlerësimeve** po aq sa
/// nga shkarkimet. Një aplikacion pa asnjë yll nuk del kurrë te «Ngjashëm» dhe
/// nuk fiton kurrë klikimin e parë. Kërkesa brenda aplikacionit është e vetmja
/// rrugë që Google-i e lejon; çdo rrugë tjetër (dritare e jona që pyet «a të
/// pëlqen?», shpërblim për yje, kërkesë me email) është shkelje politike.
///
/// # 🚨 Katër rregullat e Play-it, të shkruara si kod këtu
///
/// 1. **Asnjë shpërblim, asnjë kusht.** Lojtari nuk fiton monedha, nivele apo
///    heqje reklamash sepse vlerësoi. Prandaj [momentiMire] nuk kthen kurrë një
///    vlerë që thirrësi mund ta përdorë për të dhënë diçka.
/// 2. **Asnjë pyetje paraprake.** «A të pëlqen loja?» me dy butona, dhe vetëm
///    të kënaqurit dërgohen te Play-i, është *rating gating* — ndalohet
///    shprehimisht. Kërkesa hapet për këdo, ose për askënd.
/// 3. **Asnjë tekst i yni mbi dritaren.** Dritaren e vizaton Play-i; ne nuk
///    guxojmë ta mbulojmë, ta shpjegojmë me shigjetë, as ta paralajmërojmë.
/// 4. **Kuota është e Google-it, jo e jona.** [requestReview] shpesh **nuk
///    shfaq asgjë** dhe prapë kthehet me sukses. Prandaj ky kod nuk pretendon
///    kurrë se dritarja u pa — ai mban vetëm shënim se u *kërkua*.
///
/// # Kur pyetet
///
/// Vetëm te një **moment i mirë**: niveli u kalua, ndeshja u fitua, porosia
/// mbaroi. Kurrë te nisja, kurrë gjatë lojës, kurrë pas një humbjeje dhe kurrë
/// mbi një ekran ku lojtari po pret diçka.
///
/// Kushtet, të gjitha bashkë:
///
/// | Kushti | Vlera |
/// |---|---|
/// | hapje të aplikacionit | ≥ [_hapjetMin] |
/// | ditë nga hapja e parë | ≥ [_ditetMin] |
/// | momente të mira të numëruara | ≥ [_momentetMin] |
/// | një herë për version | po |
/// | ditë nga kërkesa e fundit | ≥ [_ditetMesKerkesave] |
///
/// 🚨 «Një herë për version» pa kufirin e ditëve nuk mjafton: tri lëshime brenda
/// një jave do të pyesnin tri herë të njëjtin njeri. Dhe kufiri i ditëve pa
/// kufirin e versionit nuk mjafton as ai: një aplikacion që nuk përditësohet do
/// ta rihapte pyetjen përjetë çdo dy muaj. Të dy bashkë, ose asnjëri.
///
/// # Çfarë NUK bën
///
/// Nuk lexon dhe nuk dërgon asgjë: as identifikues, as yje, as nëse dikush
/// vlerësoi. Play-i nuk na e thotë këtë, dhe pikërisht ajo mungesë e mbron
/// lojtarin. Gjithçka që di ky skedar rri te `SharedPreferences` e pajisjes.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Vleresimi {
  Vleresimi._();

  // ── Kufijtë. Ndryshohen KËTU, jo te thirrësit. ──────────────────────────────
  static const int _hapjetMin = 3;
  static const int _ditetMin = 2;
  static const int _momentetMin = 3;
  static const int _ditetMesKerkesave = 90;

  // ── Çelësat te SharedPreferences. Parashtesa `vleresimi_` i mban larg
  //    çelësave të vetë aplikacionit; asnjë prej tyre nuk përmban të dhëna. ───
  static const String _kHapjet = 'vleresimi_hapjet';
  static const String _kMomentet = 'vleresimi_momentet';
  static const String _kEPara = 'vleresimi_hapja_e_pare';
  static const String _kKerkesa = 'vleresimi_kerkesa_e_fundit';
  static const String _kVersioni = 'vleresimi_versioni_i_pyetur';

  /// Versioni i aplikacionit, i vendosur nga [nis].
  ///
  /// Vjen nga `String.fromEnvironment('VERSIONI')` te thirrësi ose nga
  /// `pubspec`-i përmes një konstanteje — jo nga `package_info_plus`. Një paketë
  /// e tërë vetëm për një varg do të ishte varësi e katërt te aplikacione që
  /// mbahen me tri.
  static String _versioni = '';

  static bool _duke = false;

  /// A e ka pranuar aplikacioni fare këtë rrugë.
  ///
  /// `false` te web-i, te desktopi dhe kudo ku Play-i nuk ekziston. Atëherë çdo
  /// thirrje kthehet menjëherë dhe pa gabim.
  static final InAppReview _rishikimi = InAppReview.instance;

  /// Nisja. Thirret një herë te `main`, me `unawaited`, PAS `Ruajtja.hap()`.
  ///
  /// [versioni] duhet të jetë i njëjti varg si te `pubspec.yaml` (p.sh.
  /// `'1.2.1+4'`). Kur ndryshon, lojtari mund të pyetet edhe një herë — një herë
  /// të vetme.
  static Future<void> nis({required String versioni}) async {
    _versioni = versioni;
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setInt(_kHapjet, (p.getInt(_kHapjet) ?? 0) + 1);
      if (p.getInt(_kEPara) == null) {
        await p.setInt(_kEPara, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('vlerësimi nuk u nis: $e');
    }
  }

  /// Një moment i mirë sapo ndodhi: niveli u kalua, ndeshja u fitua, porosia
  /// mbaroi.
  ///
  /// 🚨 Thirret **pasi** ekrani i fitores është i qetë — jo në mes të një
  /// animacioni dhe kurrë bashkë me një reklamë. Dy dritare mbi njëra-tjetrën
  /// e mbyllin njërën pa e parë askush, dhe kuota e Play-it shpenzohet gjithsesi.
  ///
  /// Nuk kthen asgjë me qëllim ([rregulli 1]). Thirrësi nuk mëson dot nëse u
  /// shfaq diçka, ndaj nuk mund t'i japë kurrë shpërblim lojtarit.
  static Future<void> momentiMire() async {
    if (_duke) return;
    _duke = true;
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final int momentet = (p.getInt(_kMomentet) ?? 0) + 1;
      await p.setInt(_kMomentet, momentet);

      if (!_kushtetPlotesohen(p, momentet)) return;
      if (!await _rishikimi.isAvailable()) return;

      // 🚨 Shënimi bëhet PARA kërkesës, jo pas. Nëse `requestReview` rrëzohet
      // ose pajisja fiket në mes, gjendja e mbetur duhet të jetë «u pyet» —
      // përndryshe hapja tjetër e provon prapë, dhe prapë, te i njëjti njeri.
      await p.setInt(_kKerkesa, DateTime.now().millisecondsSinceEpoch);
      if (_versioni.isNotEmpty) await p.setString(_kVersioni, _versioni);

      await _rishikimi.requestReview();
    } catch (e) {
      debugPrint('vlerësimi nuk u kërkua: $e');
    } finally {
      _duke = false;
    }
  }

  static bool _kushtetPlotesohen(SharedPreferences p, int momentet) {
    if (momentet < _momentetMin) return false;
    if ((p.getInt(_kHapjet) ?? 0) < _hapjetMin) return false;

    final int? ePara = p.getInt(_kEPara);
    if (ePara == null) return false;
    final DateTime tani = DateTime.now();
    if (tani.difference(DateTime.fromMillisecondsSinceEpoch(ePara)).inDays <
        _ditetMin) {
      return false;
    }

    // Një herë për version.
    if (_versioni.isNotEmpty && p.getString(_kVersioni) == _versioni) {
      return false;
    }

    final int? efundit = p.getInt(_kKerkesa);
    if (efundit != null &&
        tani.difference(DateTime.fromMillisecondsSinceEpoch(efundit)).inDays <
            _ditetMesKerkesave) {
      return false;
    }
    return true;
  }

  /// Butoni «Vlerëso aplikacionin» te Cilësimet — hap listimin te Play.
  ///
  /// Kjo është rruga e DYTË dhe e ndryshme: e nis vetë lojtari, ndaj s'ka as
  /// kuotë, as kufij, as kushte. Ajo hap dyqanin, jo dritaren e vogël; Play-i e
  /// lejon shprehimisht një lidhje të tillë.
  ///
  /// [idApple] duhet vetëm te iOS-i (numri te App Store Connect). Te Android-i
  /// paketa merret vetvetiu nga vetë aplikacioni.
  static Future<void> hapDyqanin({String? idApple}) async {
    try {
      await _rishikimi.openStoreListing(appStoreId: idApple);
    } catch (e) {
      debugPrint('dyqani nuk u hap: $e');
    }
  }
}
