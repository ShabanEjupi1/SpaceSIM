import 'dart:io';
import 'dart:math';

import 'package:esim/app/ads.dart';
import 'package:esim/furnizuesi/furnizuesi.dart';
import 'package:esim/modele/modele.dart';
import 'package:esim/te_dhena/katalogu.dart';
import 'package:flutter_test/flutter_test.dart';

const _json = '''
{
  "shtetet": [
    {"kodi": "XK", "emri": "Kosovë", "rajoni": "Ballkan"},
    {"kodi": "DE", "emri": "Gjermani", "rajoni": "Evropë"}
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
      {"shtetet": [{"kodi":"XK","emri":"Kosovë","rajoni":"Ballkan"}],
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

  group('Furnizuesi i palidhur', () {
    test('nuk shet, dhe e thotë pa u rikthyer', () async {
      // Ky është furnizuesi i LËSHIMIT. Nëse ndonjëherë `mundBlihet` bëhet true
      // pa një furnizues të vërtetë, aplikacioni merr para pa dhënë asgjë.
      const f = FurnizuesIPaLidhur();
      expect(f.mundBlihet, isFalse);
      expect(f.iVertete, isFalse);
      const p = Paketa(
          id: 'x', kodiIShtetit: 'XK', gigabajt: 1, dite: 7, centa: 100, rrjetet: []);
      await expectLater(
        f.blej(p, porosiaId: 'a'),
        throwsA(isA<GabimFurnizuesi>()
            .having((e) => e.rikthyeshem, 'rikthyeshem', isFalse)),
      );
    });
  });

  group('ESimIm', () {
    test('një LPA pa «LPA:» refuzohet para se të ruhet', () {
      // Pa këtë, vargu bëhet një QR që telefoni e skanon dhe e refuzon, dhe
      // blerësi mendon se profili është i prishur — jo se e ngjiti gabim.
      expect(ESimIm.gabimiILpas(r'1$rsp.x$KOD'), isNotNull);
      expect(ESimIm.gabimiILpas(''), isNotNull);
    });

    test('një LPA pa server refuzohet', () {
      expect(ESimIm.gabimiILpas('LPA:1'), isNotNull);
    });

    test('një LPA e plotë pranohet dhe kalon nëpër JSON', () {
      expect(ESimIm.gabimiILpas(r'LPA:1$rsp.example.com$ABCD'), isNull);
      final e = ESimIm(
        id: 'im1',
        emri: 'Gjermani',
        lpa: r'LPA:1$rsp.example.com$ABCD',
        kur: DateTime.utc(2026, 8, 3),
        shenim: '5 GB',
        skadon: DateTime.utc(2026, 9, 1),
      );
      final kthyer = ESimIm.ngaJson(e.teJson());
      expect(kthyer.emri, 'Gjermani');
      expect(kthyer.shenim, '5 GB');
      expect(kthyer.skadon, DateTime.utc(2026, 9, 1));
    });
  });

  group('Reklamat', () {
    test('jashtë lëshimit përdoren VETËM njësitë e provës së Google-it', () {
      // 🚨 Rregulli që mbron llogarinë: një klikim i vetëm mbi njësinë e vërtetë
      // nga vetë zhvilluesi është «trafik i pavlefshëm» dhe llogaria e AdMob-it
      // mbyllet pa paralajmërim. Testet dhe `flutter run` janë të dyja debug,
      // ndaj kjo është pikërisht gjendja që prek zhvilluesi çdo ditë.
      expect(Ads.bannerUnit, startsWith('ca-app-pub-3940256099942544/'));
      expect(Ads.interstitialUnit, startsWith('ca-app-pub-3940256099942544/'));
    });

    test('pa nisje, asnjë rrugë reklame nuk bën asgjë', () async {
      // `start()` nuk thirret kurrë te testet (as te web-i, as pa rrjet).
      // Prandaj gjithçka duhet të mbetet e heshtur: banderola zë zero hapësirë
      // dhe interstitial-i kthehet menjëherë, pa prekur SDK-në që s'ekziston.
      expect(Ads.ready, isFalse);
      await Ads.maybeShowAfterQr();
    });

    test('pauza mes dy interstitialeve nuk zbret nën 4 minuta', () {
      expect(Ads.pauzaMesInterstitialeve, greaterThanOrEqualTo(const Duration(minutes: 4)));
    });

    test('ekrani i kodit QR nuk di fare se ekzistojnë reklama', () {
      // 🚨🚨 Rregulli më i rëndësishëm i të gjithëve, dhe i vetmi që një
      // rishikim me sy e humb: ekranin e QR-it e lexon një pajisje e DYTË që po
      // skanon. Çfarëdo reklame atje bie brenda kuadratit që kamera lexon dhe
      // skanimi dështon pa e ditur askush pse.
      // Kontrolli bëhet mbi BURIMIN, jo mbi pamjen: një test widget-i do të
      // kapte vetëm banderolën, kurse një interstitial i hapur nga ai ekran do
      // t'i shpëtonte. Këtu s'i shpëton asnjëra.
      final burimi = File('lib/pamja/faqja_profilit.dart').readAsStringSync();
      expect(burimi.contains('ads.dart'), isFalse,
          reason: 'faqja_profilit.dart nuk guxon të importojë reklamat');
      expect(burimi.contains('Ads.'), isFalse);
      expect(burimi.contains('BannerSlot'), isFalse);
    });

    test('formulari «Shto eSIM-in tënd» po ashtu nuk mban reklama', () {
      // Një formular i ndërprerë nga një reklamë e plotë humb atë që është
      // shkruar; dhe LPA-ja ngjitet nga kujtesa e fragmenteve, të cilën një
      // reklamë mund ta zëvendësojë.
      final burimi = File('lib/pamja/faqja_shto.dart').readAsStringSync();
      expect(burimi.contains('ads.dart'), isFalse);
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

  group('Pamja', () {
    test('asnjë emoji te katalogu dhe te ekranet', () {
      // 🕌 Katalogu mbante emoji flamujsh derisa u hoqën më 2026-08-04: dy prej
      // tyre (Shqipëria, Mali i Zi) i vizaton fonti i pajisjes si shqiponja, pra
      // qenie të gjalla, dhe një glif Unicode nuk ndreqet dot me kod. Ky test
      // rri këtu sepse rikthimi do të ishte një rresht i vetëm te një JSON që
      // askush nuk e rilexon. Shih `lib/pamja/shenja_e_shtetit.dart`.
      final skedaret = [
        File('assets/emrat.json'),
        ...Directory('lib').listSync(recursive: true).whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
      ];
      // Emoji, simbole të ndryshme dhe treguesit rajonalë të flamujve.
      final emoji = RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
      // 🔑 Komentet hiqen para kontrollit: shënuesit 🚨/🔑/🕌 janë stili i vetë
      // depos dhe nuk dalin kurrë në ekran. Nëse kontrollohej krejt skedari,
      // testi do të binte gjithnjë dhe do të hiqej brenda javës.
      final koment = RegExp(r'^\s*//.*$|//.*$', multiLine: true);
      for (final f in skedaret) {
        final teksti = f.path.endsWith('.dart')
            ? f.readAsStringSync().replaceAll(koment, '')
            : f.readAsStringSync();
        final gjetur = emoji.allMatches(teksti).map((m) => m[0]).toSet();
        expect(gjetur, isEmpty, reason: '${f.path} mban ${gjetur.join()}');
      }
    });
  });
}
