/// Firebase Analytics — dhe rregulli i vetëm që e mban të padëmshëm.
///
/// # 🚨 Çfarë NUK dërgohet, kurrë
///
/// > Asnjë identifikues përdoruesi, asnjë e dhënë e futur nga lojtari, asnjë
/// > parametër fare.
///
/// [ngjarje] pranon **vetëm një emër**. Nuk ka fushë ku të futet një vlerë as
/// gabimisht, as më vonë nga dikush me nxitim. Analytics-i i Google-it është një
/// sistem **reklamash**: të njëjtat të dhëna që matin përdorimin, ndërtojnë
/// profile. Nëse një ditë duhen parametra, ata shtohen këtu me listë të bardhë
/// të shprehur, jo duke hapur `Map<String, Object>`.
///
/// # Kur mungon konfigurimi
///
/// `google-services.json` NUK hyn te depoja (shih `android/app/build.gradle.kts`).
/// Pa të, [nis] dështon në heshtje dhe [gati] mbetet `false`: çdo thirrje tjetër
/// kthehet menjëherë. Aplikacioni punon plotësisht pa Analytics.
///
/// 🚨 Heshtja këtu është e sigurt VETËM sepse gradle-ja bërtet te një ndërtim
/// lëshimi kur skedari mungon. Pa atë roje, kjo klasë do të ishte shtresa e
/// tretë e një dështimi krejt të padukshëm — pikërisht ai që i mbajti katër
/// aplikacione pa asnjë matje deri më 07-08-2026.
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class Analitika {
  Analitika._();

  static FirebaseAnalytics? _analitika;

  /// A u lidh Firebase-i. `false` kur `google-services.json` mungon, kur je te
  /// web-i, ose kur nisja dështoi — dhe asnjëra prej tyre nuk është gabim.
  static bool get gati => _analitika != null;

  /// Nisja. Thirret një herë te `main`, me `unawaited`.
  ///
  /// Nuk hidhet kurrë përjashtim jashtë: një lojë nuk ndalet sepse matja e
  /// përdorimit nuk u lidh.
  static Future<void> nis() async {
    if (_analitika != null) return;
    try {
      await Firebase.initializeApp();
      final FirebaseAnalytics a = FirebaseAnalytics.instance;
      // 🚨 Mbledhja fiket në debug. Pa këtë, çdo hapje gjatë zhvillimit hyn te
      // të njëjtat raporte ku matet përdorimi i vërtetë, dhe shifrat e para
      // dalin dyfish.
      await a.setAnalyticsCollectionEnabled(kReleaseMode);
      _analitika = a;
    } catch (e) {
      debugPrint('analitika nuk u nis: $e');
    }
  }

  /// Një ngjarje, vetëm me emër.
  static Future<void> ngjarje(String emri) async {
    final FirebaseAnalytics? a = _analitika;
    if (a == null) return;
    try {
      await a.logEvent(name: emri);
    } catch (e) {
      debugPrint('ngjarja «$emri» nuk u dërgua: $e');
    }
  }

  /// Emrat e lejuar. Secili përshkruan **që diçka ndodhi**, kurrë çfarë ishte.
  static const String hapja = 'hapja';
  static const String lojaNisi = 'loja_nisi';
  static const String lojaMbaroi = 'loja_mbaroi';
  static const String niveliKaluar = 'niveli_kaluar';
  static const String cilesimet = 'cilesimet';
}
