/// Transporti i vërtetë HTTP për [KlientiAiralo].
///
/// I ndarë nga `airalo.dart` me qëllim: ai skedar mbetet i provueshëm pa asnjë
/// varësi dhe pa rrjet, kurse kjo është e vetmja pjesë që prek `package:http`.
library;

import 'package:http/http.dart' as http;

import 'airalo.dart';

/// 🚨 Afati është i domosdoshëm. Pa të, një kërkesë e ngecur e mban ekranin e
/// blerjes në pritje pa fund — dhe ky aplikacion hapet pikërisht atje ku rrjeti
/// është i keq (aeroport, roaming i sapondërruar).
Transporti transportiHttp({
  http.Client? klienti,
  Duration afati = const Duration(seconds: 30),
}) {
  final c = klienti ?? http.Client();
  return (metoda, adresa, {kokat = const {}, forma}) async {
    final k = {...kokat};
    late final http.Response p;
    if (metoda == 'GET') {
      p = await c.get(adresa, headers: k).timeout(afati);
    } else {
      // Airalo-ja i pret të dyja pikat (`/v2/token` dhe `/v2/orders`) si
      // formular, jo si JSON.
      p = await c
          .post(adresa, headers: k, body: forma ?? const <String, String>{})
          .timeout(afati);
    }
    return PergjigjeHttp(p.statusCode, p.body, kokat: p.headers);
  };
}
