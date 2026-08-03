/// Paketat e një shteti, dhe blerja.
library;

import 'package:flutter/material.dart';

import '../furnizuesi/furnizuesi.dart';
import '../modele/modele.dart';
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
  });

  final Shteti shteti;
  final Katalogu katalogu;
  final Ruajtja ruajtja;
  final Furnizuesi furnizuesi;

  @override
  State<FaqjaPaketave> createState() => _FaqjaPaketaveState();
}

class _FaqjaPaketaveState extends State<FaqjaPaketave> {
  bool _duke = false;

  @override
  Widget build(BuildContext context) {
    final paketat = widget.katalogu.perShtetin(widget.shteti.kodi);
    return Scaffold(
      appBar: AppBar(title: Text('${widget.shteti.flamuri}  ${widget.shteti.emri}')),
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
                trailing: FilledButton(
                  onPressed: _duke ? null : () => _blej(p),
                  child: Text(p.cmimi),
                ),
              ),
            ),
          if (_duke) const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  Future<void> _blej(Paketa p) async {
    setState(() => _duke = true);
    final id = 'sp${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

    // 🚨 Porosia shkruhet PARA se të thirret furnizuesi, jo pas. Nëse aplikacioni
    // vritet mes pagesës dhe përgjigjes, gjurma mbetet; ndryshe blerësi ka
    // paguar dhe pajisja nuk mban asnjë provë se ka ndodhur diçka.
    var porosia = Porosia(
      id: id,
      paketaId: p.id,
      kodiIShtetit: p.kodiIShtetit,
      centa: p.centa,
      kur: DateTime.now(),
      gjendja: GjendjaEPorosise.paguar,
    );
    await widget.ruajtja.shto(porosia);

    try {
      final profili = await widget.furnizuesi.blej(p, porosiaId: id);
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
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.mesazhi)));
    }
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
