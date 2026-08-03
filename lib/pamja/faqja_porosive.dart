/// Porositë e blerësit. Gjendja `deshtoi` shfaqet po aq qartë sa `dhene` —
/// një blerje e paguar pa profil është pikërisht ajo që nuk guxon të fshihet.
library;

import 'package:flutter/material.dart';

import '../modele/modele.dart';
import '../te_dhena/katalogu.dart';
import 'faqja_profilit.dart';

class FaqjaPorosive extends StatelessWidget {
  const FaqjaPorosive({super.key, required this.porosite, required this.katalogu});

  final List<Porosia> porosite;
  final Katalogu katalogu;

  @override
  Widget build(BuildContext context) {
    if (porosite.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Ende asnjë eSIM.\nZgjidh një shtet te «Blej».',
              textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      itemCount: porosite.length,
      itemBuilder: (_, i) {
        final p = porosite[i];
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
      },
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
