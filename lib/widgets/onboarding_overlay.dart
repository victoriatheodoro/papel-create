import 'package:flutter/material.dart';

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onDone;
  /// Posições exatas (em pixels de tela) para o spotlight de cada passo.
  /// Se o offset do passo for não-nulo, ele sobrescreve o Alignment estático.
  /// Use GlobalKey + RenderBox.localToGlobal para obter offsets precisos.
  final List<Offset?> spotlightOffsets;

  const OnboardingOverlay({
    super.key,
    required this.onDone,
    this.spotlightOffsets = const [],
  });

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  int _step = 0;

  static const _steps = [
    _OnboardingStep(
      icon: Icons.auto_stories_outlined,
      title: 'Seu caderno, agora digital!',
      body:
          'O Papel & Create transforma as anotações do seu caderno físico em tarefas e eventos organizados — acessíveis de qualquer lugar, pelo celular ou computador.',
      alignTop: true,
      verticalFraction: 0.25,
      showSymbols: false,
      spotlight: Alignment(0, -0.65),
      spotlightRadius: 80,
    ),
    _OnboardingStep(
      icon: Icons.add_circle_outline,
      title: 'Transformar em Digital',
      body:
          'Toque no ícone "+" no canto superior direito para escanear uma página do caderno ou criar uma atividade manualmente.',
      alignTop: true,
      verticalFraction: 0.10,
      showSymbols: false,
      spotlight: Alignment(0.88, -0.86),
      spotlightRadius: 30,
    ),
    _OnboardingStep(
      icon: Icons.search_outlined,
      title: 'Busca rápida',
      body:
          'Toque no ícone de lupa para pesquisar tarefas e eventos por palavra-chave. Útil para encontrar rapidamente algo que você anotou.',
      alignTop: true,
      verticalFraction: 0.10,
      showSymbols: false,
      spotlight: Alignment(0.48, -0.86),
      spotlightRadius: 30,
    ),
    _OnboardingStep(
      icon: Icons.edit_note_outlined,
      title: 'Símbolos reconhecidos',
      body:
          'Para o app ler corretamente seu caderno, use estes símbolos. Apenas eles são reconhecidos no escaneamento:',
      alignTop: false,
      verticalFraction: 0.78,
      showSymbols: true,
      spotlight: null,
      spotlightRadius: 0,
    ),
    _OnboardingStep(
      icon: Icons.folder_outlined,
      title: 'Grupos',
      body:
          'Seus grupos organizam tarefas e eventos. Toque num card para ver, editar e acompanhar o progresso.',
      alignTop: true,
      verticalFraction: 0.09,
      showSymbols: false,
      spotlight: Alignment(0, -0.10),
      spotlightRadius: 90,
    ),
    _OnboardingStep(
      icon: Icons.calendar_month_outlined,
      title: 'Mini-calendário',
      body:
          'O botão "Calendário" no canto inferior esquerdo mostra seus eventos por data. Toque num dia marcado para ver detalhes e navegar ao grupo.',
      alignTop: true,
      verticalFraction: 0.55,
      showSymbols: false,
      spotlight: Alignment(-0.60, 0.90),
      spotlightRadius: 38,
    ),
  ];

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final size = MediaQuery.of(context).size;
    final isLast = _step == _steps.length - 1;

    // Usa offset exato (medido via GlobalKey) se disponível; caso contrário
    // usa o Alignment estático do passo.
    final exactOffset = _step < widget.spotlightOffsets.length
        ? widget.spotlightOffsets[_step]
        : null;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Overlay escuro com spotlight (buraco no elemento destacado)
          GestureDetector(
            onTap: _next,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: CustomPaint(
                painter: _SpotlightPainter(
                  spotlight: step.spotlight,
                  exactOffset: exactOffset,
                  spotlightRadius: step.spotlightRadius,
                ),
              ),
            ),
          ),
          // Balão de dica
          Positioned(
            left: 16,
            right: 16,
            top: step.alignTop ? size.height * step.verticalFraction : null,
            bottom: step.alignTop
                ? null
                : size.height * (1 - step.verticalFraction),
            child: _TooltipBalloon(
              icon: step.icon,
              title: step.title,
              body: step.body,
              step: _step + 1,
              total: _steps.length,
              isLast: isLast,
              showSymbols: step.showSymbols,
              onNext: _next,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String body;
  final bool alignTop;
  final double verticalFraction;
  final bool showSymbols;
  final Alignment? spotlight;
  final double spotlightRadius;

  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.alignTop,
    required this.verticalFraction,
    required this.showSymbols,
    required this.spotlight,
    required this.spotlightRadius,
  });
}

class _SpotlightPainter extends CustomPainter {
  final Alignment? spotlight;
  final Offset? exactOffset; // posição exata medida via GlobalKey (prioridade)
  final double spotlightRadius;

  const _SpotlightPainter({
    required this.spotlight,
    required this.spotlightRadius,
    this.exactOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Fundo escuro
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withOpacity(0.65),
    );

    // Determina o centro: usa offset exato se disponível, senão Alignment
    final Offset? center = exactOffset ??
        (spotlight != null
            ? spotlight!.withinRect(Rect.fromLTWH(0, 0, size.width, size.height))
            : null);

    if (center != null && spotlightRadius > 0) {
      // Buraco transparente (spotlight)
      canvas.drawCircle(
        center,
        spotlightRadius,
        Paint()..blendMode = BlendMode.clear,
      );

      // Anel branco semi-transparente ao redor
      canvas.drawCircle(
        center,
        spotlightRadius + 3,
        Paint()
          ..color = Colors.white.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.spotlight != spotlight ||
      old.exactOffset != exactOffset ||
      old.spotlightRadius != spotlightRadius;
}

class _TooltipBalloon extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final int step;
  final int total;
  final bool isLast;
  final bool showSymbols;
  final VoidCallback onNext;

  const _TooltipBalloon({
    required this.icon,
    required this.title,
    required this.body,
    required this.step,
    required this.total,
    required this.isLast,
    required this.showSymbols,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0EAF7),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFC17FD4), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ),
              Text(
                '$step/$total',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF555555),
              height: 1.5,
            ),
          ),
          if (showSymbols) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F7F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8E4F0)),
              ),
              child: Column(
                children: const [
                  _SymbolRow('[ ]', 'Tarefa pendente'),
                  _SymbolRow('[x]', 'Tarefa concluída'),
                  _SymbolRow('( )', 'Evento ou reunião'),
                  _SymbolRow('!', 'Prioridade alta'),
                  _SymbolRow('~', 'Tarefa em andamento'),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Apenas estes símbolos são lidos. Textos sem símbolo são ignorados.',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF888888),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Row(
                children: List.generate(
                  total,
                  (i) => Container(
                    width: i == step - 1 ? 14 : 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i == step - 1
                          ? const Color(0xFFC17FD4)
                          : const Color(0xFFDDD8E8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onNext,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFC17FD4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  isLast ? 'Entendido ✓' : 'Próximo →',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SymbolRow extends StatelessWidget {
  final String symbol;
  final String meaning;
  const _SymbolRow(this.symbol, this.meaning);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EAF7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              symbol,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFC17FD4),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            meaning,
            style: const TextStyle(fontSize: 11, color: Color(0xFF2D2D2D)),
          ),
        ],
      ),
    );
  }
}
