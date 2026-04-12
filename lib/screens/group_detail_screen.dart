import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity_group.dart';
import '../models/scan_result.dart';

class GroupDetailScreen extends StatefulWidget {
  final ActivityGroup? group; // null = Geral
  final List<ScanResult> history;
  final List<ActivityGroup> groups;
  final Future<void> Function() onSave;
  final void Function(String? groupId) onAddManual;

  const GroupDetailScreen({
    super.key,
    required this.group,
    required this.history,
    required this.groups,
    required this.onSave,
    required this.onAddManual,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  List<ScanResult> get _scans => widget.history
      .where((s) =>
          s.groupId == widget.group?.id &&
          (s.tasks.isNotEmpty || s.events.isNotEmpty))
      .toList();

  // Toggle cicla: Aberta → Em andamento → Concluída → Aberta
  Future<void> _toggleTask(TaskItem task) async {
    setState(() {
      if (!task.inProgress && !task.completed) {
        task.inProgress = true;
      } else if (task.inProgress && !task.completed) {
        task.inProgress = false;
        task.completed = true;
      } else {
        task.completed = false;
      }
    });
    await widget.onSave();
  }

  void _moveTask(TaskItem task, String? targetGroupId) {
    ScanResult? parentScan;
    for (final scan in widget.history) {
      if (scan.tasks.contains(task)) {
        parentScan = scan;
        break;
      }
    }
    if (parentScan == null) return;

    setState(() {
      parentScan!.tasks.remove(task);
      if (parentScan.tasks.isEmpty && parentScan.events.isEmpty) {
        widget.history.remove(parentScan);
      }
      widget.history.insert(
        0,
        ScanResult(
          imagePaths: [],
          tasks: [task],
          events: [],
          rawText: '',
          groupId: targetGroupId,
        ),
      );
    });
    widget.onSave();
  }

  void _editTask(TaskItem task) {
    final ctrl = TextEditingController(text: task.text);
    // 0 = pendente, 1 = em andamento, 2 = concluída
    int status = task.completed ? 2 : task.inProgress ? 1 : 0;
    bool priority = task.priority;
    DateTime? dueDate = task.dueDate;
    String? selectedMoveGroupId = widget.group?.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF9F7F0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('Editar tarefa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),

              // Texto
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Texto da tarefa',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFDDDCD7))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFDDDCD7))),
                ),
              ),
              const SizedBox(height: 16),

              // Status (3 botões)
              Row(
                children: [
                  _StatusBtn(
                    label: 'Pendente',
                    selected: status == 0,
                    selectedColor: const Color(0xFFC17FD4),
                    onTap: () => setSheet(() => status = 0),
                  ),
                  const SizedBox(width: 6),
                  _StatusBtn(
                    label: 'Andamento',
                    selected: status == 1,
                    selectedColor: Colors.orange[700]!,
                    onTap: () => setSheet(() => status = 1),
                  ),
                  const SizedBox(width: 6),
                  _StatusBtn(
                    label: 'Concluída',
                    selected: status == 2,
                    selectedColor: Colors.green[700]!,
                    onTap: () => setSheet(() => status = 2),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Prioridade
              _ToggleRow(
                icon: Icons.flag_outlined,
                label: 'Prioridade alta',
                value: priority,
                onChanged: (v) => setSheet(() => priority = v),
              ),
              const SizedBox(height: 10),

              // Prazo
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        dueDate != null
                            ? '${dueDate!.day.toString().padLeft(2, '0')}/${dueDate!.month.toString().padLeft(2, '0')}/${dueDate!.year}'
                            : 'Sem prazo',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: dueDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setSheet(() => dueDate = d);
                      },
                    ),
                  ),
                  if (dueDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Remover prazo',
                      onPressed: () => setSheet(() => dueDate = null),
                    ),
                  ],
                ],
              ),
              // Mover para grupo
              if (widget.groups.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Mover para',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600])),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _GroupChip(
                        label: 'Geral',
                        selected: selectedMoveGroupId == null,
                        onTap: () => setSheet(() => selectedMoveGroupId = null),
                      ),
                      ...widget.groups.map((g) => _GroupChip(
                            label: g.name,
                            selected: selectedMoveGroupId == g.id,
                            onTap: () =>
                                setSheet(() => selectedMoveGroupId = g.id),
                          )),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Salvar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    task.text = text;
                    task.completed = status == 2;
                    task.inProgress = status == 1;
                    task.priority = priority;
                    task.dueDate = dueDate;
                    Navigator.pop(ctx);
                    if (selectedMoveGroupId != widget.group?.id) {
                      _moveTask(task, selectedMoveGroupId);
                    } else {
                      setState(() {});
                      widget.onSave();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC17FD4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Salvar',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final hoje = DateTime.now();
    final ontem = hoje.subtract(const Duration(days: 1));
    if (_isSameDay(date, hoje)) return 'Hoje';
    if (_isSameDay(date, ontem)) return 'Ontem';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final scans = _scans;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group?.name ?? 'Geral'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Adicionar manualmente',
            onPressed: () {
              Navigator.pop(context);
              widget.onAddManual(widget.group?.id);
            },
          ),
        ],
      ),
      body: scans.isEmpty ? _buildEmpty() : _buildList(scans),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EAF7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.inbox_outlined,
                  size: 36, color: Color(0xFF2D2D2D)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nenhuma atividade aqui',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D2D2D)),
            ),
            const SizedBox(height: 8),
            Text(
              'Use + para adicionar manualmente\nou escaneie uma página.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey[500], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<ScanResult> scans) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        for (final scan in scans) ...[
          // Cabeçalho com data
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: Row(
              children: [
                Text(
                  scan.imagePaths.isEmpty
                      ? 'Criado manualmente'
                      : _formatDate(scan.scannedAt),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D2D2D),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E4DF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${scan.tasks.length + scan.events.length} itens',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // Tarefas
          ...scan.tasks.map((task) => _TaskRow(
                task: task,
                onToggle: () => _toggleTask(task),
                onEdit: () => _editTask(task),
              )),
          // Eventos
          ...scan.events.map((event) => _EventRow(event: event)),
          const Divider(color: Color(0xFFEEEDE7), thickness: 1),
        ],
      ],
    );
  }
}

// ─── Widgets auxiliares ────────────────────────────────────────────────────────

class _StatusBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _StatusBtn({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? selectedColor : const Color(0xFFE8E7E2),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFC17FD4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                value ? const Color(0xFFC17FD4) : const Color(0xFFE8E7E2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: value ? Colors.white : Colors.grey[500]),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color:
                    value ? Colors.white : const Color(0xFF2D2D2D),
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Task Row ─────────────────────────────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onEdit,
  });

  String? _dueDateLabel() {
    if (task.dueDate == null || task.completed) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
    final diff = due.difference(today).inDays;
    if (diff == 0) return 'Hoje';
    if (diff < 0) return '${-diff} ${-diff == 1 ? 'dia' : 'dias'} atrás';
    if (diff == 1) return 'Amanhã';
    return 'em $diff dias';
  }

  Color _dueDateColor() {
    if (task.dueDate == null) return Colors.grey;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
    final diff = due.difference(today).inDays;
    if (diff < 0) return Colors.red[700]!;
    if (diff == 0) return Colors.orange[700]!;
    return Colors.grey[500]!;
  }

  @override
  Widget build(BuildContext context) {
    final dueDateLabel = _dueDateLabel();

    return GestureDetector(
      onLongPress: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.only(top: 1, right: 10),
                child: Icon(
                  task.completed
                      ? Icons.check_circle_rounded
                      : task.inProgress
                          ? Icons.timelapse_rounded
                          : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: task.completed
                      ? Colors.green[600]
                      : task.inProgress
                          ? Colors.orange[600]
                          : Colors.grey[400],
                ),
              ),
            ),
            if (task.priority && !task.completed)
              Container(
                margin: const EdgeInsets.only(right: 6, top: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text('!',
                    style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w800,
                        fontSize: 11)),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: task.completed
                          ? Colors.grey[400]
                          : const Color(0xFF2D2D2D),
                      decoration:
                          task.completed ? TextDecoration.lineThrough : null,
                      height: 1.4,
                    ),
                  ),
                  if (dueDateLabel != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 12, color: _dueDateColor()),
                        const SizedBox(width: 3),
                        Text(
                          dueDateLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: _dueDateColor(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Ícone de edição discreto
            GestureDetector(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 1),
                child: Icon(Icons.edit_outlined,
                    size: 16, color: Colors.grey[300]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final EventItem event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final dateTime = [
      if (event.date != null) event.date!,
      if (event.time != null) event.time!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 10),
            child: Icon(Icons.event_outlined,
                size: 20, color: Colors.blue[400]),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.text,
                  style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF2D2D2D),
                      height: 1.4),
                ),
                if (dateTime.isNotEmpty)
                  Text(dateTime,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFC17FD4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFC17FD4)
                : const Color(0xFFDCC8EC),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : const Color(0xFF2D2D2D),
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
