/// Shenja e një shteti: kodi ISO me dy shkronja brenda një pllake të rrumbullakosur.
///
/// 🕌 Zëvendëson emoji-t e flamujve. Dy nga katërmbëdhjetë flamujt e katalogut
/// (Shqipëria dhe Mali i Zi) vizatohen nga fonti i pajisjes si shqiponja — qenie
/// të gjalla — dhe një glif Unicode nuk ndreqet dot me kod: forma vjen nga
/// pajisja, jo nga ne. Shih [[workflow-pamja-pa-qenie-te-gjalla]].
///
/// 🔑 Nuk humb asnjë funksion: kodi është pikërisht ajo që shkruan njeriu kur
/// kërkon, dhe lexohet edhe atje ku flamujt nuk ekzistojnë fare (Windows, PC).
library;

import 'package:flutter/material.dart';

class ShenjaEShtetit extends StatelessWidget {
  const ShenjaEShtetit(this.kodi, {super.key, this.madhesia = 40});

  final String kodi;
  final double madhesia;

  @override
  Widget build(BuildContext context) {
    final ngjyrat = Theme.of(context).colorScheme;
    return Container(
      width: madhesia,
      height: madhesia,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ngjyrat.secondaryContainer,
        borderRadius: BorderRadius.circular(madhesia * 0.28),
      ),
      child: Text(
        kodi.toUpperCase(),
        style: TextStyle(
          fontSize: madhesia * 0.38,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: ngjyrat.onSecondaryContainer,
        ),
      ),
    );
  }
}
