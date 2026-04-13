import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    final user = await AuthService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);

    if (user != null) {
      Navigator.pushReplacementNamed(context, '/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível entrar. Tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _continueWithoutAccount() {
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F0),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset('assets/images/logo.png', width: 200),
                const SizedBox(height: 16),
                const Text(
                  'Papel & Create',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Entre com sua conta para sincronizar\nseus dados em qualquer dispositivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),

                // Botão Google
                _loading
                    ? const CircularProgressIndicator(
                        color: Color(0xFFC17FD4))
                    : SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: _GoogleIcon(),
                          label: const Text(
                            'Entrar com Google',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                                color: Color(0xFFDDDCD7)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 20),

                // Continuar sem conta
                TextButton(
                  onPressed: _continueWithoutAccount,
                  child: const Text(
                    'Continuar sem conta',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF888888),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sem conta, os dados ficam só neste dispositivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFAAAAAA),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Círculo base
    paint.color = Colors.white;
    canvas.drawCircle(center, radius, paint);

    // Letras G simplificadas como arcos coloridos
    final rect = Rect.fromCircle(center: center, radius: radius * 0.75);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = radius * 0.28;
    paint.strokeCap = StrokeCap.round;

    paint.color = const Color(0xFF4285F4); // azul
    canvas.drawArc(rect, -0.52, 1.57, false, paint);

    paint.color = const Color(0xFF34A853); // verde
    canvas.drawArc(rect, 1.05, 1.57, false, paint);

    paint.color = const Color(0xFFFBBC05); // amarelo
    canvas.drawArc(rect, 2.62, 0.78, false, paint);

    paint.color = const Color(0xFFEA4335); // vermelho
    canvas.drawArc(rect, -1.57, 1.05, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
