/// Porositë e blerësit, të ruajtura VETËM në pajisje.
///
/// Nuk ka llogari dhe nuk ka server: derisa të ekzistojë një furnizues i
/// vërtetë, asnjë e dhënë e blerësit nuk ka ku të shkojë. Kjo është edhe
/// përgjigjja te «Siguria e të dhënave» — dhe ajo përgjigje duhet rishikuar në
/// ditën që hyn pagesa, sepse atëherë të dhënat nisin të dalin nga pajisja.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../modele/modele.dart';

class Ruajtja {
  Ruajtja._(this._p);

  static const _celesi = 'porosite.v1';

  final SharedPreferences _p;

  static Future<Ruajtja> hap() async => Ruajtja._(await SharedPreferences.getInstance());

  List<Porosia> porosite() {
    final teksti = _p.getString(_celesi);
    if (teksti == null || teksti.isEmpty) return const [];
    try {
      return (jsonDecode(teksti) as List)
          .map((e) => Porosia.ngaJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on FormatException {
      // 🚨 Një hyrje e prishur NUK i fshin të gjitha porositë e tjera pa pyetur.
      // Kthehet listë bosh dhe teksti i vjetër mbetet aty, që të mos humbë një
      // profil i paguar vetëm sepse formati ndryshoi.
      return const [];
    }
  }

  Future<void> ruaj(List<Porosia> porosite) =>
      _p.setString(_celesi, jsonEncode([for (final p in porosite) p.teJson()]));

  Future<List<Porosia>> shto(Porosia p) async {
    final l = [p, ...porosite()];
    await ruaj(l);
    return l;
  }

  Future<List<Porosia>> perditeso(Porosia p) async {
    final l = porosite().map((e) => e.id == p.id ? p : e).toList();
    await ruaj(l);
    return l;
  }
}
