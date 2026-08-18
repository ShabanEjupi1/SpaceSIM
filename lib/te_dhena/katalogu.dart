/// Katalogu i shteteve dhe i paketave.
///
/// Sot lexohet nga `assets/katalogu.json`; nesër nga furnizuesi. Prandaj
/// ngarkimi është `Future` edhe pse skedari lokal do të kthehej menjëherë —
/// ndryshe çdo ekran do të duhej rishkruar në ditën që burimi ndërrohet.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../modele/modele.dart';

class Katalogu {
  const Katalogu._(this.shtetet, this.paketat);

  final List<Shteti> shtetet;
  final List<Paketa> paketat;

  /// Vetëm përkthimet e emrave. 🚨 Nuk mban asnjë paketë — shih [bashko].
  static Future<Katalogu> nga({String shtegu = 'assets/emrat.json'}) async {
    final teksti = await rootBundle.loadString(shtegu);
    return Katalogu.ngaTeksti(teksti);
  }

  /// E ndarë nga [nga] që testet ta ushqejnë me tekst pa pasur nevojë për një
  /// paketë asetesh.
  factory Katalogu.ngaTeksti(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    final shtetet = (j['shtetet'] as List)
        .map((e) => Shteti.ngaJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
    // `paketat` mungon te `emrat.json` dhe kjo është e rregullt: aty rrinë
    // vetëm përkthimet. Paketat vijnë nga furnizuesi — shih [bashko].
    final paketat = ((j['paketat'] as List?) ?? const [])
        .map((e) => Paketa.ngaJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);

    // 🚨 Një paketë që tregon te një shtet i pashkruar do të dilte si listë
    // bosh te ekrani, pa asnjë gabim — pra do të dukej si «nuk ka oferta».
    // Kapet këtu, ku e sheh zhvilluesi, jo atje ku e sheh blerësi.
    final kodet = {for (final s in shtetet) s.kodi};
    for (final p in paketat) {
      if (!kodet.contains(p.kodiIShtetit)) {
        throw FormatException('Paketa ${p.id} tregon te shteti i panjohur ${p.kodiIShtetit}');
      }
    }
    return Katalogu._(shtetet, paketat);
  }

  /// Katalogu i VËRTETË: paketat nga furnizuesi, emrat shqip nga aseti.
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// 🚨🚨 PSE EKZISTON (17-08-2026) — dhe çfarë shiste aplikacioni deri sot
  ///
  /// `assets/katalogu.json` e thoshte vetë, te fusha e parë: *«Katalogu i
  /// provës … Çmimet janë TË SHPIKURA për provë»*. Nga 12-08-2026 aplikacioni
  /// ishte i lidhur me Airalo-n e vërtetë dhe shiste — po lista që i shfaqej
  /// blerësit mbeti ajo e shpikura. Pasojat, të matura më 17-08:
  ///
  ///  - Çmimi te ekrani: **4,50 €**. Çmimi i vërtetë i asaj pakete: **4,30 €**.
  ///  - Identifikuesi te ekrani: `xk-1-7`. Ai i vërteti: `plisi-7days-1gb`.
  ///    Pra edhe sikur pagesa të punonte, relaja do të kthente
  ///    «paketa nuk gjendet te katalogu» — **pas** pagesës.
  ///  - Emrat e rrjeteve («Vala · IPKO») ishin shkruar me dorë.
  ///
  /// 🔑 Mësimi: një skedar prove i shënuar qartë si i tillë nuk mbron askënd
  /// nëse asgjë nuk e ndalon rrugën e prodhimit ta lexojë. Prandaj tani aseti
  /// mban VETËM përkthimet e emrave (`emrat.json`), pa asnjë çmim dhe pa asnjë
  /// identifikues pakete — s'ka më çfarë të shitet prej tij.
  ///
  /// ⚠️ [titujt] mbulon shtetet që aseti nuk i njeh: Airalo kthen mbi 200,
  /// përkthimet janë ~30. Pa ta, pjesa tjetër do të dilte si kode dyshkronjëshe.
  static Katalogu bashko({
    required List<Paketa> paketat,
    required Map<String, String> titujt,
    required Katalogu emrat,
    String rajoniIPanjohur = 'Të tjera',
  }) {
    final me = <String>{
      for (final p in paketat)
        if (p.kodiIShtetit.isNotEmpty) p.kodiIShtetit
    };
    final njohur = {for (final s in emrat.shtetet) s.kodi: s};
    // Radha e rajoneve ndjek asetin (Ballkani i pari, se aty është blerësi);
    // shtetet e panjohura shkojnë të fundit, sipas alfabetit.
    final shtetet = <Shteti>[
      for (final s in emrat.shtetet)
        if (me.contains(s.kodi)) s,
    ];
    final tjerat = <Shteti>[
      for (final k in me)
        if (!njohur.containsKey(k))
          Shteti(kodi: k, emri: titujt[k] ?? k, rajoni: rajoniIPanjohur),
    ]..sort((a, b) => a.emri.compareTo(b.emri));
    return Katalogu._(
      [...shtetet, ...tjerat],
      [
        for (final p in paketat)
          if (p.kodiIShtetit.isNotEmpty) p
      ],
    );
  }

  /// Katalogu i ruajtur te pajisja, ose `null`.
  ///
  /// 🔑 Ruhet **i vërteti**, jo i shpikuri: ky aplikacion hapet pikërisht atje
  /// ku rrjeti mungon (aeroport, roaming i sapondërruar), ndaj një kopje
  /// vendëse është thelbi i tij. Çmimi i ruajtur mund të vjetrohet, po ajo nuk
  /// dëmton: shuma e vërtetë e pagesës vendoset nga relaja dhe i tregohet
  /// blerësit para se ai të aprovojë — shih [PagesaENisur.centa].
  static Katalogu? ngaCache(String? json, Katalogu emrat) {
    if (json == null || json.isEmpty) return null;
    try {
      final j = jsonDecode(json) as Map<String, dynamic>;
      return bashko(
        paketat: [
          for (final p in (j['paketat'] as List))
            Paketa.ngaJson((p as Map).cast<String, dynamic>())
        ],
        titujt: (j['titujt'] as Map).cast<String, String>(),
        emrat: emrat,
      );
    } catch (_) {
      // Një kopje e prishur nuk guxon ta ndalë nisjen — thjesht nuk përdoret.
      return null;
    }
  }

  String teCache(Map<String, String> titujt) => jsonEncode({
        'titujt': titujt,
        'paketat': [
          for (final p in paketat)
            {
              'id': p.id,
              'shteti': p.kodiIShtetit,
              'gb': p.gigabajt,
              'dite': p.dite,
              'centa': p.centa,
              'rrjetet': p.rrjetet,
            }
        ],
      });

  bool get bosh => paketat.isEmpty;

  List<Paketa> perShtetin(String kodi) {
    final l = paketat.where((p) => p.kodiIShtetit == kodi).toList()
      ..sort((a, b) => a.centa.compareTo(b.centa));
    return l;
  }

  Shteti shteti(String kodi) => shtetet.firstWhere((s) => s.kodi == kodi);

  Paketa paketa(String id) => paketat.firstWhere((p) => p.id == id);

  /// Shtetet e grupuara sipas rajonit, me rajonet sipas radhës së paraqitjes te
  /// skedari — jo alfabetike: Ballkani rri i pari sepse aty është blerësi.
  Map<String, List<Shteti>> sipasRajonit({String kerkim = ''}) {
    final f = kerkim.trim().toLowerCase();
    final out = <String, List<Shteti>>{};
    for (final s in shtetet) {
      if (f.isNotEmpty && !s.emri.toLowerCase().contains(f)) continue;
      out.putIfAbsent(s.rajoni, () => <Shteti>[]).add(s);
    }
    return out;
  }
}
