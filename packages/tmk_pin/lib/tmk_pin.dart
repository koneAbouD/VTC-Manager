/// Code d'accès local (verrou d'application) partagé par les applications TMK.
///
/// Le code à 5 chiffres ne remplace pas la connexion : il rouvre une session
/// déjà obtenue, dont le refresh token n'existe sur l'appareil que chiffré par
/// une clé dérivée du code. Sans le bon code, rien n'est exploitable.
library tmk_pin;

export 'src/biometric_service.dart';
export 'src/jwt_claims.dart';
export 'src/pin_cipher.dart' show PinCipher, PinVault;
export 'src/pin_service.dart';
export 'src/pin_store.dart'
    show
        InMemoryKeyValueStore,
        PinKeyValueStore,
        PinStore,
        SecureKeyValueStore;
export 'src/widgets/pin_boxes.dart';
export 'src/widgets/pin_keypad.dart';
export 'src/widgets/pin_layout.dart';
export 'src/widgets/pin_theme.dart';
