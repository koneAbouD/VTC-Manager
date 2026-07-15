/// Portefeuille Mobile Money (valeur API = name MAJUSCULES côté backend).
enum CanalPaiement {
  wave('WAVE', 'Wave'),
  orangeMoney('ORANGE_MONEY', 'Orange Money'),
  mtnMomo('MTN_MOMO', 'MTN MoMo'),
  moovMoney('MOOV_MONEY', 'Moov Money');

  final String api;
  final String label;
  const CanalPaiement(this.api, this.label);
}
