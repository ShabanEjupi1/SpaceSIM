/// Provat e pagesës — gjysma që mungonte deri më 17-08-2026.
///
/// 🚨 Përse këto prova nuk ekzistonin dhe defekti kaloi: të gjitha provat e
/// blerjes përdornin [FurnizuesISimuluar], i cili nuk kërkon pagesë. Pra rruga e
/// vërtetë — ajo që shkon te relaja dhe merr 402 — nuk ishte matur kurrë. Një
/// provë që kalon mbi një zëvendësues nuk thotë asgjë për rrugën e prodhimit.
library;

import 'dart:convert';

import 'package:esim/furnizuesi/airalo.dart';
import 'package:esim/furnizuesi/furnizuesi.dart';
import 'package:esim/modele/modele.dart';
import 'package:esim/pagesa/pagesa.dart';
import 'package:esim/te_dhena/katalogu.dart';
import 'package:flutter_test/flutter_test.dart';

const _paketa = Paketa(
  id: 'kosovo-7days-1gb',
  kodiIShtetit: 'XK',
  gigabajt: 1,
  dite: 7,
  centa: 450,
  rrjetet: ['Vala'],
);

/// Transport i rremë: një radhë përgjigjesh për çdo shteg.
class _Rremi {
  _Rremi(this.pergjigjet);

  final Map<String, List<PergjigjeHttp>> pergjigjet;
  final gjurma = <String>[];
  final format = <Map<String, String>?>[];

  Transporti get transporti => (metoda, adresa, {kokat = const {}, forma}) async {
        gjurma.add('$metoda ${adresa.path}');
        format.add(forma);
        final radha = pergjigjet[adresa.path];
        if (radha == null || radha.isEmpty) {
          return const PergjigjeHttp(404, '{"message":"pa provë"}');
        }
        return radha.length == 1 ? radha.first : radha.removeAt(0);
      };
}

PergjigjeHttp _ok(Object j) => PergjigjeHttp(200, jsonEncode(j));

PagesaPermesReleje _pagesa(_Rremi r) => PagesaPermesReleje(
      bazaUrl: 'https://rele.test',
      celesi: 'ç',
      transporti: r.transporti,
    );

void main() {
  _katalogu();
  group('nisja e pagesës', () {
    test('kthen referencën, adresën dhe shumën e RELESË', () async {
      final r = _Rremi({
        '/pagesa/nis': [_ok({'ref': 'R1', 'url': 'https://paypal/x', 'cmimi': 5.25})],
      });
      final p = await _pagesa(r).nis(_paketa);
      expect(p.ref, 'R1');
      expect(p.url, 'https://paypal/x');
      // 🚨 525, jo 450: shuma e vërtetë është ajo që relaja i tha PayPal-it.
      // Katalogu i telefonit mund të jetë orë të vjetër, dhe blerësi nuk guxon
      // të aprovojë një shifër tjetër nga ajo që i tregohet.
      expect(p.centa, 525);
      expect(p.shuma, '5.25 €');
      expect(r.format.single, {'package_id': 'kosovo-7days-1gb'});
    });

    test('pa çmim nga relaja bie te çmimi i katalogut, jo te zero', () async {
      final r = _Rremi({
        '/pagesa/nis': [_ok({'ref': 'R1', 'url': 'https://paypal/x'})],
      });
      expect((await _pagesa(r).nis(_paketa)).centa, 450);
    });

    test('mesazhi i relesë kalon te blerësi, jo kodi i zhveshur', () async {
      final r = _Rremi({
        '/pagesa/nis': [
          PergjigjeHttp(503, jsonEncode({'message': 'Pagesa nuk është konfiguruar te relaja.'}))
        ],
      });
      await expectLater(
        _pagesa(r).nis(_paketa),
        throwsA(isA<GabimPagese>().having(
            (e) => e.mesazhi, 'mesazhi', contains('nuk është konfiguruar'))),
      );
    });

    test('adresë boshe nga relaja NUK kthehet si sukses', () async {
      // Pa këtë kontroll, butoni «Vazhdo te PayPal» do të hapte një varg bosh
      // dhe blerësi do të mbetej te një ekran pritjeje pa fund.
      final r = _Rremi({
        '/pagesa/nis': [_ok({'ref': 'R1', 'url': ''})],
      });
      await expectLater(_pagesa(r).nis(_paketa), throwsA(isA<GabimPagese>()));
    });
  });

  group('pritja e konfirmimit', () {
    test('kthen kapjen kur gjendja bëhet «paguar»', () async {
      final r = _Rremi({
        '/pagesa/gjendja': [
          _ok({'gjendja': 'pritet'}),
          _ok({'gjendja': 'pritet'}),
          _ok({'gjendja': 'paguar', 'kapja': 'KAPJA-9'}),
        ],
      });
      final k = await _pagesa(r).prit('R1', hapi: Duration.zero);
      expect(k, 'KAPJA-9');
      expect(r.gjurma.length, 3);
    });

    test('anulimi është i shënuar si anulim, jo si gabim', () async {
      final r = _Rremi({'/pagesa/gjendja': [_ok({'gjendja': 'anuluar'})]});
      await expectLater(
        _pagesa(r).prit('R1', hapi: Duration.zero),
        throwsA(isA<GabimPagese>().having((e) => e.anuluar, 'anuluar', isTrue)),
      );
    });

    test('«paguar» pa kapje thotë MOS PAGUAJ SËRISH', () async {
      // Gjendja më e rrezikshme e sistemit: paratë kanë ikur dhe ne s'kemi
      // provën. Mesazhi këtu është i vetmi që e ndal pagesën e dytë.
      final r = _Rremi({'/pagesa/gjendja': [_ok({'gjendja': 'paguar'})]});
      await expectLater(
        _pagesa(r).prit('R1', hapi: Duration.zero),
        throwsA(isA<GabimPagese>()
            .having((e) => e.mesazhi, 'mesazhi', contains('Mos paguaj sërish'))),
      );
    });

    test('gabimet e përkohshme të rrjetit NUK e ndalin pritjen', () async {
      // Blerësi është te shfletuesi dhe telefoni sapo ka ndërruar rrjetin.
      // Një 500 i vetëm nuk guxon ta shpallë të dështuar një pagesë të gjallë.
      final r = _Rremi({
        '/pagesa/gjendja': [
          const PergjigjeHttp(500, 'ups'),
          const PergjigjeHttp(500, 'ups'),
          _ok({'gjendja': 'paguar', 'kapja': 'KAPJA-9'}),
        ],
      });
      expect(await _pagesa(r).prit('R1', hapi: Duration.zero), 'KAPJA-9');
    });

    test('pritja ka fund, dhe fundi e thotë çfarë të bëhet', () async {
      final r = _Rremi({'/pagesa/gjendja': [_ok({'gjendja': 'pritet'})]});
      await expectLater(
        _pagesa(r).prit('R1',
            hapi: Duration.zero, durimi: const Duration(milliseconds: 30)),
        throwsA(isA<GabimPagese>()
            .having((e) => e.mesazhi, 'mesazhi', contains('info@spacecode.tech'))),
      );
    });
  });

  group('furnizuesi kërkon kapjen', () {
    test('blerja pa kapje ndalet KËTU, pa e prekur rrjetin', () async {
      // 🚨 Kjo është prova që do ta kishte kapur defektin e 12→17 gushtit:
      // pa të, kërkesa shkonte te relaja dhe kthehej 402 me tekstin
      // «Furnizuesi ktheu gabim (402)» — që tregon te furnizuesi i gabuar.
      final r = _Rremi({});
      final f = FurnizuesiAiralo(KlientiAiralo(
        bazaUrl: 'https://rele.test',
        burimi: const ShenjaEAplikacionit('ç'),
        transporti: r.transporti,
      ));
      await expectLater(
        f.blej(_paketa, porosiaId: 'sp1'),
        throwsA(isA<GabimFurnizuesi>()
            .having((e) => e.mesazhi, 'mesazhi', contains('pa pagesë'))),
      );
      expect(r.gjurma, isEmpty);
    });

    test('kapja dërgohet te trupi i porosisë', () async {
      final r = _Rremi({
        '/v2/orders': [
          _ok({
            'data': {
              'sims': [
                {'lpa': 'LPA:1\$x\$y', 'iccid': '8900', 'matching_id': 'M'}
              ]
            }
          })
        ],
      });
      final f = FurnizuesiAiralo(KlientiAiralo(
        bazaUrl: 'https://rele.test',
        burimi: const ShenjaEAplikacionit('ç'),
        transporti: r.transporti,
      ));
      await f.blej(_paketa, porosiaId: 'sp1', kapja: 'KAPJA-9');
      expect(r.format.single?['pagesa'], 'KAPJA-9');
    });
  });

  group('porosia e mban provën e pagesës', () {
    test('kapja shkruhet dhe lexohet nga JSON-i', () {
      final p = Porosia(
        id: 'sp1',
        paketaId: 'x',
        kodiIShtetit: 'XK',
        centa: 450,
        kur: DateTime.utc(2026, 8, 17),
        gjendja: GjendjaEPorosise.paguar,
        kapja: 'KAPJA-9',
      );
      final k = Porosia.ngaJson(jsonDecode(jsonEncode(p.teJson())) as Map<String, dynamic>);
      // Pa këtë, një aplikacion i mbyllur pas pagesës do ta humbte të vetmen
      // provë se blerësi ka paguar — dhe riprovimi do të kërkonte pagesë të re.
      expect(k.kapja, 'KAPJA-9');
      expect(k.gjendja, GjendjaEPorosise.paguar);
    });
  });
}

/// Katalogu i vërtetë — provat e shtuara më 17-08-2026 bashkë me heqjen e
/// çmimeve të shpikura nga aseti.
void _katalogu() {
  group('katalogu vjen nga furnizuesi', () {
    final emrat = Katalogu.ngaTeksti('''
{"shtetet":[{"kodi":"XK","emri":"Kosovë","rajoni":"Ballkan"}]}''');

    test('aseti nuk mban më asnjë paketë', () {
      // 🚨 Prova që e ndal rikthimin: nëse dikush shton sërish çmime te aseti,
      // ky rresht bie. Deri më 17-08 ato çmime shiteshin.
      expect(emrat.paketat, isEmpty);
      expect(emrat.bosh, isTrue);
    });

    test('shtetet e panjohura marrin emrin e furnizuesit, jo kodin', () {
      final k = Katalogu.bashko(
        paketat: const [
          Paketa(id: 'a', kodiIShtetit: 'XK', gigabajt: 1, dite: 7, centa: 430, rrjetet: []),
          Paketa(id: 'b', kodiIShtetit: 'JP', gigabajt: 3, dite: 15, centa: 990, rrjetet: []),
        ],
        titujt: const {'JP': 'Japan'},
        emrat: emrat,
      );
      expect(k.shteti('XK').emri, 'Kosovë');
      expect(k.shteti('JP').emri, 'Japan');
      expect(k.shteti('JP').rajoni, 'Të tjera');
      // Ballkani mbetet i pari: aty është blerësi.
      expect(k.shtetet.first.kodi, 'XK');
    });

    test('paketat pa shtet hidhen, se nuk arrihen dot nga asnjë ekran', () {
      final k = Katalogu.bashko(
        paketat: const [
          Paketa(id: 'g', kodiIShtetit: '', gigabajt: 5, dite: 30, centa: 1990, rrjetet: []),
        ],
        titujt: const {},
        emrat: emrat,
      );
      expect(k.paketat, isEmpty);
    });

    test('kopja e ruajtur kthen TË NJËJTAT çmime dhe identifikues', () {
      final k = Katalogu.bashko(
        paketat: const [
          Paketa(id: 'plisi-7days-1gb', kodiIShtetit: 'XK', gigabajt: 1, dite: 7, centa: 430, rrjetet: ['Vala']),
        ],
        titujt: const {'XK': 'Kosovo'},
        emrat: emrat,
      );
      final prapa = Katalogu.ngaCache(k.teCache(const {'XK': 'Kosovo'}), emrat)!;
      // Identifikuesi ËSHTË ai i Airalo-s: një id i shpikur do të kalonte
      // pagesën dhe do të binte te porosia, PAS parave.
      expect(prapa.paketa('plisi-7days-1gb').centa, 430);
    });

    test('kopje e prishur nuk e rrëzon nisjen', () {
      expect(Katalogu.ngaCache('{jo json', emrat), isNull);
      expect(Katalogu.ngaCache(null, emrat), isNull);
    });
  });
}
