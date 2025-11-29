import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/dashboard_service.dart';
import '../../theme/app_colors.dart';
import '../../core/utils/logger.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final DashboardService _dashboardService = DashboardService();
  
  Map<String, dynamic>? _analyticsData;
  List<Map<String, dynamic>> _insights = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final societyId = authProvider.user?.societyId;

      if (societyId == null) {
        throw Exception('Society ID not found');
      }

      final data = await _dashboardService.getAnalytics(societyId);
      final insights = _generateInsights(data);
      
      if (!mounted) return;
      setState(() {
        _analyticsData = data;
        _insights = insights;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading analytics', e);
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _generateInsights(Map<String, dynamic> data) {
    final insights = <Map<String, dynamic>>[];

    // Most popular events
    final events = data['events'] as List<dynamic>? ?? [];
    if (events.isNotEmpty) {
      events.sort((a, b) => (b['registrations'] ?? 0).compareTo(a['registrations'] ?? 0));
      final topEvent = events.first;
      insights.add({
        'icon': Icons.trending_up,
        'title': 'Most Popular Event',
        'description': '${topEvent['title']} with ${topEvent['registrations']} registrations',
        'color': Colors.orange,
      });
    }

    // Peak participation days
    final registrationsByDay = data['registrations_by_day'] as Map<String, dynamic>? ?? {};
    if (registrationsByDay.isNotEmpty) {
      final entries = registrationsByDay.entries.toList();
      entries.sort((a, b) => (b.value as int).compareTo(a.value as int));
      final peakDay = entries.first;
      final dayName = DateFormat('EEEE').format(DateTime.parse(peakDay.key));
      insights.add({
        'icon': Icons.calendar_today,
        'title': 'Peak Registration Day',
        'description': '$dayName with ${peakDay.value} registrations',
        'color': Colors.blue,
      });
    }

    // Participation rate
    final totalEvents = data['total_events'] as int? ?? 0;
    final totalRegistrations = data['total_registrations'] as int? ?? 0;
    if (totalEvents > 0) {
      final avgParticipation = (totalRegistrations / totalEvents).toStringAsFixed(1);
      insights.add({
        'icon': Icons.people,
        'title': 'Average Participation',
        'description': '$avgParticipation registrations per event',
        'color': Colors.green,
      });
    }

    // Trend analysis
    final last7Days = data['last_7_days_registrations'] as int? ?? 0;
    final previous7Days = data['previous_7_days_registrations'] as int? ?? 0;
    if (previous7Days > 0) {
      final percentChange = ((last7Days - previous7Days) / previous7Days * 100).toStringAsFixed(1);
      final isIncreasing = last7Days > previous7Days;
      insights.add({
        'icon': isIncreasing ? Icons.arrow_upward : Icons.arrow_downward,
        'title': 'Weekly Trend',
        'description': '${isIncreasing ? '+' : ''}$percentChange% compared to last week',
        'color': isIncreasing ? Colors.green : Colors.red,
      });
    }

    // Event types analysis
    final eventsByType = data['events_by_type'] as Map<String, dynamic>? ?? {};
    if (eventsByType.isNotEmpty) {
      final entries = eventsByType.entries.toList();
      entries.sort((a, b) => (b.value as int).compareTo(a.value as int));
      final topType = entries.first;
      insights.add({
        'icon': Icons.category,
        'title': 'Most Popular Type',
        'description': '${topType.key} events (${topType.value} total)',
        'color': Colors.purple,
      });
    }

    return insights;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Charts', icon: Icon(Icons.bar_chart)),
            Tab(text: 'Insights', icon: Icon(Icons.lightbulb)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildChartsTab(),
                _buildInsightsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final totalEvents = _analyticsData?['total_events'] ?? 0;
    final totalRegistrations = _analyticsData?['total_registrations'] ?? 0;
    final totalFeedback = _analyticsData?['total_feedback'] ?? 0;
    final avgRating = _analyticsData?['avg_rating'] ?? 0.0;

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Key metrics
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Events',
                  totalEvents.toString(),
                  Icons.event,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Registrations',
                  totalRegistrations.toString(),
                  Icons.how_to_reg,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Feedback',
                  totalFeedback.toString(),
                  Icons.feedback,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Avg Rating',
                  avgRating.toStringAsFixed(1),
                  Icons.star,
                  Colors.amber,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Quick insights preview
          Text(
            'Quick Insights',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          
          ..._insights.take(3).map((insight) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (insight['color'] as Color).withValues(alpha: 0.2),
                    child: Icon(
                      insight['icon'],
                      color: insight['color'],
                    ),
                  ),
                  title: Text(insight['title']),
                  subtitle: Text(insight['description']),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildChartsTab() {
    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Registration trends
          Text(
            'Registration Trends',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildRegistrationTrendsChart(),
          
          const SizedBox(height: 32),
          
          // Event types distribution
          Text(
            'Event Types Distribution',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildEventTypesChart(),
          
          const SizedBox(height: 32),
          
          // Participation rates
          Text(
            'Participation Rates',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildParticipationRatesChart(),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'AI-Generated Insights',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Personalized recommendations based on your event data',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          
          ..._insights.map((insight) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (insight['color'] as Color).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          insight['icon'],
                          color: insight['color'],
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight['title'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              insight['description'],
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationTrendsChart() {
    final registrationsByDay = _analyticsData?['registrations_by_day'] as Map<String, dynamic>? ?? {};
    
    if (registrationsByDay.isEmpty) {
      return _buildEmptyChart('No registration data available');
    }

    final spots = <FlSpot>[];
    final entries = registrationsByDay.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    
    for (var i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), (entries[i].value as int).toDouble()));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < entries.length) {
                        final date = DateTime.parse(entries[value.toInt()].key);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('MM/dd').format(date),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventTypesChart() {
    final eventsByType = _analyticsData?['events_by_type'] as Map<String, dynamic>? ?? {};
    
    if (eventsByType.isEmpty) {
      return _buildEmptyChart('No event type data available');
    }

    final sections = <PieChartSectionData>[];
    final colors = [
      AppColors.primary,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
    ];
    
    var colorIndex = 0;
    for (final entry in eventsByType.entries) {
      sections.add(
        PieChartSectionData(
          value: (entry.value as int).toDouble(),
          title: '${entry.key}\n${entry.value}',
          color: colors[colorIndex % colors.length],
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      colorIndex++;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipationRatesChart() {
    final events = _analyticsData?['events'] as List<dynamic>? ?? [];
    
    if (events.isEmpty) {
      return _buildEmptyChart('No participation data available');
    }

    // Get top 10 events by registrations
    events.sort((a, b) => (b['registrations'] ?? 0).compareTo(a['registrations'] ?? 0));
    final topEvents = events.take(10).toList();

    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < topEvents.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: (topEvents[i]['registrations'] ?? 0).toDouble(),
              color: AppColors.primary,
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < topEvents.length) {
                        final title = topEvents[value.toInt()]['title'] as String;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Transform.rotate(
                            angle: -0.5,
                            child: Text(
                              title.length > 15 ? '${title.substring(0, 12)}...' : title,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              barGroups: barGroups,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChart(String message) {
    return Card(
      child: Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
