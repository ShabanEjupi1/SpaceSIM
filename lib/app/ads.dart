/// Reklamat e eSIM Space.
///
/// Të gjitha rregullat rrinë KËTU, në një skedar — njësoj si te Girihu dhe te
/// Shah Mat-i. Shpërndarja e tyre nëpër ekrane e bën pyetjen «sa reklama ka ky
/// aplikacion» të papërgjigjshme, dhe pikërisht ajo pyetje vendos nëse dikush e
/// mban ose e heq.
///
/// **Ky nuk është lojë, dhe politika e reklamave e ndjek atë.** Një lojë ka
/// «raunde»: mes tyre ka një pushim natyror ku një reklamë e plotë nuk pengon
/// asgjë. Një vegël nuk ka raunde — hapet për 20 sekonda pikërisht atëherë kur
/// dikush ka nevojë urgjente për kodin e vet. Prandaj:
///
/// | Ku | Çfarë |
/// |---|---|
/// | poshtë të dy skedave («Blej», «Të miat») | banderolë |
/// | **ekrani i kodit QR** | 🚨 **kurrë asgjë** — shih më poshtë |
/// | **ekrani «Shto eSIM-in tënd»** | asgjë — është një formular |
/// | kthimi PAS mbylljes së kodit QR | interstitial, jo më shpesh se një në 4 minuta |
/// | hapja e aplikacionit | e fikur |
///
/// **Pesë rregulla që nuk shkelen:**
///
/// 1. 🚨🚨 **Asnjë reklamë mbi ekranin e kodit QR.** Ai ekran shihet nga një
///    pajisje e DYTË që po skanon — telefoni nuk e skanon dot ekranin e vet.
///    Një banderolë atje nuk është thjesht bezdi: ajo bie brenda kuadratit që
///    kamera po lexon, dhe skanimi dështon pa e ditur askush pse. E njëjta gjë
///    vlen për një interstitial që hapet vetë mbi të.
/// 2. 🕌 **Filtrim halal në dy vende.** [MaxAdContentRating.g] këtu, plus
///    bllokimi i kategorive te konsola e AdMob-it (bixhoz, alkool, takime,
///    kredi me kamatë). Të dyja duhen: kodi kufizon *klasifikimin*, konsola
///    kufizon *temën*, dhe një reklamë bixhozi mund të jetë fare mirë e
///    klasifikuar «G».
/// 3. 🚨 **Në debug përdoren GJITHMONË njësitë e provës së Google-it.** Një
///    klikim i vetëm mbi njësinë e vërtetë nga vetë zhvilluesi është «trafik i
///    pavlefshëm»: llogaria e AdMob-it mbyllet pa paralajmërim.
/// 4. **Aplikacioni mbetet i plotë pa rrjet.** Reklamat janë e vetmja gjë këtu
///    që prek internetin; katalogu, eSIM-et e ruajtura dhe kodi QR janë vendëse.
///    Kur rrjeti mungon, çdo ngarkim dështon dhe asnjë rrugë nuk e ndien:
///    banderola zë zero hapësirë, interstitial-i anashkalohet.
/// 5. **Reklama nuk zëvendëson shitjen.** Sa kohë `Furnizuesi.mundBlihet` është
///    `false`, ky aplikacion nuk merr para nga askush — dhe një banderolë nuk e
///    ndryshon atë fakt te shiriti i verdhë. Të dyja gjërat janë të vërteta
///    njëkohësisht dhe të dyja tregohen.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class Ads {
  Ads._();

  /// Njësitë e vërteta të eSIM Space-it nga llogaria e AdMob-it
  /// (`credentials.local.txt`, ndarja «esim ads»). Nuk janë sekret: një
  /// identifikues njësie del në çdo kërkesë reklame dhe lexohet nga APK-ja.
  ///
  /// ⚠️ Të katër aplikacionet rrinë nën të njëjtën llogari
  /// (`pub-1776059573171352`) por nën aplikacione të NDRYSHME te AdMob-i, ndaj
  /// identifikuesi i APLIKACIONIT ndryshon: eSIM `~8254149674`, Girih
  /// `~4045126137`, Shah Mat `~3928973421`, Tokërrgjik `~3673667026`. Ai i
  /// eSIM-it rri te `AndroidManifest.xml`. Një identifikues i huaj nuk jep
  /// gabim — jep zero mbushje, që zbulohet vetëm javë më vonë te raportet.
  static const String _bannerLive = 'ca-app-pub-8491001524308476/4711645435';
  static const String _interstitialLive = 'ca-app-pub-8491001524308476/9370588516';

  // Të krijuara te AdMob-i por të PAPËRDORURA me qëllim. Rrinë të shënuara që
  // të mos rikrijohen, dhe që një njësi me zero kërkesa te konsola të ketë
  // shpjegim:
  //   rewarded           ca-app-pub-8491001524308476/8368603230
  //   rewarded interst.  ca-app-pub-8491001524308476/8201082277
  //   native advanced    ca-app-pub-8491001524308476/9234857146
  //   app open           ca-app-pub-8491001524308476/7921775474
  //
  // 🔑 Reklama me shpërblim mungon me QËLLIM: te një lojë shpërblimi është një
  // ndihmë, pra diçka që aplikacioni e ka dhe e jep. Këtu nuk ka asgjë të tillë
  // — çdo «shpërblim» i shpikur do të ishte një funksion i mbajtur peng pas një
  // reklame. App-open është po ashtu e fikur: hapja e këtij aplikacioni do të
  // thotë «më duhet kodi im TANI».

  /// Njësitë e provës së Google-it. Kthejnë gjithmonë një reklamë, kudo, dhe
  /// klikimi mbi to nuk numërohet askund.
  static const String _bannerTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String _interstitialTest = 'ca-app-pub-3940256099942544/1033173712';

  static String get bannerUnit => kReleaseMode ? _bannerLive : _bannerTest;
  static String get interstitialUnit =>
      kReleaseMode ? _interstitialLive : _interstitialTest;

  /// Reklamat ekzistojnë vetëm në Android dhe iOS. I njëjti kod ndërtohet edhe
  /// për web (esim.spacecode.tech), dhe atje `MobileAds.instance` rrëzohet —
  /// ndaj çdo rrugë këtu kalon nga kjo pyetje e vetme. Versioni në internet
  /// mbetet pa asnjë reklamë.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool _ready = false;

  /// A janë reklamat gati. Ekranet e pyesin që të mos lënë vend bosh për diçka
  /// që mund të mos vijë kurrë.
  static bool get ready => _ready;

  /// Nisja. Thirret një herë, para se të hapet ekrani i parë, me `unawaited`.
  ///
  /// Nuk hidhet kurrë përjashtim jashtë: një aplikacion që nuk hapet sepse
  /// rrjeti i reklamave nuk u përgjigj është shkëmbim absurd — sidomos ky, që
  /// hapet pikërisht kur rrjeti mungon.
  static Future<void> start() async {
    if (!supported || _ready) return;
    try {
      await _askConsent();
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          // 🕌 «G» = e përshtatshme për të gjithë. Gjysma e filtrit; gjysma
          // tjetër janë kategoritë e ndjeshme te konsola e AdMob-it.
          maxAdContentRating: MaxAdContentRating.g,
          // Publiku i synuar te Play është 18+ (udhëtim dhe pagesa), pra jo
          // fëmijë. Një «po» këtu do të hiqte identifikuesin e reklamave, do të
          // ulte mbushjen pa nevojë, dhe mbi të gjitha do të ishte deklarim i
          // pasaktë.
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
        ),
      );
      _ready = true;
      preloadInterstitial();
    } catch (e) {
      debugPrint('reklamat nuk u nisën: $e');
    }
  }

  /// Pëlqimi sipas GDPR-së (UMP). Pa këtë, një përdorues në BE merr reklama pa
  /// bazë ligjore — dhe Google-i e ndalon mbushjen për atë pajisje.
  ///
  /// 🚨 Ky aplikacion e ka publikun kryesor **në udhëtim nëpër BE**, ndaj
  /// formulari i pëlqimit këtu nuk është rast skaji: është rasti i zakonshëm.
  static Future<void> _askConsent() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) debugPrint('formulari i pëlqimit: ${error.message}');
          if (!done.isCompleted) done.complete();
        });
      },
      (FormError error) {
        debugPrint('pëlqimi: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    // Nëse UMP-ja nuk përgjigjet fare, aplikacioni vazhdon pa të: më mirë një
    // ekran fillestar pa reklama sesa një ekran fillestar që nuk mbaron kurrë.
    return done.future.timeout(const Duration(seconds: 6), onTimeout: () {});
  }

  // ── interstitial ───────────────────────────────────────────────────────────

  static InterstitialAd? _interstitial;
  static DateTime _lastInterstitial = DateTime.fromMillisecondsSinceEpoch(0);

  /// Sa shpesh guxon të dalë një interstitial. I ekspozuar që testi ta lexojë
  /// dhe të bjerë nëse dikush e ul.
  static const Duration pauzaMesInterstitialeve = Duration(minutes: 4);

  /// Ngarkon paraprakisht reklamën e ndërmjetme. Ngarkimi zgjat sekonda; nëse
  /// nis vetëm në çastin kur duhet shfaqur, ose vonon përdoruesin ose humbet.
  static void preloadInterstitial() {
    if (!_ready || _interstitial != null) return;
    InterstitialAd.load(
      adUnitId: interstitialUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) => _interstitial = ad,
        onAdFailedToLoad: (LoadAdError e) => _interstitial = null,
      ),
    );
  }

  /// Shfaqet kur përdoruesi **mbyll** ekranin e kodit QR — pra kur ka mbaruar
  /// punë, jo kur po e nis.
  ///
  /// 🚨 Rendi ka rëndësi dhe nuk është detaj estetik: nëse kjo thirret para se
  /// të hapet QR-i, reklama del pikërisht mbi kodin që dikush po pret ta skanojë
  /// me telefonin e dytë, ndoshta në aeroport pa rrjet. Pas kthimit, e vetmja
  /// gjë që reklama vonon është një listë.
  static Future<void> maybeShowAfterQr() async {
    if (!_ready) return;
    if (DateTime.now().difference(_lastInterstitial) < pauzaMesInterstitialeve) {
      preloadInterstitial();
      return;
    }

    final InterstitialAd? ad = _interstitial;
    if (ad == null) {
      preloadInterstitial();
      return;
    }
    _interstitial = null;
    _lastInterstitial = DateTime.now();

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError e) {
        ad.dispose();
        preloadInterstitial();
      },
    );
    await ad.show();
  }
}

/// Banderola e poshtme, mbi shiritin e lundrimit.
///
/// E ndarë si widget me gjendjen e vet sepse një `BannerAd` duhet ngarkuar dhe
/// hedhur bashkë me ekranin që e mban; një banderolë e vetme e përbashkët do të
/// mbetej e lidhur me një `BuildContext` të vdekur pas rrotullimit të ekranit.
///
/// Sa kohë reklama nuk është gati, widget-i zë **zero** hapësirë. Një kuti bosh
/// me lartësi 50 pikselë është vend i mbajtur për diçka që mund të mos vijë
/// kurrë (pa internet, në web, ose me pëlqim të refuzuar) — dhe «pa internet»
/// është gjendja e zakonshme e këtij aplikacioni, jo përjashtim.
class BannerSlot extends StatefulWidget {
  const BannerSlot({super.key});

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (!Ads.ready) return;
    final ad = BannerAd(
      adUnitId: Ads.bannerUnit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad _) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError e) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    unawaited(ad.load());
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BannerAd? ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
