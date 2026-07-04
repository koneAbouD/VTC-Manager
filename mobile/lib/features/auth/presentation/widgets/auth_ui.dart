import 'package:flutter/material.dart';

/// Kit d'UI partagé pour les écrans d'authentification (Login / Inscription /
/// Mot de passe oublié) — rendu « premium » cohérent.

// ── Palette ─────────────────────────────────────────────────────────────────

const kAuthPrimary = Color(0xFF43A047);
const kAuthPrimaryDark = Color(0xFF2E7D32);
const kAuthDark = Color(0xFF1A1A2E);
const kAuthHint = Color(0xFF8A94A6);
const kAuthFieldFill = Color(0xFFF3F6F4);
const kAuthBorder = Color(0xFFE4E9EE);
const kAuthError = Color(0xFFE03131);

// ── Toast ─────────────────────────────────────────────────────────────────

enum AuthToastType { success, error, warning, info }

void authToast(
  BuildContext context,
  String message, {
  AuthToastType type = AuthToastType.success,
  Duration? duration,
}) {
  final (Color bg, IconData icon) = switch (type) {
    AuthToastType.success =>
      (const Color(0xFF1B5E20), Icons.check_circle_outline_rounded),
    AuthToastType.error => (const Color(0xFFB71C1C), Icons.error_outline_rounded),
    AuthToastType.warning =>
      (const Color(0xFFE65100), Icons.warning_amber_rounded),
    AuthToastType.info => (const Color(0xFF1A237E), Icons.info_outline_rounded),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
        ),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration ??
          (type == AuthToastType.error || type == AuthToastType.warning
              ? const Duration(seconds: 4)
              : const Duration(seconds: 2)),
    ));
}

// ── Fond dégradé + back button optionnel ─────────────────────────────────────

class AuthScaffold extends StatelessWidget {
  final Widget child;
  final bool showBack;

  const AuthScaffold({super.key, required this.child, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Container(
        color: const Color(0xFFF8F9FB),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: child,
                  ),
                ),
              ),
              if (showBack)
                Positioned(
                  top: 4,
                  left: 8,
                  child: _CircleBackButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_back_rounded, size: 20, color: kAuthDark),
      ),
    );
  }
}

// ── Logo de marque + titre + sous-titre ──────────────────────────────────────

class AuthBrand extends StatelessWidget {
  final IconData icon;

  /// Chemin d'un logo asset à afficher (prioritaire sur [icon]). Le logo est
  /// encadré dans une carte blanche (le fond blanc du logo se fond dedans).
  final String? assetLogo;

  final String title;
  final String subtitle;
  final bool compact;

  const AuthBrand({
    super.key,
    this.icon = Icons.local_taxi_rounded,
    this.assetLogo,
    this.title = '',
    required this.subtitle,
    this.compact = false,
  });

  Widget _gradientBadge() {
    final badge = compact ? 64.0 : 84.0;
    return Container(
      width: badge,
      height: badge,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kAuthPrimary, kAuthPrimaryDark],
        ),
        borderRadius: BorderRadius.circular(compact ? 18 : 24),
        boxShadow: [
          BoxShadow(
            color: kAuthPrimary.withValues(alpha: 0.40),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, size: compact ? 32 : 42, color: Colors.white),
    );
  }

  Widget _logoCard() {
    final logoHeight = compact ? 78.0 : 104.0;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 20 : 26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Image.asset(
        assetLogo!,
        height: logoHeight,
        fit: BoxFit.contain,
        // Repli tant que le fichier logo n'est pas encore déposé.
        errorBuilder: (_, __, ___) => SizedBox(
          height: logoHeight,
          child: Center(child: _gradientBadge()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        assetLogo != null ? _logoCard() : _gradientBadge(),
        SizedBox(height: compact ? 14 : 20),
        if (title.isNotEmpty) ...[
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 22 : 26,
              fontWeight: FontWeight.w800,
              color: kAuthDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: kAuthHint,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ── Carte blanche conteneur du formulaire ────────────────────────────────────

class AuthCard extends StatelessWidget {
  final Widget child;
  const AuthCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDF1F4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Décoration de champ premium ──────────────────────────────────────────────

InputDecoration authInputDecoration({
  required String label,
  required IconData icon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color c, [double w = 1.2]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: kAuthHint),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: kAuthFieldFill,
    labelStyle: const TextStyle(color: kAuthHint, fontSize: 14),
    floatingLabelStyle:
        const TextStyle(color: kAuthPrimary, fontWeight: FontWeight.w600),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: border(kAuthBorder),
    border: border(kAuthBorder),
    focusedBorder: border(kAuthPrimary, 1.6),
    errorBorder: border(kAuthError),
    focusedErrorBorder: border(kAuthError, 1.6),
  );
}

// ── Bouton principal dégradé ─────────────────────────────────────────────────

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.loading = false,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kAuthPrimary, kAuthPrimaryDark],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: kAuthPrimary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 54,
              child: Center(
                child: loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
