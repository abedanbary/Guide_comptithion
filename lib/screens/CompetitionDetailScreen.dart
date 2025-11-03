import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'MapViewScreen.dart';

class CompetitionDetailScreen extends StatefulWidget {
  final String competitionId;
  final Map<String, dynamic> competitionData;

  const CompetitionDetailScreen({
    super.key,
    required this.competitionId,
    required this.competitionData,
  });

  @override
  State<CompetitionDetailScreen> createState() =>
      _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen> {
  bool _isJoining = false;
  bool _isJoined = false;
  bool _hasCompleted = false;
  final currentUser = FirebaseAuth.instance.currentUser;

  // Professional color palette
  static const Color primaryBlue = Color(0xFF3D5A80);
  static const Color accentGold = Color(0xFFE9C46A);
  static const Color lightBlue = Color(0xFF6B89A8);
  static const Color darkBlue = Color(0xFF2A3F5F);
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _checkIfJoined();
  }

  void _checkIfJoined() {
    final competitors = widget.competitionData['competitors'] as List?;
    final scores = widget.competitionData['scores'] as Map<String, dynamic>?;

    if (currentUser != null) {
      setState(() {
        _isJoined = competitors?.contains(currentUser!.uid) ?? false;
        _hasCompleted = scores?.containsKey(currentUser!.uid) ?? false;
      });
    }
  }

  Future<void> _joinCompetition() async {
    if (currentUser == null) {
      _showSnackBar('Please log in first', isError: true);
      return;
    }

    setState(() => _isJoining = true);

    try {
      await FirebaseFirestore.instance
          .collection('competitions')
          .doc(widget.competitionId)
          .update({
        'competitors': FieldValue.arrayUnion([currentUser!.uid]),
      });

      setState(() {
        _isJoined = true;
        _isJoining = false;
      });

      _showSnackBar('Successfully joined the competition!');
    } catch (e) {
      setState(() => _isJoining = false);
      _showSnackBar('Failed to join: $e', isError: true);
    }
  }

  void _startCompetition() {
    if (!_isJoined) {
      _showSnackBar('Please join the competition first', isError: true);
      return;
    }

    if (_hasCompleted) {
      _showSnackBar('You have already completed this competition!', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapViewScreen(
          competitionId: widget.competitionId,
          roadId: widget.competitionData['roadId'].toString(),
          competitionTitle: widget.competitionData['title'] ?? 'Competition',
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.competitionData['title'] ?? 'Competition';
    final roadName = widget.competitionData['roadName'] ?? 'Unknown Route';
    final createdBy = widget.competitionData['createdBy'] ?? 'Unknown';
    final competitors = (widget.competitionData['competitors'] as List?)?.length ?? 0;
    final scores = widget.competitionData['scores'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            elevation: 0,
            backgroundColor: primaryBlue,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black26)],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryBlue, lightBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 40,
                      right: -20,
                      child: Icon(
                        Icons.emoji_events,
                        size: 200,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    if (_isJoined)
                      Positioned(
                        top: 50,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade400,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Joined',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route Info Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.route,
                                color: primaryBlue,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Route',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    roadName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: darkBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 20, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Created by: $createdBy',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stats Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          Icons.people_outline,
                          competitors.toString(),
                          'Participants',
                        ),
                        Container(width: 1, height: 40, color: Colors.grey.shade300),
                        _buildStatItem(
                          Icons.star_outline,
                          scores.length.toString(),
                          'Completed',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Leaderboard Section
                  const Text(
                    'Leaderboard',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (scores.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.emoji_events_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No scores yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Be the first to complete!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _buildLeaderboard(scores),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (!_isJoined)
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isJoining ? null : _joinCompetition,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGold,
                      foregroundColor: darkBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isJoining
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: darkBlue,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_add, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Join Competition',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              if (!_isJoined) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_isJoined && !_hasCompleted) ? _startCompetition : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasCompleted
                        ? Colors.green.shade600
                        : primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: _hasCompleted
                        ? Colors.green.shade600
                        : Colors.grey.shade300,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _hasCompleted ? Icons.check_circle : Icons.play_arrow,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _hasCompleted ? 'Completed' : 'Start Route',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: primaryBlue, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: darkBlue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboard(Map<String, dynamic> scores) {
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        final uid = entry.key;
        final score = entry.value;
        final isCurrentUser = uid == currentUser?.uid;
        final rank = index + 1;

        Color rankColor = Colors.grey;
        IconData? medalIcon;

        if (rank == 1) {
          rankColor = const Color(0xFFFFD700); // Gold
          medalIcon = Icons.emoji_events;
        } else if (rank == 2) {
          rankColor = const Color(0xFFC0C0C0); // Silver
          medalIcon = Icons.emoji_events;
        } else if (rank == 3) {
          rankColor = const Color(0xFFCD7F32); // Bronze
          medalIcon = Icons.emoji_events;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? primaryBlue.withOpacity(0.1)
                : cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentUser ? primaryBlue : Colors.grey.shade200,
              width: isCurrentUser ? 2 : 1,
            ),
            boxShadow: [
              if (!isCurrentUser)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: medalIcon != null
                      ? rankColor.withOpacity(0.2)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: medalIcon != null
                      ? Icon(medalIcon, color: rankColor, size: 24)
                      : Text(
                          '#$rank',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isCurrentUser ? 'You' : 'Player $uid',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                    color: isCurrentUser ? primaryBlue : darkBlue,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: accentGold, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
