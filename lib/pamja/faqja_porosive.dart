/// «Të miat» — eSIM-et e ruajtura nga blerësi, dhe porositë.
///
/// Gjendja `deshtoi` shfaqet po aq qartë sa `dhene`: një blerje e paguar pa
/// profil është pikërisht ajo që nuk guxon të fshihet.
library;

import 'package:flutter/material.dart';

import '../app/ads.dart';
import '../furnizuesi/furnizuesi.dart';
import '../modele/modele.dart';
import '../te_dhena/katalogu.dart';
import '../te_dhena/ruajtja.dart';
import 'faqja_profilit.dart';
import 'faqja_shto.dart';
import 'shenja_e_shtetit.dart';

class FaqjaPorosive extends StatelessWidget {
  const FaqjaPorosive({
    super.key,
    required this.porosite,
    required this.esimet,
    required this.katalogu,
    required this.ruajtja,
    required this.rifresko,
    required this.furnizuesi,
  });

  final List<Porosia> porosite;
  final List<ESimIm> esimet;
  final Katalogu katalogu;
  final Ruajtja ruajtja;
  final VoidCallback rifresko;

  /// I duhet vetëm riprovimit të dorëzimit — shih [_RreshtiIPorosise].
  final Furnizuesi furnizuesi;

  @override
  Widget build(BuildContext context) {
    final bosh = porosite.isEmpty && esimet.isEmpty;
    return Scaffold(
      body: bosh
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Ende asnjë eSIM.\n\nKe një eSIM nga diku tjetër? Ruaje këtu me '
                  '«+» dhe kodi i tij QR do të jetë gjithnjë me ty, edhe pa internet.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: [
                if (esimet.isNotEmpty) ...[
                  const _Titull('TË RUAJTURA NGA TI'),
                  for (final e in esimet)
                    Dismissible(
                      key: ValueKey(e.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline),
                      ),
                      onDismissed: (_) async {
                        await ruajtja.fshiEsim(e.id);
                        rifresko();
                      },
                      child: ListTile(
                        leading: const Icon(Icons.sim_card_outlined),
                        title: Text(e.emri),
                        subtitle: Text(_nenshkrimi(e)),
                        trailing: const Icon(Icons.qr_code_2),
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                              builder: (_) => FaqjaProfilit.iImi(esim: e),
                            ))
                            .then((_) => Ads.maybeShowAfterQr()),
                      ),
                    ),
                ],
                if (porosite.isNotEmpty) ...[
                  const _Titull('POROSITË'),
                  for (final p in porosite)
                    _RreshtiIPorosise(
                      key: ValueKey(p.id),
                      porosia: p,
                      katalogu: katalogu,
                      ruajtja: ruajtja,
                      furnizuesi: furnizuesi,
                      rifresko: rifresko,
                    ),
                ],
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => FaqjaShto(ruajtja: ruajtja)),
          );
          if (ok == true) rifresko();
        },
        icon: const Icon(Icons.add),
        label: const Text('Shto eSIM-in tënd'),
      ),
    );
  }

  String _nenshkrimi(ESimIm e) {
    final pjeset = <String>[];
    if (e.shenim != null) pjeset.add(e.shenim!);
    if (e.skadon != null) {
      final mbeten = e.skadon!.difference(DateTime.now()).inDays;
      pjeset.add(mbeten < 0 ? 'ka skaduar' : 'skadon për $mbeten ditë');
    }
    return pjeset.isEmpty ? 'prek për kodin QR' : pjeset.join(' · ');
  }

}

/// Një porosi, me rrugën e daljes nga rasti më i keq.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// 🚨🚨 «Pagova dhe nuk mora asgjë» — pse ky rresht është i veçantë
///
/// Pagesa dhe dorëzimi janë dy sisteme të ndryshme (PayPal dhe Airalo), ndaj
/// ekziston gjithnjë një çast ku e para ka kaluar dhe e dyta jo. Deri më
/// 17-08-2026 aplikacioni e shfaqte atë gjendje dhe **e linte aty**: blerësi
/// shihte «Dështoi», dhe e vetmja gjë që mund të bënte ishte të paguante sërish.
///
/// Riprovimi këtu dërgon TË NJËJTËN kapje. Relaja e njeh (`porosite[kapja]`) dhe
/// kthen të njëjtën porosi pa porositur sërish — pra riprovimi është i sigurt sa
/// herë të shtypet. Pa atë veti te relaja, ky buton do të ishte një mënyrë për
/// të blerë dy paketa me një pagesë.
class _RreshtiIPorosise extends StatefulWidget {
  const _RreshtiIPorosise({
    super.key,
    required this.porosia,
    required this.katalogu,
    required this.ruajtja,
    required this.furnizuesi,
    required this.rifresko,
  });

  final Porosia porosia;
  final Katalogu katalogu;
  final Ruajtja ruajtja;
  final Furnizuesi furnizuesi;
  final VoidCallback rifresko;

  @override
  State<_RreshtiIPorosise> createState() => _RreshtiIPorosiseState();
}

class _RreshtiIPorosiseState extends State<_RreshtiIPorosise> {
  bool _duke = false;

  /// A ka kuptim të riprovohet: paguar (ose dështuar) DHE me kapje të ruajtur.
  /// Pa kapje, riprovimi do të kthente prapë 402 — pra një buton që dështon
  /// gjithnjë, që është më keq se asnjë buton.
  bool get _mundRiprovohet =>
      widget.porosia.kapja != null &&
      widget.porosia.profili == null &&
      (widget.porosia.gjendja == GjendjaEPorosise.paguar ||
          widget.porosia.gjendja == GjendjaEPorosise.deshtoi);

  Future<void> _riprovo() async {
    setState(() => _duke = true);
    final p = widget.porosia;
    try {
      final profili = await widget.furnizuesi.blej(
        widget.katalogu.paketa(p.paketaId),
        porosiaId: p.id,
        kapja: p.kapja,
      );
      await widget.ruajtja.perditeso(
          p.me(gjendja: GjendjaEPorosise.dhene, profili: profili));
      if (!mounted) return;
      setState(() => _duke = false);
      widget.rifresko();
    } on GabimFurnizuesi catch (e) {
      await widget.ruajtja
          .perditeso(p.me(gjendja: GjendjaEPorosise.deshtoi, gabimi: e.mesazhi));
      if (!mounted) return;
      setState(() => _duke = false);
      widget.rifresko();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(e.mesazhi),
          duration: const Duration(seconds: 8),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.porosia;
    final shteti = widget.katalogu.shteti(p.kodiIShtetit);
    final paketa = widget.katalogu.paketa(p.paketaId);
    final gati = p.gjendja == GjendjaEPorosise.dhene;
    return ListTile(
      leading: ShenjaEShtetit(shteti.kodi),
      title: Text('${shteti.emri} · ${paketa.sasia}'),
      subtitle: Text(_pershkrimi(p)),
      trailing: _duke
          ? const SizedBox(
              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          : gati
              ? const Icon(Icons.qr_code_2)
              : _mundRiprovohet
                  ? IconButton(
                      tooltip: 'Riprovo dorëzimin',
                      icon: const Icon(Icons.refresh),
                      onPressed: _riprovo,
                    )
                  : Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.error),
      // 🚨 Reklama vjen te `.then`, pra PAS mbylljes së kodit QR — kurrë para
      // hapjes së tij. Shih arsyetimin te `Ads.maybeShowAfterQr`.
      onTap: !gati
          ? null
          : () => Navigator.of(context)
              .push(MaterialPageRoute(
                builder: (_) => FaqjaProfilit(porosia: p, katalogu: widget.katalogu),
              ))
              .then((_) => Ads.maybeShowAfterQr()),
    );
  }

  String _pershkrimi(Porosia p) => switch (p.gjendja) {
        GjendjaEPorosise.dhene => 'Gati — prek për kodin QR',
        GjendjaEPorosise.paguar => p.kapja == null
            ? 'Paguar, po pritet profili'
            : 'Paguar — prek ↻ për ta marrë profilin',
        GjendjaEPorosise.deshtoi => p.kapja == null
            ? (p.gabimi ?? 'Dështoi')
            : '${p.gabimi ?? 'Dorëzimi dështoi'} · pagesa është e ruajtur, prek ↻',
        GjendjaEPorosise.rimbursuar => 'Të hollat u kthyen',
        GjendjaEPorosise.nisur => 'E nisur',
      };
}

class _Titull extends StatelessWidget {
  const _Titull(this.teksti);

  final String teksti;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(teksti, style: Theme.of(context).textTheme.labelSmall),
      );
}
