import 'dart:math';

import 'package:esim/furnizuesi/furnizuesi.dart';
import 'package:esim/modele/modele.dart';
import 'package:esim/te_dhena/katalogu.dart';
import 'package:flutter_test/flutter_test.dart';

const _json = '''
{
  "shtetet": [
    {"kodi": "XK", "emri": "Kosovë", "flamuri": "🇽🇰", "rajoni": "Ballkan"},
    {"kodi": "DE", "emri": "Gjermani", "flamuri": "🇩🇪", "rajoni": "Evropë"}
  ],
  "paketat": [
    {"id": "xk-3", "shteti": "XK", "gb": 3, "dite": 15, "centa": 890, "rrjetet": ["Vala"]},
    {"id": "xk-1", "shteti": "XK", "gb": 1, "dite": 7, "centa": 450, "rrjetet": ["IPKO"]}
  ]
}
''';

void main() {
  group('Katalogu', () {
    test('paketat renditen nga çmimi më i ulët', () {
      final k = Katalogu.ngaTeksti(_json);
      expect(k.perShtetin('XK').map((p) => p.id), ['xk-1', 'xk-3']);
    });

    test('një shtet pa paketa nuk rrëzon asgjë', () {
      final k = Katalogu.ngaTeksti(_json);
      expect(k.perShtetin('DE'), isEmpty);
    });

    test('një paketë që tregon te shtet i panjohur refuzohet', () {
      // Pa këtë kontroll, paketa do të zhdukej pa gabim dhe ekrani do të
      // dukej thjesht «pa oferta».
      const iKeq = '''
      {"shtetet": [{"kodi":"XK","emri":"Kosovë","flamuri":"🇽🇰","rajoni":"Ballkan"}],
       "paketat": [{"id":"zz-1","shteti":"ZZ","gb":1,"dite":7,"centa":100,"rrjetet":[]}]}
      ''';
      expect(() => Katalogu.ngaTeksti(iKeq), throwsFormatException);
    });

    test('kërkimi filtron sipas emrit, pa i prishur rajonet', () {
      final k = Katalogu.ngaTeksti(_json);
      final r = k.sipasRajonit(kerkim: 'gjerm');
      expect(r.keys, ['Evropë']);
      expect(r['Evropë']!.single.kodi, 'DE');
    });
  });

  group('Paketa', () {
    test('çmimi formatohet nga centat, pa aritmetikë me presje', () {
      const p = Paketa(
          id: 'x', kodiIShtetit: 'XK', gigabajt: 1, dite: 7, centa: 1990, rrjetet: []);
      expect(p.cmimi, '19.90 €');
    });

    test('sasia e plotë shfaqet pa presje', () {
      const p = Paketa(
          id: 'x', kodiIShtetit: 'XK', gigabajt: 10, dite: 7, centa: 100, rrjetet: []);
      expect(p.sasia, '10 GB');
    });
  });

  group('Furnizuesi i simuluar', () {
    test('deklaron se NUK është i vërtetë', () {
      // Nga kjo varet shiriti «PROVË». Nëse ndonjëherë kthen true pa qenë,
      // dikush paguan duke menduar se merr internet.
      expect(FurnizuesISimuluar().iVertete, isFalse);
    });

    test('jep një LPA që e njeh sistemi si profil', () async {
      final f = FurnizuesISimuluar(rastesia: Random(1), vonesa: Duration.zero);
      const p = Paketa(
          id: 'x', kodiIShtetit: 'XK', gigabajt: 1, dite: 7, centa: 100, rrjetet: []);
      final profili = await f.blej(p, porosiaId: 'abc');
      expect(profili.lpa, startsWith(r'LPA:1$'));
      expect(profili.iccid, startsWith('8900'));
    });

    test('dështon herë pas here, që rruga e dështimit të mos mbetet pa shkruar',
        () async {
      final f = FurnizuesISimuluar(rastesia: Random(1), vonesa: Duration.zero);
      const p = Paketa(
          id: 'x', kodiIShtetit: 'XK', gigabajt: 1, dite: 7, centa: 100, rrjetet: []);
      var deshtime = 0;
      for (var i = 0; i < 60; i++) {
        try {
          await f.blej(p, porosiaId: 'n$i');
        } on GabimFurnizuesi {
          deshtime++;
        }
      }
      expect(deshtime, greaterThan(0));
    });
  });

  group('Porosia', () {
    test('kalon e plotë nëpër JSON, bashkë me profilin', () {
      final p = Porosia(
        id: 'sp1',
        paketaId: 'xk-1',
        kodiIShtetit: 'XK',
        centa: 450,
        kur: DateTime.utc(2026, 8, 3, 12),
        gjendja: GjendjaEPorosise.dhene,
        profili: const Profili(lpa: r'LPA:1$a$b', iccid: '8900'),
      );
      final kthyer = Porosia.ngaJson(p.teJson());
      expect(kthyer.id, p.id);
      expect(kthyer.gjendja, GjendjaEPorosise.dhene);
      expect(kthyer.profili!.lpa, r'LPA:1$a$b');
      expect(kthyer.kur, p.kur);
    });

    test('një gjendje e panjohur nuk e rrëzon leximin', () {
      final j = {
        'id': 'x', 'paketa': 'p', 'shteti': 'XK', 'centa': 1,
        'kur': DateTime.utc(2026).toIso8601String(), 'gjendja': 'diçka-e-re',
      };
      expect(Porosia.ngaJson(j).gjendja, GjendjaEPorosise.nisur);
    });
  });
}
