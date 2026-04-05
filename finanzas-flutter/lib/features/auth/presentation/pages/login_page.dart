import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = ref.read(firebaseAuthServiceProvider);
      final user = await service.signInWithGoogle();
      if (user == null && mounted) {
        setState(() { _loading = false; });
      }
      // Si el usuario se autenticó, el authStateProvider emite un User
      // y el router redirige automáticamente al home.
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = 'Error al iniciar sesión. Intentá de nuevo.'; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Logo / Ícono ──
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Finanzas',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu app de finanzas personales',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.white38,
                ),
              ),

              const Spacer(flex: 3),

              // ── Botón Google Sign-In ──
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                height: 52,
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _signIn,
                        icon: Image.asset(
                          'assets/google_logo.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.login_rounded,
                            size: 20,
                            color: Colors.white70,
                          ),
                        ),
                        label: Text(
                          'Continuar con Google',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 16),
              Text(
                'Tus datos se guardan de forma segura en tu cuenta.',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white24),
                textAlign: TextAlign.center,
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
