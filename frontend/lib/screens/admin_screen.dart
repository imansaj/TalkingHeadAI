import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Admin Panel — Mentor (Jack)'),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4CAF50),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions), text: 'Unanswered'),
            Tab(icon: Icon(Icons.book), text: 'Knowledge Base'),
            Tab(icon: Icon(Icons.upload_file), text: 'Sessions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_UnansweredTab(), _KnowledgeTab(), _SessionsTab()],
      ),
    );
  }
}

// ── Unanswered Questions Tab ──────────────────────────

class _UnansweredTab extends StatefulWidget {
  const _UnansweredTab();

  @override
  State<_UnansweredTab> createState() => _UnansweredTabState();
}

class _UnansweredTabState extends State<_UnansweredTab> {
  List<UnansweredEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _entries = await ApiService.listUnanswered();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showReviewDialog(UnansweredEntry entry) {
    final answerController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A4A),
        title: const Text(
          'Review Question',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question:',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(entry.question, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              Text(
                'AI General Response:',
                style: TextStyle(
                  color: Colors.orange.shade300,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.generalResponse,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: answerController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Your authoritative answer',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            onPressed: () async {
              if (answerController.text.trim().isEmpty) return;
              try {
                await ApiService.reviewQuestion(
                  entry.questionId,
                  answerController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Submit Answer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Text(
          'No unanswered questions 🎉',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        itemBuilder: (_, i) {
          final e = _entries[i];
          return Card(
            color: const Color(0xFF2A2A4A),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                e.question,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Asked: ${e.createdAt}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                ),
                onPressed: () => _showReviewDialog(e),
                child: const Text('Review'),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Knowledge Base Tab ─────────────────────────────────

class _KnowledgeTab extends StatefulWidget {
  const _KnowledgeTab();

  @override
  State<_KnowledgeTab> createState() => _KnowledgeTabState();
}

class _KnowledgeTabState extends State<_KnowledgeTab> {
  List<KnowledgeEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _entries = await ApiService.listKnowledge();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showAddDialog() {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A4A),
        title: const Text(
          'Add Knowledge Entry',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Question',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: aCtrl,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Answer',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            onPressed: () async {
              if (qCtrl.text.trim().isEmpty || aCtrl.text.trim().isEmpty)
                return;
              try {
                await ApiService.createKnowledge(
                  qCtrl.text.trim(),
                  aCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_entries.length} entries',
                style: const TextStyle(color: Colors.white54),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Entry'),
                onPressed: _showAddDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _entries.length,
              itemBuilder: (_, i) {
                final e = _entries[i];
                return Card(
                  color: const Color(0xFF2A2A4A),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    iconColor: Colors.white54,
                    collapsedIconColor: Colors.white38,
                    title: Text(
                      e.question,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Asked ${e.timesAsked}x • Source: ${e.source}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          e.answer,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sessions Tab ────────────────────────────────────────

class _SessionsTab extends StatefulWidget {
  const _SessionsTab();

  @override
  State<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<_SessionsTab> {
  final _titleCtrl = TextEditingController();
  final _transcriptCtrl = TextEditingController();
  bool _uploading = false;

  Future<void> _upload() async {
    if (_titleCtrl.text.trim().isEmpty || _transcriptCtrl.text.trim().isEmpty) {
      return;
    }
    setState(() => _uploading = true);
    try {
      await ApiService.uploadTranscript(
        _titleCtrl.text.trim(),
        _transcriptCtrl.text.trim(),
      );
      _titleCtrl.clear();
      _transcriptCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transcript uploaded & will be processed'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Mentor–Mentee Session Transcript',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Session Title',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF2A2A4A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _transcriptCtrl,
            maxLines: 12,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Paste transcript here...',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF2A2A4A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload),
              label: Text(_uploading ? 'Uploading...' : 'Upload Transcript'),
              onPressed: _uploading ? null : _upload,
            ),
          ),
        ],
      ),
    );
  }
}
