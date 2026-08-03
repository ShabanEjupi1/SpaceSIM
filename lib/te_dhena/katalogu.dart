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

  static Future<Katalogu> nga({String shtegu = 'assets/katalogu.json'}) async {
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
    final paketat = (j['paketat'] as List)
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
