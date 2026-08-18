/// Kufiri me furnizuesin e eSIM-eve.
///
/// 🔑 Ky skedar është i vetmi vend ku aplikacioni e di se ekziston një furnizues.
/// Gjithçka tjetër — katalogu, blerja, historiku, ekrani i QR-it — punon mbi
/// këtë ndërfaqe. Kur të vijë çelësi i vërtetë (Airalo Partner, eSIM Go, Maya),
/// shtohet një zbatim i dytë dhe ndërrohet një rresht te `main.dart`; asnjë
/// ekran nuk preket.
///
/// ⛔ Sot punon vetëm `FurnizuesISimuluar`. Ai NUK prodhon profile të vërteta:
/// LPA-ja e tij tregon te një server që nuk ekziston, ndaj një telefon do ta
/// refuzonte. Kjo është me qëllim — një profil i rremë që *duket* i vërtetë
/// është më i keq se një gabim i qartë.
library;

import 'dart:async';
import 'dart:math';

import '../modele/modele.dart';

/// Dështim i furnizuesit, i ndarë nga dështimi i pagesës.
class GabimFurnizuesi implements Exception {
  const GabimFurnizuesi(this.mesazhi, {this.rikthyeshem = true});

  final String mesazhi;

  /// A ka kuptim ta provosh sërish. Një paketë e shitur krejt nuk ka; një
  /// ndërprerje rrjeti po. Blerësit i thuhen gjëra të ndryshme.
  final bool rikthyeshem;

  @override
  String toString() => mesazhi;
}

abstract class Furnizuesi {
  /// Emri që i shfaqet blerësit te faturat. Nuk është zbukurim: ligji kërkon
  /// të dihet kush e ofron shërbimin.
  String get emri;

  /// A mund të blihet fare tani. E NDARË nga [iVertete] me qëllim: një
  /// furnizues i simuluar është i pavërtetë POR i blershëm (për zhvillim),
  /// kurse mungesa e furnizuesit është e pavërtetë DHE e pablershme. Nëse do
  /// të ishte një flamur i vetëm, njëri nga dy rastet do të gënjente.
  bool get mundBlihet;

  /// A jep profile të vërteta. Ndërfaqja e përdor për të shfaqur shiritin
  /// «PROVË» — që askush të mos paguajë duke menduar se merr internet.
  bool get iVertete;

  /// Blen paketën dhe kthen profilin. Hidhet [GabimFurnizuesi] nëse dështon.
  ///
  /// [kapja] është identifikuesi i kapjes së pagesës te PayPal-i. 🚨 Pa të,
  /// relaja kthen **402** — dhe kjo nuk është kufizim i tepërt: çelësi i
  /// aplikacionit nxirret nga paketa për dy minuta, ndaj vetëm pagesa e ndan
  /// një blerës nga bilanci ynë. Shih `lib/pagesa/pagesa.dart`.
  Future<Profili> blej(Paketa paketa, {required String porosiaId, String? kapja});

  /// Sa të dhëna kanë mbetur, nëse furnizuesi e mbështet. `null` = nuk dihet,
  /// dhe ndërfaqja atëherë NUK shfaq një shifër të trilluar.
  Future<double?> gigabajtTeMbetur(Profili profili);
}

class FurnizuesISimuluar implements Furnizuesi {
  FurnizuesISimuluar({Random? rastesia, this.vonesa = const Duration(milliseconds: 900)})
      : _r = rastesia ?? Random(7);

  final Random _r;
  final Duration vonesa;

  @override
  String get emri => 'Furnizues i simuluar';

  @override
  bool get iVertete => false;

  @override
  bool get mundBlihet => true;

  @override
  Future<Profili> blej(Paketa paketa, {required String porosiaId, String? kapja}) async {
    await Future<void>.delayed(vonesa);

    // 🚨 Një furnizues i simuluar që nuk dështon KURRË e fsheh gabimin më të
    // shpeshtë të këtij zhanri: rruga «pagova dhe s'mora profil» mbetet e
    // pashkruar derisa të ndodhë me një blerës të vërtetë. Prandaj një në
    // dhjetë blerje dështon me qëllim.
    if (_r.nextInt(10) == 0) {
      throw const GabimFurnizuesi(
        'Furnizuesi nuk u përgjigj. Porosia mbetet e paguar dhe profili '
        'jepet sapo lidhja të rikthehet.',
      );
    }

    final iccid = '8900${porosiaId.hashCode.abs().toString().padLeft(15, '0').substring(0, 15)}';
    return Profili(
      lpa: 'LPA:1\$provë.spacesim.invalid\$${porosiaId.toUpperCase()}',
      iccid: iccid,
      kodiIAktivizimit: porosiaId.toUpperCase(),
    );
  }

  @override
  Future<double?> gigabajtTeMbetur(Profili profili) async => null;
}

/// Gjendja e vërtetë e sotme: **nuk ka furnizues**.
///
/// 🔑 Ky është zbatimi që përdoret te lëshimi, jo ai i simuluari. Arsyeja është
/// e drejtpërdrejtë: një dyqan që merr para dhe jep profile të rreme nuk është
/// «provë», është mashtrim — dhe Play-i e trajton pikërisht ashtu. Me këtë,
/// aplikacioni thotë hapur se shitja s'ka nisur, kurse gjithçka tjetër (katalogu,
/// pajtueshmëria, udhëzimet, eSIM-et e tua) punon plotësisht.
class FurnizuesIPaLidhur implements Furnizuesi {
  const FurnizuesIPaLidhur();

  @override
  String get emri => 'Ende pa furnizues';

  @override
  bool get mundBlihet => false;

  @override
  bool get iVertete => false;

  @override
  Future<Profili> blej(Paketa paketa, {required String porosiaId, String? kapja}) async =>
      throw const GabimFurnizuesi(
        'Shitja ende nuk ka nisur. Çmimet janë orientuese.',
        rikthyeshem: false,
      );

  @override
  Future<double?> gigabajtTeMbetur(Profili profili) async => null;
}
