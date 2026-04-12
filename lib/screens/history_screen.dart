import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/scan_result.dart';
import 'review_screen.dart';

class HistoryScreen extends StatefulWidget {
  final List<ScanResult> history;
  const HistoryScreen({super.key, required this.history});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';

  List<ScanResult> get _filtered {
    if (_query.isEmpty) return widget.history;
    final q = _query.toLowerCase();
    return widget.history.where((scan) {
      return scan.rawText.toLowerCase().contains(q) ||
          scan.tasks.any((t) => t.text.toLowerCase().contains(q)) ||
          scan.events.any((e) => e.text.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Buscar por texto...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: const Color(0xFFF0EAF7),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty ? _buildEmpty() : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _query.isEmpty ? 'Nenhum scan ainda' : 'Nenhum resultado',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final scan = _filtered[i];
        return _ScanCard(
          scan: scan,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReviewScreen(scanResult: scan),
            ),
          ),
        );
      },
    );
  }
}

class _ScanCard extends StatelessWidget {
  final ScanResult scan;
  final VoidCallback onTap;

  const _ScanCard({required this.scan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy · HH:mm').format(scan.scannedAt);
    final taskCount = scan.tasks.length;
    final eventCount = scan.events.length;
    final hasImage = scan.imagePaths.isNotEmpty;
    final imageCount = scan.imagePaths.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E7E2)),
        ),
        child: Row(
          children: [
            // Thumbnail da imagem
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: hasImage
                      ? Image.network(
                          scan.imagePaths.first,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _iconPlaceholder(),
                        )
                      : _iconPlaceholder(),
                ),
                // Badge com contagem de imagens
                if (imageCount > 1)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC17FD4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$imageCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$taskCount ${taskCount == 1 ? 'tarefa' : 'tarefas'} · '
                    '$eventCount ${eventCount == 1 ? 'evento' : 'eventos'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _iconPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EAF7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.description_outlined,
        size: 24,
        color: Color(0xFF2D2D2D),
      ),
    );
  }
}
