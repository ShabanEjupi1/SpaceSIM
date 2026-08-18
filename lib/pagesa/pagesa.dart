/// Pagesa — gjysma që mungonte mes çmimit dhe profilit.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// 🚨🚨 PSE EKZISTON KY SKEDAR (17-08-2026)
///
/// Deri sot [FaqjaPaketave] thërriste drejt `Furnizuesi.blej`, dhe relaja —
/// e shkruar saktë — e refuzonte çdo porosi pa një kapje pagese të verifikuar.
/// Rezultati te telefoni ishte **«Furnizuesi ktheu gabim (402)»**: një mesazh
/// që tregon te Airalo, kurse asgjë nuk kishte shkuar kurrë te Airalo. Shitja
/// ishte e pamundur qysh nga dita e parë, dhe asnjë provë nuk e kapte, sepse
/// të gjitha provat e blerjes përdornin një furnizues të simuluar që s'kërkonte
/// pagesë.
///
/// 🔑 Rregulli që del prej saj: **çdo kontroll sigurie ka një anë tjetër**, dhe
/// nëse ajo anë nuk ekziston, kontrolli nuk dallohet nga një veçori e prishur.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// Rruga, e tëra
///
/// 1. `POST /pagesa/nis`     → relaja krijon porosinë te PayPal-i, kthen `url`
/// 2. blerësi e hap `url`-në te shfletuesi dhe aprovon
/// 3. PayPal-i e kthen te relaja, e cila **kap** pagesën
/// 4. `GET /pagesa/gjendja`  → aplikacioni pyet derisa të dalë `paguar`
/// 5. `POST /v2/orders`      → me identifikuesin e kapjes
///
/// 🚨 Hapi 4 është një **cikël pyetjesh**, jo një pritje e vetme: blerësi mund
/// të mbyllë shfletuesin, të ndërrojë rrjetin, ose të paguajë pas pesë minutash.
/// Asnjë nga këto nuk guxon ta lërë aplikacionin të thotë «dështoi» për një
/// pagesë që ka shkuar.
library;

import 'dart:async';
import 'dart:convert';

import '../furnizuesi/airalo.dart' show PergjigjeHttp, Transporti;
import '../modele/modele.dart';

/// Dështim i pagesës — i NDARË nga [GabimFurnizuesi] me qëllim.
///
/// Blerësi duhet t'i dallojë dy botët: «nuk pagove» (provo sërish, s'ke humbur
/// asgjë) dhe «pagove por profili s'erdhi» (mos paguaj sërish, na shkruaj). Një
/// klasë e vetme gabimi do t'i shkrinte, dhe mesazhi i gabuar te rasti i dytë e
/// bën blerësin të paguajë dy herë.
class GabimPagese implements Exception {
  const GabimPagese(this.mesazhi, {this.anuluar = false});

  final String mesazhi;

  /// Blerësi u tërhoq vetë. Nuk është gabim, ndaj ndërfaqja nuk shfaq të kuqe.
  final bool anuluar;

  @override
  String toString() => mesazhi;
}

/// Një pagesë e nisur: adresa që duhet hapur, dhe shuma e VËRTETË.
///
/// 🚨 `centa` vjen nga relaja, jo nga katalogu i telefonit. Katalogu i pajisjes
/// mund të jetë orë të vjetër; shuma që do të ngarkohet vërtet është ajo që
/// relaja i tha PayPal-it. Ndërfaqja e tregon KËTË numër te butoni i fundit —
/// përndryshe blerësi aprovon një shifër dhe sheh një tjetër te PayPal-i.
class PagesaENisur {
  const PagesaENisur({required this.ref, required this.url, required this.centa});

  final String ref;
  final String url;
  final int centa;

  String get shuma => '${(centa / 100).toStringAsFixed(2)} €';
}

enum GjendjaEPageses { pritet, paguar, anuluar, deshtoi }

abstract class Pagesa {
  /// A mund të paguhet fare. `false` → ndërfaqja nuk shfaq buton blerjeje.
  bool get mundPaguhet;

  /// Krijon pagesën dhe kthen adresën që duhet hapur te shfletuesi.
  Future<PagesaENisur> nis(Paketa paketa);

  /// Gjendja e tanishme e një pagese.
  Future<({GjendjaEPageses gjendja, String? kapja, String? gabimi})> gjendja(String ref);

  /// Pret derisa pagesa të përfundojë. Kthen identifikuesin e kapjes.
  ///
  /// Hidhet [GabimPagese] nëse blerësi anulon, nëse PayPal-i e refuzon, ose
  /// nëse kalon [durimi] pa përgjigje.
  Future<String> prit(
    String ref, {
    Duration durimi = const Duration(minutes: 15),
    Duration hapi = const Duration(seconds: 3),
  });
}

/// Pagesa përmes relesë sonë. Aplikacioni **nuk e prek kurrë PayPal-in vetë**:
/// as `client_id`, as `secret`, as kapja nuk krijohen këtu.
class PagesaPermesReleje implements Pagesa {
  PagesaPermesReleje({
    required this.bazaUrl,
    required this.celesi,
    required this.transporti,
  });

  final String bazaUrl;
  final String celesi;
  final Transporti transporti;

  @override
  bool get mundPaguhet => bazaUrl.isNotEmpty;

  Map<String, String> get _kokat => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $celesi',
      };

  @override
  Future<PagesaENisur> nis(Paketa paketa) async {
    final p = await transporti(
      'POST',
      Uri.parse('$bazaUrl/pagesa/nis'),
      kokat: _kokat,
      forma: {'package_id': paketa.id},
    );
    if (!p.eMire) throw GabimPagese(_mesazhi(p) ?? 'Pagesa nuk u nis (${p.kodi}).');
    final j = p.json;
    final url = j['url'] as String?;
    final ref = j['ref'] as String?;
    if (url == null || ref == null || url.isEmpty || ref.isEmpty) {
      throw const GabimPagese('Relaja nuk ktheu adresë pagese.');
    }
    // 🚨 Rezervë te çmimi i katalogut vetëm nëse relaja nuk e ktheu fare. Një
    // `0` i heshtur do të thoshte «paguaj 0,00 €» te butoni i fundit.
    final cmimi = j['cmimi'];
    final centa = cmimi is num ? (cmimi * 100).round() : paketa.centa;
    return PagesaENisur(ref: ref, url: url, centa: centa);
  }

  @override
  Future<({GjendjaEPageses gjendja, String? kapja, String? gabimi})> gjendja(
      String ref) async {
    final p = await transporti(
      'GET',
      Uri.parse('$bazaUrl/pagesa/gjendja?ref=${Uri.encodeQueryComponent(ref)}'),
      kokat: _kokat,
    );
    if (!p.eMire) throw GabimPagese(_mesazhi(p) ?? 'Gjendja e pagesës (${p.kodi}).');
    final j = p.json;
    final g = switch (j['gjendja']) {
      'paguar' => GjendjaEPageses.paguar,
      'anuluar' => GjendjaEPageses.anuluar,
      'deshtoi' => GjendjaEPageses.deshtoi,
      _ => GjendjaEPageses.pritet,
    };
    return (gjendja: g, kapja: j['kapja'] as String?, gabimi: j['gabimi'] as String?);
  }

  @override
  Future<String> prit(
    String ref, {
    Duration durimi = const Duration(minutes: 15),
    Duration hapi = const Duration(seconds: 3),
  }) async {
    final deri = DateTime.now().add(durimi);
    var deshtimeRadhazi = 0;
    while (DateTime.now().isBefore(deri)) {
      await Future<void>.delayed(hapi);

      // 🚨 VETËM thirrja rri brenda `try`-t, kurse vendimet janë jashtë tij.
      // Fillimisht ishin bashkë, dhe atëherë `catch`-i i dështimeve kalimtare
      // gëlltiste edhe vendimet e mia («anuluar», «paguar pa kapje») — pra
      // përgjigjet përfundimtare numëroheshin si gabime rrjeti dhe cikli
      // vazhdonte deri te afati. Një `try` më i gjerë se ç'duhet e kthen një
      // përgjigje të qartë në pritje pa fund.
      ({GjendjaEPageses gjendja, String? kapja, String? gabimi}) g;
      try {
        g = await gjendja(ref);
        deshtimeRadhazi = 0;
      } catch (_) {
        // Një gabim rrjeti gjatë pritjes NUK e ndal ciklin: blerësi është te
        // shfletuesi, jo te aplikacioni, dhe telefoni sapo ka ndërruar rrjetin
        // (roaming, Wi-Fi i aeroportit). Vetëm disa dështime radhazi janë
        // shenjë e vërtetë se lidhja ka ikur.
        deshtimeRadhazi++;
        if (deshtimeRadhazi >= 10) {
          throw const GabimPagese(
            'Lidhja u ndërpre gjatë pritjes së pagesës. Nëse PayPal-i të ka '
            'ngarkuar, hape sërish aplikacionin — porosia vazhdon vetë.',
          );
        }
        continue;
      }

      switch (g.gjendja) {
        case GjendjaEPageses.paguar:
          final k = g.kapja;
          if (k == null || k.isEmpty) {
            throw const GabimPagese(
              'Pagesa u konfirmua por identifikuesi mungon. Mos paguaj sërish '
              '— na shkruaj te info@spacecode.tech.',
            );
          }
          return k;
        case GjendjaEPageses.anuluar:
          throw const GabimPagese('Pagesa u anulua. Nuk u mor asnjë shumë.',
              anuluar: true);
        case GjendjaEPageses.deshtoi:
          throw GabimPagese(
              'PayPal-i nuk e përfundoi pagesën${g.gabimi == null ? '' : ' (${g.gabimi})'}. '
              'Nuk u mor asnjë shumë.');
        case GjendjaEPageses.pritet:
          break;
      }
    }
    throw const GabimPagese(
      'Pagesa nuk u konfirmua brenda kohës. Nëse PayPal-i të ka ngarkuar, '
      'na shkruaj te info@spacecode.tech — asnjë porosi nuk u bë.',
    );
  }

  static String? _mesazhi(PergjigjeHttp p) {
    try {
      final j = jsonDecode(p.trupi);
      if (j is Map && j['message'] is String) return j['message'] as String;
    } catch (_) {}
    return null;
  }
}

/// Nuk ka pagesë të lidhur — ndërfaqja e di dhe nuk shfaq buton blerjeje.
class PagesaEPaLidhur implements Pagesa {
  const PagesaEPaLidhur();

  @override
  bool get mundPaguhet => false;

  @override
  Future<PagesaENisur> nis(Paketa paketa) async =>
      throw const GabimPagese('Pagesat ende nuk janë të lidhura.');

  @override
  Future<({GjendjaEPageses gjendja, String? kapja, String? gabimi})> gjendja(
          String ref) async =>
      (gjendja: GjendjaEPageses.deshtoi, kapja: null, gabimi: 'pa pagesë');

  @override
  Future<String> prit(String ref,
          {Duration durimi = const Duration(minutes: 15),
          Duration hapi = const Duration(seconds: 3)}) async =>
      throw const GabimPagese('Pagesat ende nuk janë të lidhura.');
}
