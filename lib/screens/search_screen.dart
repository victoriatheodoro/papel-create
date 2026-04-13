import 'package:flutter/material.dart';
import '../models/activity_group.dart';
import '../models/scan_result.dart';

class _SearchResult {
  final bool isTask;
  final String text;
  final String? date;
  final String? groupName;
  final ActivityGroup? group;
  final bool completed;
  final bool inProgress;

  const _SearchResult({
    required this.isTask,
    required this.text,
    this.date,
    this.groupName,
    this.group,
    this.completed = false,
    this.inProgress = false,
  });
}

class SearchScreen extends StatefulWidget {
  final List<ScanResult> history;
  final List<ActivityGroup> groups;
  final void Function(ActivityGroup? group) onGroupOpen;

  const SearchScreen({
    super.key,
    required this.history,
    required this.groups,
    required this.onGroupOpen,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<_SearchResult> _results = [];

  ActivityGroup? _findGroup(String? groupId) {
    if (groupId == null) return null;
    return widget.groups.cast<ActivityGroup?>().firstWhere(
          (g) => g?.id == groupId,
          orElse: () => null,
        );
  }

  void _search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }

    final results = <_SearchResult>[];

    for (final scan in widget.history) {
      final group = _findGroup(scan.groupId);
      final groupName = group?.name ?? 'Geral';

      for (final task in scan.tasks) {
        if (task.text.toLowerCase().contains(q)) {
          String? dateStr;
          if (task.dueDate != null) {
            final d = task.dueDate!;
            dateStr =
                '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
          }
          results.add(_SearchResult(
            isTask: true,
            text: task.text,
            date: dateStr,
            groupName: groupName,
            group: group,
            completed: task.completed,
            inProgress: task.inProgress,
          ));
        }
      }

      for (final event in scan.events) {
        if (event.text.toLowerCase().contains(q)) {
          final dateStr = event.date != null
              ? '${event.date}${event.time != null ? ' às ${event.time}' : ''}'
              : null;
          results.add(_SearchResult(
            isTask: false,
            text: event.text,
            date: dateStr,
            groupName: groupName,
            group: group,
          ));
        }
      }
    }

    setState(() => _results = results);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F0),
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _search,
          style: const TextStyle(fontSize: 15, color: Color(0xFF2D2D2D)),
          decoration: InputDecoration(
            hintText: 'Buscar tarefas e eventos...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _ctrl.clear();
                _search('');
              },
            ),
        ],
      ),
      body: _ctrl.text.trim().isEmpty
          ? _buildEmpty()
          : _results.isEmpty
              ? _buildNoResults()
              : _buildResults(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Digite para buscar',
            style: TextStyle(fontSize: 15, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Nenhum resultado para "${_ctrl.text}"',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = _results[i];
        return _ResultCard(
          result: r,
          onTap: () {
            Navigator.pop(context);
            widget.onGroupOpen(r.group);
          },
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  final _SearchResult result;
  final VoidCallback onTap;

  const _ResultCard({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color statusColor = const Color(0xFF888888);
    String statusLabel = '';
    if (result.isTask) {
      if (result.completed) {
        statusColor = Colors.green;
        statusLabel = 'Concluída';
      } else if (result.inProgress) {
        statusColor = Colors.orange;
        statusLabel = 'Em andamento';
      } else {
        statusColor = const Color(0xFFC17FD4);
        statusLabel = 'Pendente';
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EAF7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                result.isTask
                    ? Icons.check_box_outline_blank
                    : Icons.event_outlined,
                color: const Color(0xFFC17FD4),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2D2D2D),
                      decoration: result.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Grupo
                      _Badge(
                        label: result.groupName ?? 'Geral',
                        color: const Color(0xFFF0EAF7),
                        textColor: const Color(0xFFC17FD4),
                        icon: Icons.folder_outlined,
                      ),
                      // Data
                      if (result.date != null)
                        _Badge(
                          label: result.date!,
                          color: const Color(0xFFF5F5F5),
                          textColor: const Color(0xFF888888),
                          icon: Icons.calendar_today_outlined,
                        ),
                      // Status (apenas tarefas)
                      if (result.isTask)
                        _Badge(
                          label: statusLabel,
                          color: statusColor.withOpacity(0.1),
                          textColor: statusColor,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
