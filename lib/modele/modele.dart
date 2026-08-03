/// Modelet e SpaceSIM-it.
///
/// Të gjitha janë të pandryshueshme dhe dinë ta lexojnë veten nga JSON-i, sepse
/// i njëjti format vjen sot nga `assets/katalogu.json` dhe nesër nga API-ja e
/// furnizuesit. Nëse modelet do ta njihnin njërin burim, ndërrimi do të ishte
/// rishkrim.
library;

class Shteti {
  const Shteti({
    required this.kodi,
    required this.emri,
    required this.flamuri,
    required this.rajoni,
  });

  /// ISO 3166-1 alpha-2, me shkronja të mëdha ('XK' për Kosovën).
  final String kodi;
  final String emri;

  /// Flamuri si dy shkronja rajonale Unicode — pa asnjë figurë dhe pa asnjë
  /// skedar imazhi; e vizaton vetë fonti i sistemit.
  final String flamuri;
  final String rajoni;

  factory Shteti.ngaJson(Map<String, dynamic> j) => Shteti(
        kodi: j['kodi'] as String,
        emri: j['emri'] as String,
        flamuri: j['flamuri'] as String,
        rajoni: j['rajoni'] as String,
      );
}

class Paketa {
  const Paketa({
    required this.id,
    required this.kodiIShtetit,
    required this.gigabajt,
    required this.dite,
    required this.centa,
    required this.rrjetet,
  });

  final String id;
  final String kodiIShtetit;
  final double gigabajt;
  final int dite;

  /// 🚨 Çmimi mbahet në **centa si numër i plotë**, kurrë si `double`. Një
  /// çmim me presje dhjetore mblidhet me gabim rrumbullakimi, dhe te një
  /// shportë me disa artikuj ai gabim del te shuma që sheh blerësi.
  final int centa;
  final List<String> rrjetet;

  String get cmimi => '${(centa / 100).toStringAsFixed(2)} €';

  String get sasia =>
      gigabajt == gigabajt.roundToDouble() ? '${gigabajt.round()} GB' : '$gigabajt GB';

  factory Paketa.ngaJson(Map<String, dynamic> j) => Paketa(
        id: j['id'] as String,
        kodiIShtetit: j['shteti'] as String,
        gigabajt: (j['gb'] as num).toDouble(),
        dite: j['dite'] as int,
        centa: j['centa'] as int,
        rrjetet: (j['rrjetet'] as List).cast<String>(),
      );
}

/// Gjendja e një porosie. `paguar` dhe `dhene` janë të NDARA me qëllim: pagesa
/// mund të kalojë dhe furnizuesi të dështojë, dhe atëherë blerësi ka paguar pa
/// marrë profil — pikërisht rasti që duhet të jetë i dukshëm në të dhëna, jo i
/// fshehur pas një flamuri të vetëm «e suksesshme».
enum GjendjaEPorosise { nisur, paguar, dhene, deshtoi, rimbursuar }

class Profili {
  const Profili({
    required this.lpa,
    required this.iccid,
    this.kodiIAktivizimit,
  });

  /// Vargu `LPA:1$<serveri>$<kodi>` — pikërisht ai që kodohet te QR-i dhe që
  /// sistemi operativ e njeh si profil eSIM.
  final String lpa;
  final String iccid;
  final String? kodiIAktivizimit;

  Map<String, dynamic> teJson() => {
        'lpa': lpa,
        'iccid': iccid,
        if (kodiIAktivizimit != null) 'kodi': kodiIAktivizimit,
      };

  factory Profili.ngaJson(Map<String, dynamic> j) => Profili(
        lpa: j['lpa'] as String,
        iccid: j['iccid'] as String,
        kodiIAktivizimit: j['kodi'] as String?,
      );
}

class Porosia {
  const Porosia({
    required this.id,
    required this.paketaId,
    required this.kodiIShtetit,
    required this.centa,
    required this.kur,
    required this.gjendja,
    this.profili,
    this.gabimi,
  });

  final String id;
  final String paketaId;
  final String kodiIShtetit;
  final int centa;
  final DateTime kur;
  final GjendjaEPorosise gjendja;
  final Profili? profili;
  final String? gabimi;

  Porosia me({GjendjaEPorosise? gjendja, Profili? profili, String? gabimi}) =>
      Porosia(
        id: id,
        paketaId: paketaId,
        kodiIShtetit: kodiIShtetit,
        centa: centa,
        kur: kur,
        gjendja: gjendja ?? this.gjendja,
        profili: profili ?? this.profili,
        gabimi: gabimi ?? this.gabimi,
      );

  Map<String, dynamic> teJson() => {
        'id': id,
        'paketa': paketaId,
        'shteti': kodiIShtetit,
        'centa': centa,
        'kur': kur.toIso8601String(),
        'gjendja': gjendja.name,
        if (profili != null) 'profili': profili!.teJson(),
        if (gabimi != null) 'gabimi': gabimi,
      };

  factory Porosia.ngaJson(Map<String, dynamic> j) => Porosia(
        id: j['id'] as String,
        paketaId: j['paketa'] as String,
        kodiIShtetit: j['shteti'] as String,
        centa: j['centa'] as int,
        kur: DateTime.parse(j['kur'] as String),
        gjendja: GjendjaEPorosise.values.firstWhere(
          (g) => g.name == j['gjendja'],
          orElse: () => GjendjaEPorosise.nisur,
        ),
        profili: j['profili'] == null
            ? null
            : Profili.ngaJson((j['profili'] as Map).cast<String, dynamic>()),
        gabimi: j['gabimi'] as String?,
      );
}
