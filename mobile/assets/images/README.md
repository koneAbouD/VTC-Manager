# Assets images

Logos de l'application TMK :

- `logo_tmk.png` : logo affiché sur l'écran de connexion (login).
  Peut être rectangulaire (ex. 1109×613). Fond blanc OK.

- `logo_tmk_icon.png` : source de l'icône de lancement Android/iOS.
  **Doit être CARRÉ** (ex. 1024×1024), fond blanc.

## Régénérer l'icône de lancement
Après avoir déposé `logo_tmk_icon.png` :

    flutter pub get
    dart run flutter_launcher_icons
