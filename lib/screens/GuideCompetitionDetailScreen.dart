import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GuideCompetitionDetailScreen extends StatefulWidget {
  final String competitionId;
  final Map<String, dynamic> competitionData;

  const GuideCompetitionDetailScreen({
    super.key,
    required this.competitionId,
    required this.competitionData,
  });

  @override
  State<GuideCompetitionDetailScreen> createState() =>
      _GuideCompetitionDetailScreenState();
}

class _GuideCompetitionDetailScreenState
    extends State<GuideCompetitionDetailScreen> {
  // Professional color palette
  static const Color primaryBlue = Color(0xFF3D5A80);
  static const Color accentGold = Color(0xFFE9C46A);
  static const Color lightBlue = Color(0xFF6B89A8);
  static const Color darkBlue = Color(0xFF2A3F5F);
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color cardColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('competitions')
          .doc(widget.competitionId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ??
            widget.competitionData;

        final title = data['title'] ?? 'Competition';
        final roadName = data['roadName'] ?? 'Unknown Route';
        final isPublished = data['isPublished'] ?? false;
        final competitors = (data['competitors'] as List?)?.length ?? 0;
        final scores = data['scores'] as Map<String, dynamic>? ?? {};

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
                        Positioned(
                          top: 50,
                          right: 16,
                          child: _buildStatusBadge(isPublished),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () => _togglePublish(isPublished),
                    icon: Icon(
                      isPublished ? Icons.pause_circle : Icons.play_circle,
                    ),
                    tooltip: isPublished ? 'Pause' : 'Activate',
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.edit, size: 20, color: primaryBlue),
                            SizedBox(width: 12),
                            Text('Edit Competition'),
                          ],
                        ),
                        onTap: () {
                          // TODO: Add edit functionality
                        },
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red.shade700),
                            const SizedBox(width: 12),
                            const Text('Delete Competition'),
                          ],
                        ),
                        onTap: () {
                          Future.delayed(Duration.zero, () => _deleteCompetition());
                        },
                      ),
                    ],
                  ),
                ],
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
                        child: Row(
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
                                size: 28,
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
                            Container(
                                width: 1, height: 40, color: Colors.grey.shade300),
                            _buildStatItem(
                              Icons.star_outline,
                              scores.length.toString(),
                              'Completed',
                            ),
                            Container(
                                width: 1, height: 40, color: Colors.grey.shade300),
                            _buildStatItem(
                              Icons.trending_up,
                              _getAverageScore(scores),
                              'Avg Score',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Leaderboard Section
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentGold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.leaderboard, color: primaryBlue),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Leaderboard',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                        ],
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
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No scores yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Participants haven\'t completed\nthe route yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        _buildLeaderboard(scores),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(bool isPublished) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPublished ? Colors.green.shade400 : Colors.orange.shade400,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublished ? Icons.check_circle : Icons.pause_circle,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            isPublished ? 'Active' : 'Paused',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
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

  String _getAverageScore(Map<String, dynamic> scores) {
    if (scores.isEmpty) return '0';
    final total = scores.values.fold<int>(0, (sum, score) => sum + (score as int));
    return (total / scores.length).toStringAsFixed(1);
  }

  Widget _buildLeaderboard(Map<String, dynamic> scores) {
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return Column(
      children: [
        // Top 3 Podium
        if (sortedEntries.length >= 3) ...[
          _buildPodium(sortedEntries),
          const SizedBox(height: 16),
        ],

        // Rest of the list
        ...sortedEntries.asMap().entries.map((entry) {
          final index = entry.key;
          final score = entry.value;
          return _buildLeaderboardItem(
            index + 1,
            score.key,
            score.value as int,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildPodium(List<MapEntry<String, dynamic>> topThree) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryBlue.withOpacity(0.1), accentGold.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentGold.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (topThree.length > 1)
            _buildPodiumPlace(2, topThree[1].key, topThree[1].value as int, 100),
          if (topThree.isNotEmpty)
            _buildPodiumPlace(1, topThree[0].key, topThree[0].value as int, 130),
          if (topThree.length > 2)
            _buildPodiumPlace(3, topThree[2].key, topThree[2].value as int, 80),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(int rank, String uid, int score, double height) {
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];

    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: colors[rank - 1],
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors[rank - 1].withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: rank == 1 ? 36 : 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Player $uid',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '$score pts',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colors[rank - 1],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: colors[rank - 1].withOpacity(0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: colors[rank - 1], width: 2),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colors[rank - 1],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardItem(int rank, String uid, int score) {
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];

    final showMedal = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
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
              color: showMedal
                  ? colors[rank - 1].withOpacity(0.2)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: showMedal
                  ? Icon(Icons.emoji_events, color: colors[rank - 1], size: 24)
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
              'Player $uid',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: darkBlue,
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
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePublish(bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('competitions')
          .doc(widget.competitionId)
          .update({'isPublished': !currentStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentStatus ? 'Competition activated!' : 'Competition paused',
            ),
            backgroundColor: !currentStatus
                ? Colors.green.shade700
                : Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _deleteCompetition() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 12),
            const Text('Delete Competition?'),
          ],
        ),
        content: const Text(
          'This will permanently delete this competition and all participant data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('competitions')
                    .doc(widget.competitionId)
                    .delete();
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Competition deleted'),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
