/// «Të miat» — eSIM-et e ruajtura nga blerësi, dhe porositë.
///
/// Gjendja `deshtoi` shfaqet po aq qartë sa `dhene`: një blerje e paguar pa
/// profil është pikërisht ajo që nuk guxon të fshihet.
library;

import 'package:flutter/material.dart';

import '../modele/modele.dart';
import '../te_dhena/katalogu.dart';
import '../te_dhena/ruajtja.dart';
import 'faqja_profilit.dart';
import 'faqja_shto.dart';

class FaqjaPorosive extends StatelessWidget {
  const FaqjaPorosive({
    super.key,
    required this.porosite,
    required this.esimet,
    required this.katalogu,
    required this.ruajtja,
    required this.rifresko,
  });

  final List<Porosia> porosite;
  final List<ESimIm> esimet;
  final Katalogu katalogu;
  final Ruajtja ruajtja;
  final VoidCallback rifresko;

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
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => FaqjaProfilit.iImi(esim: e),
                        )),
                      ),
                    ),
                ],
                if (porosite.isNotEmpty) ...[
                  const _Titull('POROSITË'),
                  for (final p in porosite) _rreshtiIPorosise(context, p),
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

  Widget _rreshtiIPorosise(BuildContext context, Porosia p) {
    final shteti = katalogu.shteti(p.kodiIShtetit);
    final paketa = katalogu.paketa(p.paketaId);
    return ListTile(
      leading: Text(shteti.flamuri, style: const TextStyle(fontSize: 26)),
      title: Text('${shteti.emri} · ${paketa.sasia}'),
      subtitle: Text(_pershkrimi(p)),
      trailing: p.gjendja == GjendjaEPorosise.dhene
          ? const Icon(Icons.qr_code_2)
          : Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
      onTap: p.gjendja != GjendjaEPorosise.dhene
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FaqjaProfilit(porosia: p, katalogu: katalogu),
              )),
    );
  }

  String _pershkrimi(Porosia p) => switch (p.gjendja) {
        GjendjaEPorosise.dhene => 'Gati — prek për kodin QR',
        GjendjaEPorosise.paguar => 'Paguar, po pritet profili',
        GjendjaEPorosise.deshtoi => p.gabimi ?? 'Dështoi',
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
