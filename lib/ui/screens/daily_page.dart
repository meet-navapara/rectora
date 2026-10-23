import 'package:flutter/material.dart';
import 'package:rectora/domain/common/date_key.dart';
import 'package:rectora/domain/daily/streak.dart';
import 'package:rectora/theme/palette.dart';
import 'package:rectora/ui/scope.dart';
import 'package:rectora/ui/screens/parcel_page.dart';
import 'package:rectora/ui/widgets/dialogs.dart';

class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  late DateTime month;

  @override
  void initState() {
    super.initState();
    final today = RectoraScope.read(context).now;
    month = DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final controller = RectoraScope.of(context);
    final palette = RectoraTheme.of(context);
    final today = DateTime(
      controller.now.year,
      controller.now.month,
      controller.now.day,
    );
    final cells = monthCells(month.year, month.month);
    final stats = controller.stats;
    final canGoForward = DateTime(
      month.year,
      month.month + 1,
    ).isBefore(DateTime(today.year, today.month + 1));
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Daily'),
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            'The same local date always selects the same puzzle from the built-in schedule rectora-daily-v1. It is not coordinated by a server. A missed day ends the streak; playing an older day extends it only when that day connects to today or yesterday.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Streak ${stats.currentStreak} · longest ${stats.longestStreak}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => setState(() {
                  month = DateTime(month.year, month.month - 1);
                }),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _monthName(month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: canGoForward
                    ? () => setState(() {
                        month = DateTime(month.year, month.month + 1);
                      })
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final label in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: cells.length,
            itemBuilder: (context, index) {
              final day = cells[index];
              if (day == null) return const SizedBox.shrink();
              final state = dailyState(
                day: day,
                today: today,
                completed: controller.save.dailyCompleted,
              );
              final open = state != DailyDayState.future;
              return Material(
                color: state == DailyDayState.completed
                    ? palette.copper
                    : state == DailyDayState.todayOpen
                    ? palette.surfaceHigh
                    : palette.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: open
                      ? () async {
                          final level = controller.catalog.dailyLevelFor(day);
                          final again = controller.save.dailyCompleted.contains(
                            dateKey(day),
                          );
                          if (again) {
                            final proceed = await showRectoraDialog<bool>(
                              context: context,
                              title: 'Already completed',
                              body:
                                  '${dateKey(day)} is already in your history. You can play it again, but the streak will not increase a second time.',
                              choices: const [
                                DialogChoice(
                                  label: 'Play again',
                                  value: true,
                                  primary: true,
                                ),
                                DialogChoice(label: 'Close', value: false),
                              ],
                            );
                            if (proceed != true || !context.mounted) return;
                          }
                          if (!context.mounted) return;
                          await pushSoft(
                            context,
                            ParcelPage(level: level, dailyDate: day),
                          );
                        }
                      : null,
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: state == DailyDayState.completed
                            ? palette.copperInk
                            : open
                            ? palette.ink
                            : palette.muted,
                        fontWeight: state == DailyDayState.todayOpen
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _monthName(DateTime month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${names[month.month - 1]} ${month.year}';
}
