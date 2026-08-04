/// Modelet e eSIM Space-it.
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

/// Një eSIM që blerësi e ka nga diku tjetër dhe e mban këtu.
///
/// 🔑 Kjo është e vetmja gjë e dobishme që aplikacioni bën PA asnjë furnizues:
/// QR-të e eSIM-eve vijnë si email ose si foto dhe humbin menjëherë, kurse
/// telefoni nuk e skanon dot ekranin e vet. Këtu ruhen, rivizatohen si QR dhe
/// mbahen bashkë me shënimin se ku vlejnë dhe kur skadojnë.
class ESimIm {
  const ESimIm({
    required this.id,
    required this.emri,
    required this.lpa,
    required this.kur,
    this.shenim,
    this.skadon,
  });

  final String id;
  final String emri;
  final String lpa;
  final DateTime kur;
  final String? shenim;
  final DateTime? skadon;

  Map<String, dynamic> teJson() => {
        'id': id,
        'emri': emri,
        'lpa': lpa,
        'kur': kur.toIso8601String(),
        if (shenim != null) 'shenim': shenim,
        if (skadon != null) 'skadon': skadon!.toIso8601String(),
      };

  factory ESimIm.ngaJson(Map<String, dynamic> j) => ESimIm(
        id: j['id'] as String,
        emri: j['emri'] as String,
        lpa: j['lpa'] as String,
        kur: DateTime.parse(j['kur'] as String),
        shenim: j['shenim'] as String?,
        skadon: j['skadon'] == null ? null : DateTime.parse(j['skadon'] as String),
      );

  /// Një LPA e vlefshme ka formën `LPA:1$<serveri>$<kodi>`; serveri është i
  /// detyrueshëm, kodi jo (disa profile aktivizohen vetëm me serverin).
  ///
  /// 🚨 Kontrollohet PARA se të ruhet: një varg i gabuar bëhet një QR që
  /// telefoni e skanon dhe e refuzon, dhe atëherë blerësi mendon se profili
  /// është i prishur — jo se e ngjiti gabim.
  static String? gabimiILpas(String tekst) {
    final t = tekst.trim();
    if (t.isEmpty) return 'Ngjit kodin LPA ose kodin e aktivizimit.';
    if (!t.toUpperCase().startsWith('LPA:')) {
      return 'Duhet të nisë me «LPA:» — kështu e njeh telefoni.';
    }
    final pjeset = t.split(r'$');
    if (pjeset.length < 2 || pjeset[1].trim().isEmpty) {
      return 'Mungon serveri. Forma është LPA:1\$serveri\$kodi';
    }
    return null;
  }
}
