/// Furnizuesi i vërtetë: **Airalo Partner API** (REST).
///
/// Shkruar më 10-08-2026, pasi Guy Dor (Partnerships Manager te Airalo) dërgoi
/// modelet e partneritetit dhe zgjodhëm REST API-në — SDK-ja e tyre ekziston
/// vetëm për PHP dhe Node.js, kurse klienti ynë është Dart.
///
/// Dokumentimi: <https://developers.partners.airalo.com/>
///   POST /v2/token              — client_credentials → `data.access_token`
///   GET  /v2/packages           — katalogu, me `filter[type]`, `limit`, `page`
///   POST /v2/orders             — blerja → `data.sims[].lpa` + `iccid`
///   GET  /v2/sims/{iccid}/usage — `remaining` në **megabajt**
///
/// ⛔ **Ende pa çelësa.** Marrëveshja e API-së nuk është nënshkruar, ndaj as
/// sandbox-i nuk ekziston. Ky skedar është shkruar kundër dokumentimit dhe
/// provohet me një transport të rremë; ditën që vijnë çelësat ndryshon vetëm
/// konfigurimi. Kjo është pikërisht ajo që i premtova Airalo-s («ditë, jo muaj»).
///
/// ## 🚨🚨 `client_secret` NUK hyn kurrë te aplikacioni
///
/// Një APK shpërbëhet për dy minuta. Një `client_secret` brenda tij do të thotë
/// se kushdo mund të porosisë paketa mbi bilancin tonë — pra humbje parash e
/// drejtpërdrejtë, jo «rrjedhje të dhënash». Prandaj:
///
/// - te **lëshimi** aplikacioni flet me relenë tonë — `bazaUrl` i saj, çelës i
///   vetë aplikacionit ([ShenjaEAplikacionit]) — dhe relaja i vendos vetë
///   kredencialet e Airalo-s. Shtigjet mbeten të njëjta, ndaj klienti nuk
///   ndryshon fare;
/// - [CelesatAiralo] (client_id + secret të drejtpërdrejtë) përdoret **vetëm**
///   nga vegla e importit të katalogut dhe nga vetë relaja — kod që rri te kutia.
///
/// [FurnizuesiAiralo] nuk e di se cila prej të dyjave është: të dyja janë
/// [BurimiIShenjes]. Kështu i njëjti klient provohet pa rrjet dhe vendoset pa
/// ndryshuar asnjë rresht.
library;

import 'dart:async';
import 'dart:convert';

import '../modele/modele.dart';
import 'furnizuesi.dart';

/// Përgjigje e zhveshur e HTTP-së — sa i duhet këtij skedari.
class PergjigjeHttp {
  const PergjigjeHttp(this.kodi, this.trupi, {this.kokat = const {}});

  final int kodi;
  final String trupi;
  final Map<String, String> kokat;

  bool get eMire => kodi >= 200 && kodi < 300;

  Map<String, dynamic> get json =>
      (jsonDecode(trupi) as Map).cast<String, dynamic>();
}

/// Transporti. Një funksion, jo një klasë: prova e zëvendëson me një mbyllje
/// prej tre rreshtash, pa asnjë varësi dhe pa asnjë rrjet.
typedef Transporti = Future<PergjigjeHttp> Function(
  String metoda,
  Uri adresa, {
  Map<String, String> kokat,
  Map<String, String>? forma,
});

/// Nga vjen shenja `Bearer`.
abstract class BurimiIShenjes {
  /// Shenja e vlefshme tani. Zbatimi kujdeset vetë për ruajtjen dhe rifreskimin.
  Future<String> shenja();

  /// Hiq shenjën e ruajtur — thirret kur serveri kthen 401, që përpjekja
  /// tjetër të marrë një të re në vend që të dështojë përgjithmonë.
  void harro();
}

/// Çelësat e drejtpërdrejtë të partnerit.
///
/// 🚨 Vetëm për kod që rri te serveri (relaja, importuesi i katalogut). Mos e
/// përdor te aplikacioni — shih shënimin te kreu i skedarit.
class CelesatAiralo implements BurimiIShenjes {
  CelesatAiralo({
    required this.clientId,
    required this.clientSecret,
    required this.transporti,
    this.bazaUrl = prodhimi,
  });

  static const prodhimi = 'https://partners-api.airalo.com';

  final String clientId;
  final String clientSecret;
  final Transporti transporti;
  final String bazaUrl;

  String? _shenja;
  DateTime? _skadon;

  /// 🚨 `/v2/token` lejon vetëm **3 kërkesa në minutë**, kurse shenja jeton 24
  /// orë. Pra ruajtja nuk është optimizim: pa të, dhjetë blerje njëkohësisht e
  /// bllokojnë llogarinë për një minutë. Pragu prej 60 s heq garën me orën e
  /// serverit — një shenjë që skadon gjatë fluturimit të kërkesës do të kthente
  /// 401 pikërisht te blerja e paguar.
  @override
  Future<String> shenja() async {
    final tani = DateTime.now();
    final ruajtur = _shenja;
    if (ruajtur != null &&
        _skadon != null &&
        _skadon!.isAfter(tani.add(const Duration(seconds: 60)))) {
      return ruajtur;
    }

    final p = await transporti(
      'POST',
      Uri.parse('$bazaUrl/v2/token'),
      kokat: const {'Accept': 'application/json'},
      forma: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': 'client_credentials',
      },
    );
    if (!p.eMire) {
      throw GabimFurnizuesi(
        'Nuk u mor leja nga furnizuesi (${p.kodi}).',
        rikthyeshem: p.kodi >= 500 || p.kodi == 429,
      );
    }
    final d = (p.json['data'] as Map).cast<String, dynamic>();
    _shenja = d['access_token'] as String;
    _skadon = tani.add(Duration(seconds: (d['expires_in'] as num?)?.toInt() ?? 86400));
    return _shenja!;
  }

  @override
  void harro() {
    _shenja = null;
    _skadon = null;
  }
}

/// Çelësi i vetë aplikacionit, i njohur nga relaja jonë.
///
/// 🚨🚨 **Relaja nuk guxon të japë kurrë shenjën e Airalo-s.** Tundimi ishte të
/// bëhej pikërisht ajo — «e fshehta rri te serveri, aplikacioni merr vetëm një
/// shenjë» — dhe ajo nuk zgjidh asgjë: shenja e partnerit ka **të njëjtat të
/// drejta** si `client_secret`-i, pra kush e nxjerr nga paketa porosit paketa
/// mbi bilancin tonë. Prandaj relaja **ndërmjetëson**, nuk shpërndan: te
/// [KlientiAiralo] i jepet `bazaUrl` i relesë, jo i Airalo-s, dhe shtigjet
/// mbeten të njëjta (`/v2/orders`, `/v2/sims/…/usage`).
///
/// Ky çelës nxirret gjithashtu nga paketa — dhe kjo është në rregull, sepse ai
/// **nuk blen asgjë vetë**. Bilancin e mbron relaja: ajo verifikon pagesën para
/// se të porosisë, dhe numëron kërkesat për pajisje.
class ShenjaEAplikacionit implements BurimiIShenjes {
  const ShenjaEAplikacionit(this.celesi);

  final String celesi;

  @override
  Future<String> shenja() async => celesi;

  @override
  void harro() {}
}

/// Klienti REST i Airalo-s. Nuk di asgjë për ekranet — kthen modelet e aplikacionit.
class KlientiAiralo {
  KlientiAiralo({
    required this.burimi,
    required this.transporti,
    this.bazaUrl = CelesatAiralo.prodhimi,
    this.marzhaNePerqindje = 0,
  });

  final BurimiIShenjes burimi;
  final Transporti transporti;
  final String bazaUrl;

  /// Sa i shtohet çmimit neto para se t'i shfaqet blerësit. Airalo jep 20%
  /// zbritje mbi çmimin e listës, ndaj marzha rri **mbi netot**, jo mbi listën.
  final int marzhaNePerqindje;

  Future<Map<String, dynamic>> _kerko(
    String metoda,
    String shtegu, {
    Map<String, String>? forma,
    bool eDyta = false,
  }) async {
    final p = await transporti(
      metoda,
      Uri.parse('$bazaUrl$shtegu'),
      kokat: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${await burimi.shenja()}',
      },
      forma: forma,
    );

    // 🚨 401 nuk është dështim përfundimtar: shenja jeton 24 orë dhe mund të
    // jetë shfuqizuar nga ana e tyre. Provohet EDHE NJË herë me shenjë të re;
    // pa këtë, aplikacioni do të mbetej i vdekur derisa ta rihapte blerësi.
    if (p.kodi == 401 && !eDyta) {
      burimi.harro();
      return _kerko(metoda, shtegu, forma: forma, eDyta: true);
    }
    if (p.kodi == 429) {
      final prit = p.kokat['retry-after'] ?? p.kokat['Retry-After'];
      throw GabimFurnizuesi(
        prit == null
            ? 'Shumë kërkesa. Provo pas pak.'
            : 'Shumë kërkesa. Provo pas $prit sekondash.',
      );
    }
    if (!p.eMire) {
      throw GabimFurnizuesi(
        _mesazhi(p) ?? 'Furnizuesi ktheu gabim (${p.kodi}).',
        // 4xx do të thotë se kërkesa jonë ishte e gabuar — e njëjta kërkesë do
        // të dështojë përsëri. Vetëm 5xx-të kanë kuptim të riprovohen.
        rikthyeshem: p.kodi >= 500,
      );
    }
    return p.json;
  }

  static String? _mesazhi(PergjigjeHttp p) {
    try {
      final m = p.json['meta'];
      if (m is Map && m['message'] is String) return m['message'] as String;
    } catch (_) {}
    return null;
  }

  /// Katalogu i paketave, i kthyer te modeli ynë.
  ///
  /// 🚨 Përgjigjja është **tri nivele** e thellë (shteti → operatori → paketat),
  /// jo një listë e sheshtë. Kodi i shtetit rri te niveli i parë; po ta lexoje
  /// nga paketa, do të dilte bosh dhe katalogu do të mbushej me shtete «».
  Future<List<Paketa>> paketat({String lloji = 'local', int faqja = 1, int sa = 100}) async =>
      (await katalogu(lloji: lloji, faqja: faqja, sa: sa)).paketat;

  /// Paketat **dhe** emrat e shteteve, në një kalim të vetëm.
  ///
  /// 🚨 Emrat duhen bashkë me paketat: relaja kthen mbi 200 shtete, kurse
  /// përkthimet shqip te `assets/emrat.json` mbulojnë vetëm ato më të kërkuarat.
  /// Pa `titujt`, çdo shtet i papërkthyer do të shfaqej te ekrani si kodi i tij
  /// me dy shkronja — pra një listë kodesh, jo një dyqan.
  Future<({List<Paketa> paketat, Map<String, String> titujt})> katalogu({
    String lloji = 'local',
    int faqja = 1,
    int sa = 100,
  }) async {
    final j = await _kerko('GET', '/v2/packages?filter[type]=$lloji&limit=$sa&page=$faqja');
    final dalja = <Paketa>[];
    final titujt = <String, String>{};
    for (final shteti in (j['data'] as List? ?? const [])) {
      final s = (shteti as Map).cast<String, dynamic>();
      final kodi = (s['country_code'] as String? ?? '').toUpperCase();
      final titulli = s['title'] as String?;
      if (kodi.isNotEmpty && titulli != null && titulli.isNotEmpty) {
        titujt[kodi] = titulli;
      }
      for (final operatori in (s['operators'] as List? ?? const [])) {
        final o = (operatori as Map).cast<String, dynamic>();
        final rrjeti = o['title'] as String? ?? '';
        for (final paketa in (o['packages'] as List? ?? const [])) {
          final p = (paketa as Map).cast<String, dynamic>();
          final pk = _paketa(p, kodi, rrjeti);
          if (pk != null) dalja.add(pk);
        }
      }
    }
    return (paketat: dalja, titujt: titujt);
  }

  Paketa? _paketa(Map<String, dynamic> p, String kodiIShtetit, String rrjeti) {
    // ⛔ Paketat pa kufi hidhen tani për tani: modeli ynë e tregon sasinë në GB
    // dhe një `0 GB` do të lexohej si «pa të dhëna», jo si «pa kufi».
    if (p['is_unlimited'] == true) return null;

    final id = p['id']?.toString();
    if (id == null || id.isEmpty) return null;

    // `amount` është në MEGABAJT te API-ja e tyre.
    final mb = (p['amount'] as num?)?.toDouble();
    final dite = (p['day'] as num?)?.toInt();
    if (mb == null || dite == null) return null;

    final c = _euroCenta(p);
    if (c == null) return null;

    return Paketa(
      id: id,
      kodiIShtetit: kodiIShtetit,
      gigabajt: mb / 1024,
      dite: dite,
      // Marzha shtohet VETËM mbi netot. Te modeli `discount_pricing` numri që
      // marrim është vetë çmimi i shitjes i Airalo-s — shih [_euroCenta].
      centa: c.eshteNeto
          ? c.centa + (c.centa * marzhaNePerqindje / 100).round()
          : c.centa,
      rrjetet: rrjeti.isEmpty ? const [] : [rrjeti],
    );
  }

  /// Çmimi në **centa euro**, bashkë me atë që tregon nëse është *neto* (kostoja
  /// jonë) apo çmimi i gatshëm i shitjes.
  ///
  /// 🚨🚨 Airalo ka **dy modele çmimi**, dhe llogaria jonë është te i dyti:
  ///
  /// - `net_price` — përgjigjja mban `prices.net_price.EUR` = kostoja jonë, dhe
  ///   marzha rri mbi të.
  /// - `discount_pricing` — **s'ka fare `net_price`**. Përgjigjja mban vetëm
  ///   `prices.recommended_retail_price.EUR`; zbritja jonë (20%) hiqet te
  ///   faturimi, jo te katalogu. Marzha mbi këtë numër do të thoshte shitje MBI
  ///   çmimin e Airalo-s vetë — pra dyqani ynë do të ishte gjithmonë më i shtrenjtë.
  ///
  /// 🚨 Matur më **11-08-2026** te `partners-api.airalo.com`: përgjigjja e vërtetë
  /// e llogarisë sonë ka **zero** `net_price` te 204 shtetet. Leximi i vjetër
  /// (vetëm `net_price.EUR`) hidhte çdo paketë dhe linte katalogun **bosh**, pa
  /// asnjë gabim — pikërisht dështimi i heshtur që kushton.
  ///
  /// 🚨 Dollarët nuk përdoren kurrë: `price` te niveli i paketës është USD, dhe
  /// një shifër dollarësh e shfaqur me «€» është gabim që e paguan blerësi.
  /// Rrumbullakimi bëhet një herë, te centat: [Paketa.centa] është `int`
  /// pikërisht për këtë.
  static ({int centa, bool eshteNeto})? _euroCenta(Map<String, dynamic> p) {
    final cmimet = p['prices'];
    if (cmimet is! Map) return null;

    final neto = cmimet['net_price'];
    if (neto is Map && neto['EUR'] is num) {
      return (centa: ((neto['EUR'] as num) * 100).round(), eshteNeto: true);
    }

    final lista = cmimet['recommended_retail_price'];
    if (lista is Map && lista['EUR'] is num) {
      return (centa: ((lista['EUR'] as num) * 100).round(), eshteNeto: false);
    }

    return null;
  }
}

/// [Furnizuesi] mbi [KlientiAiralo].
class FurnizuesiAiralo implements Furnizuesi {
  FurnizuesiAiralo(this.klienti, {this.iVerteteVertete = false});

  final KlientiAiralo klienti;

  /// 🟡 Mbetet `false` derisa marrëveshja të ekzistojë VËRTET dhe çelësat të
  /// jenë të prodhimit. Te sandbox-i porositë janë të simuluara — profilet nuk
  /// aktivizohen — ndaj shiriti «PROVË» duhet të rrijë aty edhe kur integrimi
  /// punon. Pikërisht gjendja «punon, por s'kam të drejtë të shes» është ajo ku
  /// shiriti duhet më shumë.
  final bool iVerteteVertete;

  @override
  String get emri => 'Airalo';

  @override
  bool get iVertete => iVerteteVertete;

  @override
  bool get mundBlihet => true;

  @override
  Future<Profili> blej(Paketa paketa,
      {required String porosiaId, String? kapja}) async {
    // 🚨🚨 Pa `pagesa` relaja kthen 402, dhe blerësi lexon «Furnizuesi ktheu
    // gabim (402)» — mesazh që tregon te Airalo për diçka që s'ka arritur kurrë
    // atje. Kontrolli bëhet KËTU që gabimi të flasë shqip dhe të tregojë nga
    // vërtet: te pagesa jonë, jo te furnizuesi i tyre.
    if (kapja == null || kapja.isEmpty) {
      throw const GabimFurnizuesi(
        'Porosia u provua pa pagesë. Kjo është gabim i aplikacionit — '
        'asnjë shumë nuk u mor.',
        rikthyeshem: false,
      );
    }
    final j = await klienti._kerko('POST', '/v2/orders', forma: {
      'quantity': '1',
      'package_id': paketa.id,
      'type': 'sim',
      'pagesa': kapja,
      // 🔑 Porosia jonë shkruhet PARA se të thirret furnizuesi, dhe id-ja e saj
      // dërgohet këtu: kështu një porosi e humbur gjendet te paneli i tyre pa
      // pasur nevojë t'u tregohet ora e saktë.
      'description': porosiaId,
    });

    final d = (j['data'] as Map?)?.cast<String, dynamic>();
    final simet = d?['sims'];
    if (simet is! List || simet.isEmpty) {
      // Paratë kanë ikur dhe profili nuk erdhi: kjo NUK riprovohet vetvetiu, se
      // një riprovë do të porosiste një paketë të dytë mbi të njëjtin pagesë.
      throw const GabimFurnizuesi(
        'Porosia u pranua por profili nuk erdhi. Mos paguaj sërish — na shkruaj.',
        rikthyeshem: false,
      );
    }
    final s = (simet.first as Map).cast<String, dynamic>();
    final lpa = s['lpa'] as String?;
    final iccid = s['iccid'] as String?;
    if (lpa == null || iccid == null) {
      throw const GabimFurnizuesi(
        'Profili erdhi i paplotë. Mos paguaj sërish — na shkruaj.',
        rikthyeshem: false,
      );
    }
    return Profili(
      lpa: lpa.startsWith('LPA:') ? lpa : 'LPA:$lpa',
      iccid: iccid,
      kodiIAktivizimit: s['matching_id'] as String?,
    );
  }

  @override
  Future<double?> gigabajtTeMbetur(Profili profili) async {
    try {
      final j = await klienti._kerko('GET', '/v2/sims/${profili.iccid}/usage');
      final d = (j['data'] as Map?)?.cast<String, dynamic>();
      if (d == null) return null;
      // 🚨 Te paketat pa kufi `remaining` kthen 0 — dhe «0 GB të mbetura» te
      // një paketë pa kufi është pikërisht ankesa që s'duhet shkaktuar.
      if (d['is_unlimited'] == true) return null;
      final mb = (d['remaining'] as num?)?.toDouble();
      return mb == null ? null : mb / 1024;
    } on GabimFurnizuesi {
      // 🔑 Përdorimi është shtesë, jo thelb: kufiri i tyre është një kërkesë çdo
      // 15 minuta për eSIM. Një 429 këtu nuk guxon ta prishë ekranin e profilit
      // — `null` do të thotë «nuk dihet», dhe ndërfaqja atëherë nuk shfaq shifër.
      return null;
    }
  }
}
