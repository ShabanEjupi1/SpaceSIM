/// Provat e furnizuesit të vërtetë (Airalo Partner API).
///
/// 🔑 Asnjë prej tyre nuk prek rrjetin: [Transporti] është një funksion, ndaj
/// zëvendësohet me tre rreshta. Kjo është arsyeja pse `airalo.dart` nuk e njeh
/// `package:http` — atë e njeh vetëm `transporti_http.dart`.
///
/// ⛔ Kur të vijnë çelësat e sandbox-it, këto prova mbeten si janë: ato masin
/// **si e lexojmë ne përgjigjen e tyre**, jo se a punon serveri i tyre.
library;

import 'dart:convert';

import 'package:esim/furnizuesi/airalo.dart';
import 'package:esim/furnizuesi/furnizuesi.dart';
import 'package:esim/modele/modele.dart';
import 'package:flutter_test/flutter_test.dart';

/// Një transport i rremë që kthen përgjigje sipas shtegut, dhe mban shënim
/// çdo kërkesë që i erdhi.
class _Rremi {
  _Rremi(this.pergjigjet);

  final Map<String, List<PergjigjeHttp>> pergjigjet;
  final gjurma = <String>[];
  final format = <Map<String, String>?>[];

  Transporti get transporti => (metoda, adresa, {kokat = const {}, forma}) async {
        gjurma.add('$metoda ${adresa.path}${adresa.hasQuery ? '?${adresa.query}' : ''}');
        format.add(forma);
        final radha = pergjigjet[adresa.path];
        if (radha == null || radha.isEmpty) {
          return const PergjigjeHttp(404, '{"meta":{"message":"pa provë"}}');
        }
        return radha.length == 1 ? radha.first : radha.removeAt(0);
      };
}

PergjigjeHttp _ok(Object j) => PergjigjeHttp(200, jsonEncode(j));

Map<String, dynamic> get _shenja => {
      'data': {'token_type': 'Bearer', 'expires_in': 86400, 'access_token': 'SH-1'},
      'meta': {'message': 'success'},
    };

/// Përgjigje e `/v2/packages` me formën e vërtetë: shtet → operator → paketa.
///
/// 🚨 [zbritje] jep formën e llogarisë sonë të vërtetë (`discount_pricing`,
/// matur 11-08-2026): **asnjë** `net_price`, vetëm `recommended_retail_price`.
Map<String, dynamic> _katalogu({
  double euro = 4.5,
  int mb = 3072,
  bool paKufi = false,
  bool zbritje = false,
}) =>
    {
      'data': [
        {
          'slug': 'kosovo',
          'country_code': 'xk',
          'title': 'Kosovo',
          'operators': [
            {
              'id': 7,
              'title': 'Vala',
              'type': 'local',
              'packages': [
                {
                  'id': 'vala-3gb-15days',
                  'type': 'sim',
                  'price': 6.5,
                  'amount': mb,
                  'day': 15,
                  'is_unlimited': paKufi,
                  'title': '3 GB - 15 Days',
                  'data': '3 GB',
                  if (!zbritje) 'net_price': 5.2,
                  'prices': {
                    if (!zbritje) 'net_price': {'USD': 5.2, 'EUR': euro},
                    'recommended_retail_price': {
                      'USD': 6.5,
                      'EUR': zbritje ? euro : 5.9,
                    },
                  },
                },
              ],
            },
          ],
        },
      ],
      if (zbritje) 'pricing': {'model': 'discount_pricing', 'discount_percentage': 20},
      'meta': {'message': 'success', 'current_page': 1, 'total': 1},
    };

Map<String, dynamic> _porosia({bool meSim = true, bool ipa = true}) => {
      'data': {
        'id': 991,
        'code': '20260810-991',
        'package_id': 'vala-3gb-15days',
        'quantity': '1',
        'sims': meSim
            ? [
                {
                  'id': 55,
                  'iccid': '8938544000000123456',
                  if (ipa) 'lpa': 'LPA:1\$lpa.airalo.com\$TM-A1B2C3',
                  'matching_id': 'TM-A1B2C3',
                  'qrcode': 'LPA:1\$lpa.airalo.com\$TM-A1B2C3',
                },
              ]
            : <Object>[],
      },
      'meta': {'message': 'success'},
    };

KlientiAiralo _klienti(_Rremi r, {int marzha = 0}) => KlientiAiralo(
      burimi: CelesatAiralo(
        clientId: 'id',
        clientSecret: 'fshehta',
        transporti: r.transporti,
      ),
      transporti: r.transporti,
      marzhaNePerqindje: marzha,
    );

void main() {
  test('shenja merret një herë dhe ruhet — kufiri është 3 kërkesa në minutë', () async {
    final r = _Rremi({
      '/v2/token': [_ok(_shenja)],
      '/v2/packages': [_ok(_katalogu()), _ok(_katalogu())],
    });
    final k = _klienti(r);

    await k.paketat();
    await k.paketat();

    // 🚨 Kjo është prova që mbron llogarinë: pa ruajtje, dhjetë blerje
    // njëkohësisht e kalojnë kufirin e tyre dhe e bllokojnë për një minutë.
    expect(r.gjurma.where((g) => g.startsWith('POST /v2/token')).length, 1);
  });

  test('katalogu lexohet nga TRE nivele — kodi i shtetit rri te i pari', () async {
    final r = _Rremi({
      '/v2/token': [_ok(_shenja)],
      '/v2/packages': [_ok(_katalogu(euro: 4.5, mb: 3072))],
    });

    final paketat = await _klienti(r).paketat();

    expect(paketat, hasLength(1));
    final p = paketat.single;
    // 🚨 Po ta lexoje kodin nga vetë paketa, do të dilte bosh — dhe katalogu do
    // të mbushej me shtete «» pa asnjë gabim.
    expect(p.kodiIShtetit, 'XK');
    expect(p.gigabajt, closeTo(3, 0.001));
    expect(p.dite, 15);
    expect(p.rrjetet, ['Vala']);
  });

  test('çmimi merret nga EURO-ja, jo nga `net_price` që është në dollarë', () async {
    final r = _Rremi({
      '/v2/token': [_ok(_shenja)],
      '/v2/packages': [_ok(_katalogu(euro: 4.5))],
    });

    final p = (await _klienti(r).paketat()).single;

    // 450, jo 520: `net_price` në krye të paketës është USD.
    expect(p.centa, 450);
  });

  test('marzha rri MBI netot dhe rrumbullakoset një herë te centat', () async {
    final r = _Rremi({
      '/v2/token': [_ok(_shenja)],
      '/v2/packages': [_ok(_katalogu(euro: 4.5))],
    });

    final p = (await _klienti(r, marzha: 15).paketat()).single;

    expect(p.centa, 518); // 450 + 67,5 → 68
    expect(p.centa, isA<int>());
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 🚨🚨 Modeli `discount_pricing` — forma e llogarisë sonë të VËRTETË.
  //
  // Provat e para u shkruan pa çelësa, mbi një përgjigje të supozuar me
  // `net_price`. Më 11-08-2026, me çelësat në dorë, përgjigjja e vërtetë e
  // `partners-api.airalo.com` u mat: **zero** `net_price` te 204 shtetet.
  // Pra pesëmbëdhjetë prova të gjelbra përshkruanin një API që nuk ekziston,
  // dhe katalogu do të dilte BOSH te telefoni pa asnjë gabim.

  test('katalogu NUK del bosh kur mungon fare `net_price` (discount_pricing)', () async {
    final r = _Rremi({
      '/v2/token': [_ok(_shenja)],
      '/v2/packages': [_ok(_katalogu(euro: 10, zbritje: true))],
    });

    final paketat = await _klienti(r).paketat();

    // Ky `hasLength(1)` është e gjithë prova: leximi i vjetër jepte 0.
    expect(paketat, hasLength(1));
    expect(paketat.single.centa, 1000);
  });

  test('te `discount_pricing` marzha NUK shtohet — ai numër është vetë shitja', () async {
    final r = _Rremi({
      '/v2/token': [_ok(_shenja)],
      '/v2/packages': [_ok(_katalogu(euro: 10, zbritje: true))],
    });

    // 🔑 Fitimi vjen nga zbritja 20% te faturimi, jo nga një shtesë mbi listë.
    // Marzha mbi çmimin e rekomanduar do të thoshte se dyqani ynë është
    // gjithmonë më i shtrenjtë se aplikacioni i vetë Airalo-s.
    expect((await _klienti(r, marzha: 15).paketat()).single.centa, 1000);
  });

  test('paketa pa çmim në euro HIDHET, nuk shitet me shifër dollari', () async {
    final pa = _katalogu();
    ((((pa['data'] as List).first as Map)['operators'] as List).first
        as Map)['packages'] = [
      {
        'id': 'x',
        'amount': 1024,
        'day': 7,
        'is_unlimited': false,
        'net_price': 3.0,
        'prices': {
          'net_price': {'USD': 3.0},
        },
      },
    ];
    final r = _Rremi({
      '/v2/token': [_ok(_shenja)],
      '/v2/packages': [_ok(pa)],
    });

    expect(await _klienti(r).paketat(), isEmpty);
  });

  test('paketat pa kufi hidhen — «0 GB» do të lexohej si «pa të dhëna»', () async {
    final r = _Rremi({
      '/v2/token': [_ok(_shenja)],
      '/v2/packages': [_ok(_katalogu(paKufi: true))],
    });

    expect(await _klienti(r).paketat(), isEmpty);
  });

  test('blerja kthen LPA-në dhe ICCID-në, dhe e dërgon id-në tonë te description',
      () async {
    final r = _Rremi({
      '/v2/token': [_ok(_shenja)],
      '/v2/orders': [_ok(_porosia())],
    });
    final f = FurnizuesiAiralo(_klienti(r));

    final profili = await f.blej(
      const Paketa(
          id: 'vala-3gb-15days',
          kodiIShtetit: 'XK',
          gigabajt: 3,
          dite: 15,
          centa: 518,
          rrjetet: ['Vala']),
      porosiaId: 'p-2026-0001',
    );

    expect(profili.lpa, startsWith('LPA:1\$'));
    expect(profili.iccid, '8938544000000123456');
    expect(profili.kodiIAktivizimit, 'TM-A1B2C3');
    // 🔑 Pa këtë, një porosi e humbur nuk gjendet dot te paneli i tyre.
    expect(r.format.last?['description'], 'p-2026-0001');
    expect(r.format.last?['quantity'], '1');
  });

  test('porosi e pranuar pa sim NUK riprovohet — do të porosiste një të dytë',
      () async {
    final r = _Rremi({
      '/v2/token': [_ok(_shenja)],
      '/v2/orders': [_ok(_porosia(meSim: false))],
    });

    await expectLater(
      FurnizuesiAiralo(_klienti(r)).blej(
        const Paketa(
            id: 'x',
            kodiIShtetit: 'XK',
            gigabajt: 3,
            dite: 15,
            centa: 518,
            rrjetet: []),
        porosiaId: 'p-1',
      ),
      throwsA(isA<GabimFurnizuesi>()
          .having((g) => g.rikthyeshem, 'rikthyeshem', isFalse)),
    );
  });

  test('401 e rimerr shenjën një herë të vetme, pastaj dorëzohet', () async {
    final r = _Rremi({
      '/v2/token': [_ok(_shenja), _ok(_shenja)],
      '/v2/orders': [
        const PergjigjeHttp(401, '{"meta":{"message":"Unauthenticated."}}'),
        const PergjigjeHttp(401, '{"meta":{"message":"Unauthenticated."}}'),
      ],
    });

    await expectLater(
      FurnizuesiAiralo(_klienti(r)).blej(
        const Paketa(
            id: 'x', kodiIShtetit: 'XK', gigabajt: 1, dite: 7, centa: 450, rrjetet: []),
        porosiaId: 'p-1',
      ),
      throwsA(isA<GabimFurnizuesi>()),
    );
    expect(r.gjurma.where((g) => g.startsWith('POST /v2/orders')).length, 2);
    expect(r.gjurma.where((g) => g.startsWith('POST /v2/token')).length, 2);
  });

  test('4xx nuk është i rikthyeshëm, 5xx është', () async {
    Future<GabimFurnizuesi> provo(int kodi) async {
      final r = _Rremi({
        '/v2/token': [_ok(_shenja)],
        '/v2/orders': [PergjigjeHttp(kodi, '{"meta":{"message":"jo"}}')],
      });
      try {
        await FurnizuesiAiralo(_klienti(r)).blej(
          const Paketa(
              id: 'x', kodiIShtetit: 'XK', gigabajt: 1, dite: 7, centa: 450, rrjetet: []),
          porosiaId: 'p-1',
        );
      } on GabimFurnizuesi catch (g) {
        return g;
      }
      fail('pritej gabim');
    }

    expect((await provo(422)).rikthyeshem, isFalse);
    expect((await provo(503)).rikthyeshem, isTrue);
  });

  test('429 e thotë sa duhet pritur, nga koka Retry-After', () async {
    final r = _Rremi({
      '/v2/token': [_ok(_shenja)],
      '/v2/orders': [
        const PergjigjeHttp(429, '{}', kokat: {'retry-after': '900'}),
      ],
    });

    await expectLater(
      FurnizuesiAiralo(_klienti(r)).blej(
        const Paketa(
            id: 'x', kodiIShtetit: 'XK', gigabajt: 1, dite: 7, centa: 450, rrjetet: []),
        porosiaId: 'p-1',
      ),
      throwsA(isA<GabimFurnizuesi>()
          .having((g) => g.mesazhi, 'mesazhi', contains('900'))),
    );
  });

  test('përdorimi: MB → GB, dhe paketa pa kufi kthen null jo zero', () async {
    Future<double?> mbetja(Map<String, dynamic> d) async {
      final r = _Rremi({
        '/v2/token': [_ok(_shenja)],
        '/v2/sims/8938544000000123456/usage': [
          _ok({'data': d})
        ],
      });
      return FurnizuesiAiralo(_klienti(r)).gigabajtTeMbetur(
        const Profili(lpa: 'LPA:1\$a\$b', iccid: '8938544000000123456'),
      );
    }

    expect(await mbetja({'remaining': 1536, 'total': 3072, 'is_unlimited': false}),
        closeTo(1.5, 0.001));
    // 🚨 «0 GB të mbetura» te një paketë PA KUFI është pikërisht ankesa që s'duhet
    // shkaktuar — API-ja kthen 0 aty me qëllim.
    expect(await mbetja({'remaining': 0, 'total': 0, 'is_unlimited': true}), isNull);
  });

  test('një 429 te përdorimi NUK e prish ekranin e profilit', () async {
    final r = _Rremi({
      '/v2/token': [_ok(_shenja)],
      '/v2/sims/1/usage': [
        const PergjigjeHttp(429, '{}', kokat: {'retry-after': '600'})
      ],
    });

    // Kufiri i tyre është një kërkesë çdo 15 minuta për eSIM; profili duhet të
    // hapet prapë, thjesht pa shifër.
    expect(
      await FurnizuesiAiralo(_klienti(r))
          .gigabajtTeMbetur(const Profili(lpa: 'LPA:1\$a\$b', iccid: '1')),
      isNull,
    );
  });

  test('shiriti «PROVË» rri derisa çelësat të jenë të PRODHIMIT', () {
    final r = _Rremi({});
    // Sandbox-i i Airalo-s porosit profile të simuluara: integrimi punon, por
    // asgjë nuk aktivizohet. Prandaj `iVertete` NUK vjen nga «a ka furnizues».
    expect(FurnizuesiAiralo(_klienti(r)).iVertete, isFalse);
    expect(FurnizuesiAiralo(_klienti(r)).mundBlihet, isTrue);
    expect(FurnizuesiAiralo(_klienti(r), iVerteteVertete: true).iVertete, isTrue);
  });
}
