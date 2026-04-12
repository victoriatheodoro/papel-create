import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/activity_group.dart';
import '../models/scan_result.dart';
import '../services/ocr_service.dart';

class ReviewScreen extends StatefulWidget {
  final ScanResult scanResult;
  final List<ActivityGroup> groups;
  const ReviewScreen({
    super.key,
    required this.scanResult,
    this.groups = const [],
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late ScanResult _result;
  late List<TaskItem> _tasks;
  late List<EventItem> _events;
  final _ocrService = OcrService();
  final _picker = ImagePicker();
  bool _addingImage = false;
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _result = widget.scanResult;
    _tasks = List.from(widget.scanResult.tasks);
    _events = List.from(widget.scanResult.events);
  }

  // ─── Ações ────────────────────────────────────────────────────────────────

  void _toggleTask(String id) {
    setState(() {
      final t = _tasks.firstWhere((t) => t.id == id);
      t.completed = !t.completed;
    });
  }

  void _deleteTask(String id) =>
      setState(() => _tasks.removeWhere((t) => t.id == id));

  void _deleteEvent(String id) =>
      setState(() => _events.removeWhere((e) => e.id == id));

  void _editTask(TaskItem task) {
    final ctrl = TextEditingController(text: task.text);
    bool priority = task.priority;
    bool inProgress = task.inProgress;
    DateTime? dueDate = task.dueDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Editar tarefa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Texto', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              // Prioridade
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Prioridade alta'),
                value: priority,
                onChanged: (v) => setDialog(() => priority = v ?? false),
              ),
              // Em andamento
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Em andamento'),
                value: inProgress,
                onChanged: (v) => setDialog(() => inProgress = v ?? false),
              ),
              const SizedBox(height: 8),
              // Prazo
              OutlinedButton.icon(
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
                  if (d != null) setDialog(() => dueDate = d);
                },
              ),
              if (dueDate != null)
                TextButton(
                  onPressed: () => setDialog(() => dueDate = null),
                  child: const Text('Remover prazo',
                      style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  setState(() {
                    task.text = ctrl.text.trim();
                    task.priority = priority;
                    task.inProgress = inProgress;
                    task.dueDate = dueDate;
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _editEvent(EventItem event) {
    final textCtrl = TextEditingController(text: event.text);
    DateTime? selectedDate = _parseDate(event.date);
    TimeOfDay? selectedTime = _parseTime(event.time);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar evento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        selectedDate != null
                            ? '${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.year}'
                            : 'Sem data',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setDialogState(() => selectedDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(
                        selectedTime != null
                            ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                            : 'Sem hora',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (t != null) setDialogState(() => selectedTime = t);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (textCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    event.text = textCtrl.text.trim();
                    event.date = selectedDate != null
                        ? '${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.year}'
                        : null;
                    event.time = selectedTime != null
                        ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                        : null;
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _parseDate(String? date) {
    if (date == null) return null;
    try {
      final parts = date.split('/');
      if (parts.length >= 2) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = parts.length == 3
            ? int.parse(parts[2].length == 2
                ? '20${parts[2]}'
                : parts[2])
            : DateTime.now().year;
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  TimeOfDay? _parseTime(String? time) {
    if (time == null) return null;
    try {
      final parts = time.split(':');
      if (parts.length == 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return null;
  }

  Future<void> _addImage() async {
    final source = await _showSourcePicker();
    if (source == null || !mounted) return;

    final image = await _picker.pickImage(source: source, imageQuality: 90);
    if (image == null) return;

    setState(() => _addingImage = true);

    try {
      final newResult = await _ocrService.processFile(image);
      if (!mounted) return;

      final prevTaskCount = _tasks.length;
      final prevEventCount = _events.length;

      setState(() {
        _result.imagePaths.add(image.path);
        // merge sem duplicatas
        final existingTexts = _tasks.map((t) => t.text.toLowerCase()).toSet();
        for (final t in newResult.tasks) {
          if (!existingTexts.contains(t.text.toLowerCase())) _tasks.add(t);
        }
        final existingEvents = _events.map((e) => e.text.toLowerCase()).toSet();
        for (final e in newResult.events) {
          if (!existingEvents.contains(e.text.toLowerCase())) _events.add(e);
        }
        _addingImage = false;
      });

      final addedTasks = _tasks.length - prevTaskCount;
      final addedEvents = _events.length - prevEventCount;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imagem adicionada: +$addedTasks ${addedTasks == 1 ? 'tarefa' : 'tarefas'}, '
              '+$addedEvents ${addedEvents == 1 ? 'evento' : 'eventos'}',
            ),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _addingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao processar imagem. Tente novamente.'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  Future<ImageSource?> _showSourcePicker() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFFF9F7F0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 28),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Adicionar imagem',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            _SourceOption(
              icon: Icons.camera_alt_outlined,
              label: 'Tirar foto',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 12),
            _SourceOption(
              icon: Icons.photo_library_outlined,
              label: 'Escolher da galeria',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    _result.tasks = _tasks;
    _result.events = _events;
    _result.groupId = _selectedGroupId;
    Navigator.pop(context, _result);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEmpty = _tasks.isEmpty && _events.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _result.imagePaths.length > 1
              ? 'Revisar dados · ${_result.imagePaths.length} imagens'
              : 'Revisar dados',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, null),
        ),
      ),
      body: _addingImage
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      color: Color(0xFFC17FD4), strokeWidth: 2.5),
                  SizedBox(height: 24),
                  Text('Processando imagem...',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
          : isEmpty
              ? _buildEmpty()
              : _buildContent(),
      bottomNavigationBar: isEmpty
          ? null
          : _addingImage
              ? null
              : _buildSaveBar(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text(
              'Nenhum item detectado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              'Certifique-se de usar os símbolos\n[ ], [x], ( ) e ! no caderno.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], height: 1.6),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Adicionar outra imagem'),
              onPressed: _addImage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        // Carrossel de imagens
        _ImageCarousel(
          imagePaths: _result.imagePaths,
          onAddImage: _addImage,
        ),
        const SizedBox(height: 20),

        if (_tasks.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.check_box_outlined,
            title: 'Tarefas',
            count: _tasks.length,
          ),
          const SizedBox(height: 10),
          ..._tasks.map(
            (t) => _TaskTile(
              task: t,
              onToggle: () => _toggleTask(t.id),
              onEdit: () => _editTask(t),
              onDelete: () => _deleteTask(t.id),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (_events.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.event_outlined,
            title: 'Eventos',
            count: _events.length,
          ),
          const SizedBox(height: 10),
          ..._events.map(
            (e) => _EventTile(
              event: e,
              onEdit: () => _editEvent(e),
              onDelete: () => _deleteEvent(e.id),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Botão adicionar imagem
        OutlinedButton.icon(
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: const Text('+ Adicionar imagem'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xFFDDDCD7)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _addImage,
        ),
      ],
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
      color: const Color(0xFFF9F7F0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seletor de grupo
          if (widget.groups.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Grupo',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...widget.groups.map((g) => _GroupChip(
                        label: g.name,
                        selected: _selectedGroupId == g.id,
                        onTap: () =>
                            setState(() => _selectedGroupId = g.id),
                      )),
                  _GroupChip(
                    label: 'Geral',
                    selected: _selectedGroupId == null,
                    onTap: () =>
                        setState(() => _selectedGroupId = null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Botão salvar
          GestureDetector(
            onTap: _save,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFC17FD4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_outlined, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Salvar no histórico',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }
}

// ─── Widgets locais ───────────────────────────────────────────────────────────

class _ImageCarousel extends StatelessWidget {
  final List<String> imagePaths;
  final VoidCallback onAddImage;

  const _ImageCarousel({required this.imagePaths, required this.onAddImage});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Imagens',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D2D2D)),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E4DF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${imagePaths.length}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imagePaths.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imagePaths[i],
                width: 90,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 90,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EAF7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.image_outlined,
                      color: Colors.grey, size: 32),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceOption(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EAF7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2D2D2D), size: 22),
            const SizedBox(width: 16),
            Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: const Color(0xFF2D2D2D)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D2D2D),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E4DF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E7E2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Icon(
              task.completed
                  ? Icons.check_circle_rounded
                  : task.inProgress
                      ? Icons.timelapse_rounded
                      : Icons.radio_button_unchecked_rounded,
              color: task.completed
                  ? Colors.green[600]
                  : task.inProgress
                      ? Colors.orange[600]
                      : Colors.grey[400],
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          if (task.priority)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '!',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: Text(
              task.text,
              style: TextStyle(
                fontSize: 15,
                color: task.completed
                    ? Colors.grey[400]
                    : const Color(0xFF2D2D2D),
                decoration:
                    task.completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (task.inProgress && !task.completed)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'em andamento',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          _ActionIcon(icon: Icons.edit_outlined, onTap: onEdit),
          _ActionIcon(icon: Icons.delete_outline, onTap: onDelete),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GroupChip(
      {required this.label, required this.selected, required this.onTap});

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
                  : const Color(0xFFDDDCD7)),
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

class _EventTile extends StatelessWidget {
  final EventItem event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventTile({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateTime = [
      if (event.date != null) event.date!,
      if (event.time != null) event.time!,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E7E2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_outlined,
              color: Color(0xFF2D2D2D), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.text,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                if (dateTime.isNotEmpty)
                  Text(
                    dateTime,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
          _ActionIcon(icon: Icons.edit_outlined, onTap: onEdit),
          _ActionIcon(icon: Icons.delete_outline, onTap: onDelete),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Icon(icon, size: 18, color: Colors.grey[400]),
      ),
    );
  }
}
