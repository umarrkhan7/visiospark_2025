import 'package:flutter/material.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../theme/app_colors.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/logger.dart';
import '../../widgets/common/custom_button.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  final EventService _eventService = EventService();
  List<EventModel> _events = [];
  List<EventModel> _filteredEvents = [];
  bool _isLoading = true;
  String? _error;
  
  String? _selectedSociety;
  String? _selectedEventType;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final events = await _eventService.getUpcomingEvents();
      setState(() {
        _events = events;
        _filteredEvents = events;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading events', e);
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterEvents() {
    setState(() {
      _filteredEvents = _events.where((event) {
        final matchesSociety = _selectedSociety == null || 
            event.society?.shortName == _selectedSociety;
        
        final matchesType = _selectedEventType == null || 
            event.eventType == _selectedEventType;
        
        final searchQuery = _searchController.text.toLowerCase();
        final matchesSearch = searchQuery.isEmpty ||
            event.title.toLowerCase().contains(searchQuery) ||
            (event.description?.toLowerCase().contains(searchQuery) ?? false);
        
        return matchesSociety && matchesType && matchesSearch;
      }).toList();
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FilterSheet(
        selectedSociety: _selectedSociety,
        selectedEventType: _selectedEventType,
        onApply: (society, eventType) {
          setState(() {
            _selectedSociety = society;
            _selectedEventType = eventType;
            _filterEvents();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.pushNamed(context, AppConstants.calendarRoute);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search events...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterEvents();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => _filterEvents(),
            ),
          ),

          // Filter Chips
          if (_selectedSociety != null || _selectedEventType != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_selectedSociety != null)
                    Chip(
                      label: Text(_selectedSociety!),
                      onDeleted: () {
                        setState(() {
                          _selectedSociety = null;
                          _filterEvents();
                        });
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                    ),
                  if (_selectedEventType != null)
                    Chip(
                      label: Text(_selectedEventType!),
                      onDeleted: () {
                        setState(() {
                          _selectedEventType = null;
                          _filterEvents();
                        });
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                    ),
                ],
              ),
            ),

          // Events List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadEvents,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredEvents.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadEvents,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredEvents.length,
                              itemBuilder: (context, index) {
                                return _EventCard(
                                  event: _filteredEvents[index],
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppConstants.eventDetailRoute,
                                      arguments: _filteredEvents[index].id,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: AppColors.gray400,
          ),
          const SizedBox(height: 16),
          Text(
            'No events found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for upcoming events',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image
            if (event.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  event.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      color: AppColors.gray200,
                      child: const Icon(Icons.event, size: 48),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Society Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      event.society?.name ?? 'Unknown',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Event Title
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Date and Time
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: AppColors.gray500),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(event.dateTime),
                        style: const TextStyle(
                          color: AppColors.gray500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: AppColors.gray500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.venue,
                          style: const TextStyle(
                            color: AppColors.gray500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Participants Info
                  Row(
                    children: [
                      const Icon(Icons.people, size: 16, color: AppColors.gray500),
                      const SizedBox(width: 4),
                      Text(
                        event.isFull
                            ? 'Event Full'
                            : event.capacity > 0
                                ? '${event.spotsLeft} spots left'
                                : 'Open registration',
                        style: TextStyle(
                          color: event.isFull ? AppColors.error : AppColors.gray500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (eventDate == today) {
      return 'Today at ${_formatTime(dateTime)}';
    } else if (eventDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow at ${_formatTime(dateTime)}';
    } else {
      return '${_formatDate(dateTime)} at ${_formatTime(dateTime)}';
    }
  }

  String _formatDate(DateTime dateTime) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

class _FilterSheet extends StatefulWidget {
  final String? selectedSociety;
  final String? selectedEventType;
  final Function(String?, String?) onApply;

  const _FilterSheet({
    this.selectedSociety,
    this.selectedEventType,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _society;
  String? _eventType;

  @override
  void initState() {
    super.initState();
    _society = widget.selectedSociety;
    _eventType = widget.selectedEventType;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Events',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _society = null;
                    _eventType = null;
                  });
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Society Filter
          Text(
            'Society',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(AppConstants.societyACM, _society, (value) {
                setState(() => _society = value ? AppConstants.societyACM : null);
              }),
              _buildFilterChip(AppConstants.societyCLS, _society, (value) {
                setState(() => _society = value ? AppConstants.societyCLS : null);
              }),
              _buildFilterChip(AppConstants.societyCSS, _society, (value) {
                setState(() => _society = value ? AppConstants.societyCSS : null);
              }),
            ],
          ),
          const SizedBox(height: 24),

          // Event Type Filter
          Text(
            'Event Type',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('Technical', _eventType, (value) {
                setState(() => _eventType = value ? 'technical' : null);
              }),
              _buildFilterChip('Literary', _eventType, (value) {
                setState(() => _eventType = value ? 'literary' : null);
              }),
              _buildFilterChip('Sports', _eventType, (value) {
                setState(() => _eventType = value ? 'sports' : null);
              }),
            ],
          ),
          const SizedBox(height: 24),

          // Apply Button
          CustomButton(
            text: 'Apply Filters',
            onPressed: () {
              widget.onApply(_society, _eventType);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? selected, Function(bool) onSelected) {
    final isSelected = selected == label || 
        (label == 'Technical' && selected == 'technical') ||
        (label == 'Literary' && selected == 'literary') ||
        (label == 'Sports' && selected == 'sports');
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }
}
