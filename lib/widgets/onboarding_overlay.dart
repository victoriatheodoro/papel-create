import 'package:flutter/material.dart';

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingOverlay({super.key, required this.onDone});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  int _step = 0;

  static const _steps = [
    _OnboardingStep(
      icon: Icons.auto_stories_outlined,
      title: 'Bem-vinda ao Papel & Create!',
      body:
          'Digitalize páginas do seu caderno e organize tarefas e eventos de forma simples.',
      alignTop: false,
      verticalFraction: 0.22,
      showSymbols: false,
    ),
    _OnboardingStep(
      icon: Icons.add_circle_outline,
      title: 'Adicionar atividade',
      body:
          'Toque no ícone "+" no canto superior direito para escanear uma página do caderno ou criar uma atividade manualmente.',
      alignTop: true,
      verticalFraction: 0.12,
      showSymbols: false,
    ),
    _OnboardingStep(
      icon: Icons.edit_note_outlined,
      title: 'Símbolos reconhecidos',
      body:
          'Para o app ler corretamente seu caderno, use estes símbolos. Apenas eles são reconhecidos no escaneamento:',
      alignTop: false,
      verticalFraction: 0.55,
      showSymbols: true,
    ),
    _OnboardingStep(
      icon: Icons.folder_outlined,
      title: 'Grupos',
      body:
          'Seus grupos organizam tarefas e eventos. Toque num card para ver, editar e acompanhar o progresso.',
      alignTop: false,
      verticalFraction: 0.5,
      showSymbols: false,
    ),
    _OnboardingStep(
      icon: Icons.calendar_month_outlined,
      title: 'Mini-calendário',
      body:
          'O botão "Calendário" no canto inferior esquerdo mostra seus eventos por data. Toque num dia marcado para ver detalhes e navegar ao grupo.',
      alignTop: true,
      verticalFraction: 0.78,
      showSymbols: false,
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

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Fundo escuro semi-transparente
          GestureDetector(
            onTap: _next,
            child: Container(
              width: size.width,
              height: size.height,
              color: Colors.black.withOpacity(0.65),
            ),
          ),
          // Balão de dica
          Positioned(
            left: 20,
            right: 20,
            top: step.alignTop ? size.height * step.verticalFraction : null,
            bottom:
                step.alignTop ? null : size.height * (1 - step.verticalFraction),
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

  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.alignTop,
    required this.verticalFraction,
    required this.showSymbols,
  });
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
      padding: const EdgeInsets.all(20),
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
          // Cabeçalho: ícone + título + contador
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0EAF7),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFC17FD4), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ),
              Text(
                '$step/$total',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF555555),
              height: 1.5,
            ),
          ),
          // Tabela de símbolos (apenas no passo dedicado)
          if (showSymbols) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
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
            const SizedBox(height: 8),
            const Text(
              'Apenas estes símbolos são lidos pelo app. Textos sem símbolo são ignorados.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF888888),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Rodapé: indicadores de passo + botão
          Row(
            children: [
              Row(
                children: List.generate(
                  total,
                  (i) => Container(
                    width: i == step - 1 ? 16 : 6,
                    height: 6,
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
                      horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  isLast ? 'Entendido ✓' : 'Próximo →',
                  style: const TextStyle(
                    fontSize: 13,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EAF7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              symbol,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFC17FD4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            meaning,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2D2D2D),
            ),
          ),
        ],
      ),
    );
  }
}
