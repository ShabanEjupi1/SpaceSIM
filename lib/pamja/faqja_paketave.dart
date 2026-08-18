/// Paketat e një shteti, dhe blerja.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../furnizuesi/furnizuesi.dart';
import '../modele/modele.dart';
import '../pagesa/pagesa.dart';
import '../te_dhena/katalogu.dart';
import '../te_dhena/ruajtja.dart';
import 'faqja_profilit.dart';

class FaqjaPaketave extends StatefulWidget {
  const FaqjaPaketave({
    super.key,
    required this.shteti,
    required this.katalogu,
    required this.ruajtja,
    required this.furnizuesi,
    required this.pagesa,
  });

  final Shteti shteti;
  final Katalogu katalogu;
  final Ruajtja ruajtja;
  final Furnizuesi furnizuesi;
  final Pagesa pagesa;

  @override
  State<FaqjaPaketave> createState() => _FaqjaPaketaveState();
}

class _FaqjaPaketaveState extends State<FaqjaPaketave> {
  bool _duke = false;

  @override
  Widget build(BuildContext context) {
    final paketat = widget.katalogu.perShtetin(widget.shteti.kodi);
    return Scaffold(
      appBar: AppBar(title: Text(widget.shteti.emri)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _KutiaEPajtueshmerise(),
          const SizedBox(height: 8),
          for (final p in paketat)
            Card(
              child: ListTile(
                title: Text('${p.sasia} · ${p.dite} ditë'),
                subtitle: Text(p.rrjetet.join(' · ')),
                // 🚨 TË DYJA: një furnizues i lidhur pa pagesë të lidhur është
                // pikërisht gjendja e 12→17 gushtit, ku butoni «4.50 €» dukej
                // krejt i zakonshëm dhe çdo shtypje e tij përfundonte me 402.
                trailing: widget.furnizuesi.mundBlihet && widget.pagesa.mundPaguhet
                    ? FilledButton(
                        onPressed: _duke ? null : () => _blej(p),
                        child: Text(p.cmimi),
                      )
                    // Pa furnizues çmimi tregohet, por butoni jo: një buton
                    // blerjeje që nuk blen dot është pikërisht ajo që Play-i e
                    // quan «funksion i prishur».
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(p.cmimi,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Text('orientues', style: TextStyle(fontSize: 11)),
                        ],
                      ),
              ),
            ),
          if (_duke) const Padding(
            padding: EdgeInsets.all(24),
            child: Column(children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              // 🔑 Teksti nuk është zbukurim: pritja zgjat sa i duhet blerësit
              // te PayPal-i — minuta, jo sekonda. Një rrotë pa fjalë atje lexohet
              // si «ngeci», dhe blerësi e mbyll aplikacionin mes pagesës.
              Text('Duke pritur konfirmimin e pagesës…',
                  textAlign: TextAlign.center),
              SizedBox(height: 4),
              Text('Mund të kthehesh te PayPal-i; kjo faqe pret.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }

  /// Blerja e plotë: pagesa së pari, porosia pastaj.
  ///
  /// 🚨 Rendi është i pandryshueshëm dhe **porosia shkruhet vetëm pasi paratë
  /// kanë ikur vërtet**. Deri më 17-08-2026 ndodhte e kundërta: porosia
  /// shkruhej menjëherë me gjendjen `paguar`, pa asnjë pagesë, ndaj historiku i
  /// blerësit mbushej me «të paguara» për blerje që s'kishin ndodhur kurrë.
  Future<void> _blej(Paketa p) async {
    setState(() => _duke = true);

    final String kapja;
    try {
      final nisur = await widget.pagesa.nis(p);
      if (!mounted) return;
      // Shuma e vërtetë vjen nga relaja; shih [PagesaENisur.centa].
      final hapi = await _konfirmo(nisur);
      if (!hapi) {
        setState(() => _duke = false);
        return;
      }
      kapja = await widget.pagesa.prit(nisur.ref);
    } on GabimPagese catch (e) {
      if (!mounted) return;
      setState(() => _duke = false);
      // Anulimi nuk është dështim: asnjë shumë nuk u mor, ndaj as ngjyrë e kuqe
      // as fjala «gabim».
      _thuaj(e.mesazhi, gabim: !e.anuluar);
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _duke = false);
      _thuaj('Pagesa nuk u nis: $e');
      return;
    }

    // 🚨 Nga këtu tutje blerësi KA PAGUAR. Porosia shkruhet para se të thirret
    // furnizuesi, me `kapja` brenda: nëse aplikacioni vritet në këtë çast, te
    // pajisja mbetet e vetmja provë e pagesës, dhe dorëzimi riprovohet me të —
    // pa pagesë të dytë. Shih [Porosia.kapja].
    final id = 'sp${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    var porosia = Porosia(
      id: id,
      paketaId: p.id,
      kodiIShtetit: p.kodiIShtetit,
      centa: p.centa,
      kur: DateTime.now(),
      gjendja: GjendjaEPorosise.paguar,
      kapja: kapja,
    );
    await widget.ruajtja.shto(porosia);

    try {
      final profili = await widget.furnizuesi.blej(p, porosiaId: id, kapja: kapja);
      porosia = porosia.me(gjendja: GjendjaEPorosise.dhene, profili: profili);
      await widget.ruajtja.perditeso(porosia);
      if (!mounted) return;
      setState(() => _duke = false);
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FaqjaProfilit(porosia: porosia, katalogu: widget.katalogu),
      ));
    } on GabimFurnizuesi catch (e) {
      porosia = porosia.me(gjendja: GjendjaEPorosise.deshtoi, gabimi: e.mesazhi);
      await widget.ruajtja.perditeso(porosia);
      if (!mounted) return;
      setState(() => _duke = false);
      _thuaj('${e.mesazhi} Pagesa u ruajt — riprovo te «Të miat».');
    }
  }

  void _thuaj(String teksti, {bool gabim = true}) {
    final n = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(teksti),
        backgroundColor: gabim ? n.errorContainer : null,
        // 🚨 Mesazhet e pagesës janë të gjata dhe blerësi duhet t'i lexojë deri
        // në fund: parazgjedhja prej 4 sekondash i fshin para se të mbarojë
        // fjalia, pikërisht atje ku ajo fjali thotë «mos paguaj sërish».
        duration: const Duration(seconds: 8),
      ));
  }

  /// Fleta e fundit para se të hapet PayPal-i.
  ///
  /// 🔑 Ekziston për një arsye teknike përveç asaj njerëzore: hapja e një
  /// adrese duhet të vijë nga një **prekje e blerësit**. Te web-i, një `launch`
  /// pas një `await` bllokohet si dritare vetëhapëse, dhe blerësi mbetet me një
  /// buton që nuk bën asgjë — pa asnjë gabim.
  Future<bool> _konfirmo(PagesaENisur nisur) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      builder: (kontekst) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Paguaj ${nisur.shuma}',
                  style: Theme.of(kontekst).textTheme.titleLarge),
              const SizedBox(height: 10),
              const Text('Pagesa hapet te PayPal-i, jashtë aplikacionit. '
                  'Pasi ta konfirmosh, kthehu këtu — eSIM-i vjen vetë.'),
              const SizedBox(height: 18),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Vazhdo te PayPal'),
                onPressed: () async {
                  final u = Uri.parse(nisur.url);
                  final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
                  if (!kontekst.mounted) return;
                  Navigator.of(kontekst).pop(ok);
                },
              ),
              TextButton(
                onPressed: () => Navigator.of(kontekst).pop(false),
                child: const Text('Anulo'),
              ),
            ],
          ),
        ),
      ),
    );
    return r ?? false;
  }
}

/// Kontrolli i pajtueshmërisë shfaqet PARA çmimeve me qëllim: shkaku më i
/// shpeshtë i ankesave te ky zhanër është një telefon që s'e mban eSIM-in ose
/// është i kyçur nga operatori — dhe atëherë blerja ka ndodhur tashmë.
class _KutiaEPajtueshmerise extends StatelessWidget {
  const _KutiaEPajtueshmerise();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A e mban telefoni yt eSIM?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Shkruaj *#06# te telefonuesi. Nëse shfaqet një numër EID '
                '(32 shifra), pajisja e mban eSIM-in.\n'
                'Telefoni duhet të jetë edhe i pakyçur nga operatori — një '
                'pajisje e kyçur e refuzon profilin edhe kur EID-i ekziston.'),
          ],
        ),
      ),
    );
  }
}
