import '../../features/chauffeur/domain/entities/chauffeur.dart';
import '../../features/vehicule/domain/entities/statut_vehicule.dart';
import '../../features/vehicule/domain/entities/vehicule.dart';

/// Génération des exports CSV de la flotte (véhicules / chauffeurs).
/// Partagé par les onglets « Véhicules » et « Chauffeurs » du FleetScreen.

String vehiculesToCsv(List<Vehicule> vehicules) {
  final buf = StringBuffer()
    ..writeln(
        'Immatriculation;Marque;Modèle;Couleur;Statut;Kilométrage (km);'
        'Groupe;Type activité;Date achat;Date mise en circulation;'
        'Date entrée flotte;Date prochaine maintenance');
  for (final v in vehicules) {
    buf.writeln([
      v.immatriculation,
      v.marque,
      v.modele,
      v.couleur ?? '',
      _statutVehiculeLabel(v.statut),
      '${v.kilometrage ?? ''}',
      v.groupe ?? '',
      v.typeActiviteNom ?? '',
      _fmtDate(v.dateAchat),
      _fmtDate(v.dateMiseEnCirculation),
      _fmtDate(v.dateEntreeFlotte),
      _fmtDate(v.dateProchaineMaintenance),
    ].map(_csvEscape).join(';'));
  }
  return buf.toString();
}

String chauffeursToCsv(List<Chauffeur> chauffeurs) {
  final buf = StringBuffer()
    ..writeln('Prénom;Nom;Téléphone;Email;Statut;Type;'
        'Véhicule assigné;Matricule;Date embauche');
  for (final c in chauffeurs) {
    buf.writeln([
      c.prenom,
      c.nom,
      c.telephone ?? '',
      c.email ?? '',
      c.statut?.label ?? '',
      c.type?.label ?? '',
      c.vehiculeNom ?? '',
      c.vehiculeMatricule ?? '',
      _fmtDate(c.dateEmbauche),
    ].map(_csvEscape).join(';'));
  }
  return buf.toString();
}

String _statutVehiculeLabel(String? s) {
  final st = StatutVehicule.resolve(s);
  return st.code.isEmpty ? (s ?? '') : st.libelle;
}

String _fmtDate(DateTime? d) {
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _csvEscape(String v) {
  if (v.contains(';') || v.contains('"') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}
