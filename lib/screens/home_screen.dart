import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_group.dart';
import '../models/scan_result.dart';
import '../services/ocr_service.dart';
import '../services/todoist_service.dart';
import 'group_detail_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ocrService = OcrService();
  final _todoistService = TodoistService();
  final _picker = ImagePicker();
  bool _processing = false;
  bool _syncing = false;
  List<ScanResult> _history = [];
  List<ActivityGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadHistory(), _loadGroups()]);
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('scan_history');
      if (raw != null && raw.isNotEmpty) {
        if (mounted) setState(() => _history = ScanResult.decodeList(raw));
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Storage] erro ao carregar histórico: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('scan_history', ScanResult.encodeList(_history));
    } catch (e) {
      // ignore: avoid_print
      print('[Storage] erro ao salvar histórico: $e');
    }
  }

  Future<void> _loadGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('activity_groups');
      if (raw != null && raw.isNotEmpty) {
        if (mounted) setState(() => _groups = ActivityGroup.decodeList(raw));
      } else {
        final defaults = [
          ActivityGroup(name: 'Pessoal'),
          ActivityGroup(name: 'Trabalho'),
          ActivityGroup(name: 'Casa'),
        ];
        if (mounted) setState(() => _groups = defaults);
        await _saveGroups(defaults);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Storage] erro ao carregar grupos: $e');
    }
  }

  Future<void> _saveGroups([List<ActivityGroup>? groups]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'activity_groups', ActivityGroup.encodeList(groups ?? _groups));
    } catch (e) {
      // ignore: avoid_print
      print('[Storage] erro ao salvar grupos: $e');
    }
  }

  // ─── Todoist ───────────────────────────────────────────────────────────────

  Future<void> _syncTodoist() async {
    final token = await _todoistService.getToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Configure o Todoist Token em Configurações'),
          backgroundColor: Colors.orange[700],
        ),
      );
      return;
    }

    setState(() => _syncing = true);
    try {
      // Push: tarefas locais → Todoist
      final pushed = await _todoistService.push(_history, _saveHistory);

      // Pull: tarefas do Todoist → app
      final imported = await _todoistService.pull(_history, _groups);
      if (imported != null && imported.tasks.isNotEmpty) {
        // Garantir que o grupo Todoist existe
        if (imported.groupId == null) {
          final todoistGroup = ActivityGroup(name: 'Todoist');
          setState(() {
            _groups.add(todoistGroup);
            imported.groupId = todoistGroup.id;
          });
          await _saveGroups();
        }
        setState(() => _history.insert(0, imported));
        await _saveHistory();
      }

      if (!mounted) return;
      final pulled = imported?.tasks.length ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Todoist sincronizado! ↑ $pushed enviadas · ↓ $pulled importadas',
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('TODOIST_NO_TOKEN')
          ? 'Configure o Todoist Token em Configurações'
          : 'Erro ao sincronizar: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<bool> _checkApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('gemini_api_key') ?? '').isNotEmpty;
  }

  // ─── Scan ──────────────────────────────────────────────────────────────────

  Future<void> _scan(ImageSource source) async {
    // pickImage deve ser a primeira operação async para manter o contexto de
    // gesto do usuário no Flutter Web (browser bloqueia o seletor se houver
    // awaits intermediários antes de chamar pickImage).
    final image = await _picker.pickImage(source: source, imageQuality: 90);
    debugPrint('[SCAN] Imagem selecionada: ${image?.path ?? "null"}');
    if (image == null) return;

    final hasKey = await _checkApiKey();
    debugPrint('[SCAN] API key presente: $hasKey');
    if (!hasKey && mounted) {
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('API Key necessária'),
          content: const Text(
            'Para escanear imagens, você precisa configurar sua API key do Gemini.\n\nDeseja ir para as configurações?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Configurar'),
            ),
          ],
        ),
      );
      if (goToSettings == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      }
      return;
    }

    setState(() => _processing = true);

    try {
      debugPrint('[SCAN] Iniciando OCR...');
      final result = await _ocrService.processFile(image);
      debugPrint('[SCAN] OCR concluído: ${result.tasks.length} tarefas, ${result.events.length} eventos');
      if (!mounted) return;
      setState(() => _processing = false);

      debugPrint('[SCAN] Navegando para ReviewScreen...');
      final saved = await Navigator.pushNamed(
        context,
        '/review',
        arguments: {'result': result, 'groups': _groups},
      );
      debugPrint('[SCAN] Voltou do ReviewScreen, saved=${saved.runtimeType}');

      if (saved is ScanResult) {
        setState(() => _history.insert(0, saved));
        await _saveHistory();
        debugPrint('[SCAN] Atividade salva com sucesso!');
      }
    } catch (e) {
      debugPrint('[SCAN] ERRO: $e');
      if (!mounted) return;
      setState(() => _processing = false);
      final err = e.toString();
      final msg = err.contains('API_KEY_MISSING')
          ? 'API key não configurada. Acesse Configurações.'
          : err.contains('RATE_LIMIT')
              ? err.replaceFirst('Exception: RATE_LIMIT: ', 'Limite: ')
              : 'Erro ao processar imagem. Tente novamente.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
      );
    }
  }

  // ─── Bottom sheets ─────────────────────────────────────────────────────────

  void _showAddSheet() {
    showModalBottomSheet(
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
            const Text('Adicionar atividade',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            _SheetOption(
              icon: Icons.document_scanner_outlined,
              label: 'Escanear página',
              onTap: () {
                Navigator.pop(context);
                _showPickerSheet();
              },
            ),
            const SizedBox(height: 12),
            _SheetOption(
              icon: Icons.edit_outlined,
              label: 'Criar manualmente',
              onTap: () {
                Navigator.pop(context);
                _showManualEntrySheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPickerSheet() {
    showModalBottomSheet(
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
            const Text('Escanear página',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            _SheetOption(
              icon: Icons.camera_alt_outlined,
              label: 'Tirar foto',
              onTap: () {
                Navigator.pop(context);
                _scan(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            _SheetOption(
              icon: Icons.photo_library_outlined,
              label: 'Escolher da galeria',
              onTap: () {
                Navigator.pop(context);
                _scan(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManualEntrySheet({String? preselectedGroupId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF9F7F0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ManualEntrySheet(
        groups: _groups,
        preselectedGroupId: preselectedGroupId,
        onSave: (ScanResult result) async {
          setState(() => _history.insert(0, result));
          await _saveHistory();
        },
        onGroupCreated: (String name) async {
          final newGroup = ActivityGroup(name: name);
          setState(() => _groups.add(newGroup));
          await _saveGroups();
          return newGroup;
        },
      ),
    );
  }

  // ─── Gerenciamento de grupos ───────────────────────────────────────────────

  Future<void> _createGroup() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Novo grupo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ex: Saúde, Estudos, Viagem...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(context, ctrl.text.trim());
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (name != null && mounted) {
      setState(() => _groups.add(ActivityGroup(name: name)));
      await _saveGroups();
    }
  }

  Future<void> _renameGroup(ActivityGroup group) async {
    final ctrl = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renomear grupo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(context, ctrl.text.trim());
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (name != null && mounted) {
      setState(() => group.name = name);
      await _saveGroups();
    }
  }

  Future<void> _deleteGroup(ActivityGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Excluir "${group.name}"?'),
        content: const Text(
            'As atividades deste grupo serão movidas para Geral.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() {
        for (final scan in _history) {
          if (scan.groupId == group.id) scan.groupId = null;
        }
        _groups.remove(group);
      });
      await Future.wait([_saveGroups(), _saveHistory()]);
    }
  }

  void _openGroup(ActivityGroup? group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(
          group: group,
          history: _history,
          groups: _groups,
          onSave: () async {
            await _saveHistory();
            setState(() {});
          },
          onAddManual: (preselectedGroupId) =>
              _showManualEntrySheet(preselectedGroupId: preselectedGroupId),
        ),
      ),
    );
    setState(() {});
  }

  void _showLegend() {
    showModalBottomSheet(
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
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Legenda de símbolos',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _LegendRow('[ ]', 'Tarefa pendente'),
            _LegendRow('[x]', 'Tarefa concluída'),
            _LegendRow('~', 'Em andamento'),
            _LegendRow('( )', 'Evento'),
            _LegendRow('!', 'Prioridade alta'),
          ],
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 130,
        leading: TextButton(
          onPressed: _showLegend,
          child: const Text(
            'Legenda de\nsímbolos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D2D2D),
              height: 1.4,
            ),
          ),
        ),
        title: const Text('Papel & Create'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Histórico',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(history: _history),
                ),
              );
              setState(() {});
            },
          ),
          _syncing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFC17FD4),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.sync_outlined),
                  tooltip: 'Sincronizar com Todoist',
                  onPressed: _syncTodoist,
                ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configurações',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 26),
            tooltip: 'Adicionar atividade',
            onPressed: _showAddSheet,
          ),
        ],
      ),
      body: _processing ? _buildLoading() : _buildBody(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
              color: Color(0xFFC17FD4), strokeWidth: 2.5),
          SizedBox(height: 24),
          Text('Analisando sua página...',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  // Tarefas com prazo vencido ou vencendo hoje (não concluídas)
  List<({TaskItem task, String groupName})> get _overdueTasks {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final result = <({TaskItem task, String groupName})>[];

    for (final scan in _history) {
      for (final task in scan.tasks) {
        if (task.completed) continue;
        if (task.dueDate == null) continue;
        final due = DateTime(
            task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
        if (due.isAfter(todayOnly)) continue;
        final group = _groups.cast<ActivityGroup?>().firstWhere(
              (g) => g?.id == scan.groupId,
              orElse: () => null,
            );
        result.add((
          task: task,
          groupName: group?.name ?? 'Geral',
        ));
      }
    }
    return result;
  }

  Widget _buildBody() {
    final hasUngrouped = _history.any(
      (s) =>
          s.groupId == null &&
          (s.tasks.isNotEmpty || s.events.isNotEmpty),
    );
    final overdue = _overdueTasks;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Logo da marca
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 20),
            child: Image.asset('assets/images/logo.png', width: 220),
          ),
        ),

        // Seção "Vencendo"
        if (overdue.isNotEmpty) ...[
          _OverdueSection(items: overdue),
          const SizedBox(height: 8),
        ],

        // Grupos nomeados
        ..._groups.map((group) => _GroupBlock(
              group: group,
              history: _history,
              onTap: () => _openGroup(group),
              onRename: () => _renameGroup(group),
              onDelete: () => _deleteGroup(group),
            )),

        // Geral (sem grupo)
        if (hasUngrouped) ...[
          const SizedBox(height: 4),
          _GroupBlock(
            group: null,
            history: _history,
            onTap: () => _openGroup(null),
          ),
        ],

        const SizedBox(height: 20),

        // Botão novo grupo
        GestureDetector(
          onTap: _createGroup,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDCC8EC)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18, color: Color(0xFF888880)),
                SizedBox(width: 8),
                Text(
                  'Novo grupo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF888880),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }
}

// ─── Seção "Vencendo" ─────────────────────────────────────────────────────────

class _OverdueSection extends StatelessWidget {
  final List<({TaskItem task, String groupName})> items;
  const _OverdueSection({required this.items});

  String _label(DateTime dueDate) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = due.difference(todayOnly).inDays;
    if (diff == 0) return 'Hoje';
    return '${-diff} ${-diff == 1 ? 'dia' : 'dias'} atrás';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: Colors.red[700]),
              const SizedBox(width: 6),
              Text(
                'Vencendo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.red[700],
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.red[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 8),
                      child: Icon(Icons.circle,
                          size: 6, color: Colors.red[400]),
                    ),
                    Expanded(
                      child: Text(
                        item.task.text,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2D2D2D),
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _label(item.task.dueDate!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.red[600],
                          ),
                        ),
                        Text(
                          item.groupName,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Bloco de grupo ───────────────────────────────────────────────────────────

class _GroupBlock extends StatelessWidget {
  final ActivityGroup? group;
  final List<ScanResult> history;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _GroupBlock({
    required this.group,
    required this.history,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scans =
        history.where((s) => s.groupId == group?.id).toList();
    final tasks = scans.expand((s) => s.tasks).toList();
    final events = scans.expand((s) => s.events).toList();
    final pendingCount = tasks.where((t) => !t.completed).length;
    final isEmpty = tasks.isEmpty && events.isEmpty;

    return GestureDetector(
      onTap: onTap,
      onLongPress: group != null
          ? () => _showOptions(context)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2D4EE)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group?.name ?? 'Geral',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEmpty
                        ? 'Nenhuma atividade ainda'
                        : [
                            if (tasks.isNotEmpty)
                              '${tasks.length} ${tasks.length == 1 ? 'tarefa' : 'tarefas'}',
                            if (events.isNotEmpty)
                              '${events.length} ${events.length == 1 ? 'evento' : 'eventos'}',
                          ].join(' · '),
                    style: TextStyle(
                      fontSize: 13,
                      color: isEmpty
                          ? Colors.grey[350]
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (pendingCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC17FD4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pendingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            const Icon(Icons.chevron_right,
                color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF9F7F0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(group!.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renomear grupo'),
              onTap: () {
                Navigator.pop(context);
                onRename?.call();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Excluir grupo',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Formulário de criação manual ─────────────────────────────────────────────

class _ManualEntrySheet extends StatefulWidget {
  final List<ActivityGroup> groups;
  final String? preselectedGroupId;
  final void Function(ScanResult) onSave;
  final Future<ActivityGroup> Function(String name) onGroupCreated;

  const _ManualEntrySheet({
    required this.groups,
    this.preselectedGroupId,
    required this.onSave,
    required this.onGroupCreated,
  });

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  bool _isTask = true;
  final _ctrl = TextEditingController();
  bool _priority = false;
  bool _inProgress = false;
  DateTime? _date;
  TimeOfDay? _time;
  DateTime? _dueDate;
  String? _selectedGroupId;
  late List<ActivityGroup> _localGroups;

  @override
  void initState() {
    super.initState();
    _localGroups = List.from(widget.groups);
    _selectedGroupId = widget.preselectedGroupId ??
        (_localGroups.isNotEmpty ? _localGroups.first.id : null);
  }

  void _save() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final result = ScanResult(
      imagePaths: [],
      tasks: _isTask
          ? [
              TaskItem(
                  text: text,
                  priority: _priority,
                  inProgress: _inProgress,
                  dueDate: _dueDate)
            ]
          : [],
      events: !_isTask
          ? [
              EventItem(
                text: text,
                date: _date != null
                    ? '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}'
                    : null,
                time: _time != null
                    ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'
                    : null,
              )
            ]
          : [],
      rawText: '',
      groupId: _selectedGroupId,
    );

    widget.onSave(result);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 40),
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

          const Text('Nova atividade',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Toggle tarefa / evento
          Row(
            children: [
              Expanded(
                child: _TypeButton(
                  label: 'Tarefa',
                  selected: _isTask,
                  selectedColor: const Color(0xFFF4A7C7),
                  onTap: () => setState(() => _isTask = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TypeButton(
                  label: 'Evento',
                  selected: !_isTask,
                  selectedColor: const Color(0xFFC17FD4),
                  onTap: () => setState(() => _isTask = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Campo de texto
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: _isTask
                  ? 'Descreva a tarefa...'
                  : 'Descreva o evento...',
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
          const SizedBox(height: 12),

          // Opções de tarefa
          if (_isTask) ...[
            _CheckOption(
              label: 'Prioridade alta',
              icon: Icons.flag_outlined,
              value: _priority,
              onChanged: (v) => setState(() => _priority = v),
            ),
            const SizedBox(height: 8),
            _CheckOption(
              label: 'Em andamento',
              icon: Icons.timelapse_outlined,
              value: _inProgress,
              onChanged: (v) => setState(() => _inProgress = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: _dueDate != null
                          ? const Color(0xFF2D2D2D)
                          : Colors.grey[500],
                    ),
                    label: Text(
                      _dueDate != null
                          ? '${_dueDate!.day.toString().padLeft(2, '0')}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.year}'
                          : 'Sem prazo',
                      style: TextStyle(
                        fontSize: 13,
                        color: _dueDate != null
                            ? const Color(0xFF2D2D2D)
                            : Colors.grey[500],
                      ),
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (d != null) setState(() => _dueDate = d);
                    },
                  ),
                ),
                if (_dueDate != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _dueDate = null),
                    tooltip: 'Remover prazo',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Opções de evento
          if (!_isTask) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _date != null
                          ? '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}'
                          : 'Sem data',
                      style: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(
                      _time != null
                          ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'
                          : 'Sem hora',
                      style: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _time ?? TimeOfDay.now(),
                      );
                      if (t != null) setState(() => _time = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          const SizedBox(height: 16),

          // Seletor de grupo
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Grupo',
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
                ..._localGroups.map((g) => _GroupChip(
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
                GestureDetector(
                  onTap: () async {
                    final nameCtrl = TextEditingController();
                    final name = await showDialog<String>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Novo grupo'),
                        content: TextField(
                          controller: nameCtrl,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Ex: Saúde, Estudos, Viagem...',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (v) {
                            if (v.trim().isNotEmpty) {
                              Navigator.pop(context, v.trim());
                            }
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () {
                              if (nameCtrl.text.trim().isNotEmpty) {
                                Navigator.pop(context, nameCtrl.text.trim());
                              }
                            },
                            child: const Text('Criar'),
                          ),
                        ],
                      ),
                    );
                    if (name != null && mounted) {
                      final newGroup = await widget.onGroupCreated(name);
                      setState(() {
                        _localGroups.add(newGroup);
                        _selectedGroupId = newGroup.id;
                      });
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFC17FD4),
                          style: BorderStyle.solid),
                    ),
                    child: const Text(
                      '+ Criar grupo',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFC17FD4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Botão salvar
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _save,
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
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetOption(
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

class _TypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  const _TypeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = const Color(0xFFC17FD4),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? selectedColor : const Color(0xFFE2D4EE)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey[600],
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CheckOption(
      {required this.label,
      required this.icon,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFC17FD4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: value
                  ? const Color(0xFFC17FD4)
                  : const Color(0xFFE2D4EE)),
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
                color: value ? Colors.white : const Color(0xFF2D2D2D),
                fontWeight:
                    value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GroupChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFC17FD4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? const Color(0xFFC17FD4)
                  : const Color(0xFFDCC8EC)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color:
                selected ? Colors.white : const Color(0xFF2D2D2D),
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String symbol;
  final String desc;
  const _LegendRow(this.symbol, this.desc);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(symbol,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
          const SizedBox(width: 8),
          Text(desc,
              style: TextStyle(color: Colors.grey[600], fontSize: 15)),
        ],
      ),
    );
  }
}
