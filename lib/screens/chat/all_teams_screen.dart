import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/team_service.dart';
import '../../services/event_service.dart';
import '../../models/team_model.dart';
import '../../models/event_model.dart';
import '../../theme/app_colors.dart';
import '../../core/utils/logger.dart';
import '../chat/team_chat_screen.dart';

class AllTeamsScreen extends StatefulWidget {
  const AllTeamsScreen({super.key});

  @override
  State<AllTeamsScreen> createState() => _AllTeamsScreenState();
}

class _AllTeamsScreenState extends State<AllTeamsScreen> {
  final _teamService = TeamService();
  final _eventService = EventService();
  final _searchController = TextEditingController();
  
  List<TeamModel> _allTeams = [];
  List<TeamModel> _filteredTeams = [];
  Map<String, EventModel> _eventsMap = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedEventFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Get all events first
      final events = await _eventService.getEvents();
      _eventsMap = {for (var event in events) event.id: event};
      
      // Get teams for all events
      final allTeams = <TeamModel>[];
      for (final event in events) {
        try {
          final teams = await _teamService.getEventTeams(event.id);
          // Add event title to each team
          for (var team in teams) {
            allTeams.add(team);
          }
        } catch (e) {
          AppLogger.error('Error loading teams for event ${event.id}', e);
        }
      }
      
      if (!mounted) return;
      setState(() {
        _allTeams = allTeams;
        _filteredTeams = allTeams;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading teams', e);
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _filterTeams() {
    setState(() {
      _filteredTeams = _allTeams.where((team) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            team.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (team.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        
        // Event filter
        final matchesEvent = _selectedEventFilter == null ||
            team.eventId == _selectedEventFilter;
        
        return matchesSearch && matchesEvent;
      }).toList();
    });
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _filterTeams();
  }

  void _onEventFilterChanged(String? eventId) {
    setState(() => _selectedEventFilter = eventId);
    _filterTeams();
  }

  Future<void> _joinTeam(TeamModel team) async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) return;

    try {
      await _teamService.joinTeam(team.id, userId);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined team successfully!')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _openTeamChat(TeamModel team) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamChatScreen(teamId: team.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Teams'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search teams...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              
              // Event filter
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('All Events'),
                              selected: _selectedEventFilter == null,
                              onSelected: (_) => _onEventFilterChanged(null),
                            ),
                            const SizedBox(width: 8),
                            ..._eventsMap.values.map((event) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(event.title),
                                  selected: _selectedEventFilter == event.id,
                                  onSelected: (_) => _onEventFilterChanged(event.id),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredTeams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty || _selectedEventFilter != null
                            ? Icons.search_off
                            : Icons.group_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty || _selectedEventFilter != null
                            ? 'No teams found'
                            : 'No teams yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isNotEmpty || _selectedEventFilter != null
                            ? 'Try adjusting your filters'
                            : 'Teams will appear here',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredTeams.length,
                    itemBuilder: (context, index) {
                      final team = _filteredTeams[index];
                      final event = _eventsMap[team.eventId];
                      final isMember = team.members?.any((m) => m.userId == userId) ?? false;
                      final isLeader = team.members?.any((m) => m.userId == userId && m.isLeader) ?? false;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Event badge
                              if (event != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    event.title,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              
                              // Team info
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          team.name,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        if (team.description != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            team.description!,
                                            style: Theme.of(context).textTheme.bodyMedium,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      Icon(
                                        team.isFull ? Icons.lock : Icons.group,
                                        color: team.isFull ? Colors.grey : AppColors.primary,
                                      ),
                                      Text(
                                        '${team.memberCount ?? 0}/${team.maxMembers}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Actions
                              Row(
                                children: [
                                  if (isMember) ...[
                                    if (isLeader)
                                      Chip(
                                        label: const Text('Leader'),
                                        avatar: const Icon(Icons.star, size: 16),
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                      ),
                                    if (!isLeader)
                                      Chip(
                                        label: const Text('Member'),
                                        avatar: const Icon(Icons.check, size: 16),
                                        backgroundColor: Colors.green.withValues(alpha: 0.2),
                                      ),
                                    const Spacer(),
                                    ElevatedButton.icon(
                                      onPressed: () => _openTeamChat(team),
                                      icon: const Icon(Icons.chat, size: 18),
                                      label: const Text('Chat'),
                                    ),
                                  ] else ...[
                                    const Spacer(),
                                    ElevatedButton.icon(
                                      onPressed: team.isFull ? null : () => _joinTeam(team),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: Text(team.isFull ? 'Full' : 'Join'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
