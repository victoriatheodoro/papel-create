import 'package:flutter/material.dart';
import '../models/scan_result.dart';

class MiniCalendar extends StatefulWidget {
  final Map<DateTime, List<EventItem>> eventsByDate;

  const MiniCalendar({super.key, required this.eventsByDate});

  @override
  State<MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<MiniCalendar> {
  late DateTime _focusedMonth;

  static const _weekDays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
  static const _months = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() => setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      });

  void _nextMonth() => setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
      });

  List<DateTime?> _buildDays() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // domingo = 0

    final cells = <DateTime?>[];
    for (int i = 0; i < startWeekday; i++) cells.add(null);
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_focusedMonth.year, _focusedMonth.month, d));
    }
    return cells;
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool _hasEvents(DateTime dt) {
    final key = DateTime(dt.year, dt.month, dt.day);
    return widget.eventsByDate.containsKey(key) &&
        widget.eventsByDate[key]!.isNotEmpty;
  }

  void _onDayTap(DateTime dt) {
    final key = DateTime(dt.year, dt.month, dt.day);
    final events = widget.eventsByDate[key];
    if (events == null || events.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF9F7F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.event_outlined, color: Color(0xFFC17FD4), size: 20),
            const SizedBox(width: 8),
            Text(
              '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: events.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(top: 5, right: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC17FD4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.text,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF2D2D2D))),
                        if (e.time != null && e.time!.isNotEmpty)
                          Text(e.time!,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar',
                style: TextStyle(color: Color(0xFFC17FD4))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildDays();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 232,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cabeçalho: ← Mês Ano →
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _prevMonth,
                    child: const Icon(Icons.chevron_left,
                        size: 20, color: Color(0xFFC17FD4)),
                  ),
                  Text(
                    '${_months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  GestureDetector(
                    onTap: _nextMonth,
                    child: const Icon(Icons.chevron_right,
                        size: 20, color: Color(0xFFC17FD4)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Letras dos dias da semana
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _weekDays
                    .map((d) => SizedBox(
                          width: 28,
                          child: Center(
                            child: Text(d,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF888888))),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 4),
              // Grade de dias
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 0,
                  childAspectRatio: 1,
                ),
                itemCount: days.length,
                itemBuilder: (_, i) {
                  final dt = days[i];
                  if (dt == null) return const SizedBox.shrink();

                  final today = _isToday(dt);
                  final hasEv = _hasEvents(dt);

                  return GestureDetector(
                    onTap: hasEv ? () => _onDayTap(dt) : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: today
                              ? const BoxDecoration(
                                  color: Color(0xFFC17FD4),
                                  shape: BoxShape.circle,
                                )
                              : null,
                          child: Center(
                            child: Text(
                              '${dt.day}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: today
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: today
                                    ? Colors.white
                                    : const Color(0xFF2D2D2D),
                              ),
                            ),
                          ),
                        ),
                        if (hasEv)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: const BoxDecoration(
                              color: Color(0xFFC17FD4),
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 6),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
