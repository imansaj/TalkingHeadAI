import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        title: const Text(
          'Admin Panel — Mentor (Jack)',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
        backgroundColor: const Color(0xFF09090B),
        foregroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF3B82F6),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFAFAFA),
          unselectedLabelColor: const Color(0xFF71717A),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
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
  bool _deleting = false;

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

  Future<void> _confirmDelete(UnansweredEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Delete Entry',
          style: TextStyle(color: Color(0xFFFAFAFA)),
        ),
        content: Text(
          'Delete "${entry.question}"?',
          style: const TextStyle(color: Color(0xFFA1A1AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF71717A)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _deleting = true);
      try {
        await ApiService.deleteUnanswered(entry.questionId);
        _load();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Delete All Unanswered',
          style: TextStyle(color: Color(0xFFFAFAFA)),
        ),
        content: Text(
          'Delete all ${_entries.length} unanswered entries? This cannot be undone.',
          style: const TextStyle(color: Color(0xFFA1A1AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF71717A)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _deleting = true);
      try {
        await ApiService.deleteAllUnanswered();
        _load();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showReviewDialog(UnansweredEntry entry) {
    final answerController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final screenHeight = MediaQuery.of(ctx).size.height;
        return AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          title: const Text(
            'Review Question',
            style: TextStyle(
              color: Color(0xFFFAFAFA),
              fontWeight: FontWeight.w600,
            ),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: screenHeight * 0.65,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Question:',
                    style: TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _CopyableBlock(
                    text: entry.question,
                    textStyle: const TextStyle(
                      color: Color(0xFFFAFAFA),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AI General Response:',
                    style: TextStyle(
                      color: const Color(0xFFF59E0B),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _CopyableBlock(
                    text: entry.generalResponse,
                    textStyle: const TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: answerController,
                    maxLines: 4,
                    style: const TextStyle(color: Color(0xFFFAFAFA)),
                    decoration: InputDecoration(
                      labelText: 'Your authoritative answer',
                      labelStyle: const TextStyle(color: Color(0xFF52525B)),
                      filled: true,
                      fillColor: const Color(0xFF09090B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF71717A)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                try {
                  await ApiService.approveQuestion(entry.questionId);
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
              child: const Text('Approve AI Answer'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Text(
          'No unanswered questions 🎉',
          style: TextStyle(color: Color(0xFF52525B), fontSize: 16),
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF3B82F6),
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_entries.length} entries',
                  style: const TextStyle(color: Color(0xFF52525B)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text(
                    'Delete All',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: _deleting ? null : _confirmDeleteAll,
                ),
              ],
            ),
          ),
          if (_deleting)
            const LinearProgressIndicator(
              color: Color(0xFFDC2626),
              backgroundColor: Color(0xFF27272A),
              minHeight: 3,
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _entries.length,
              itemBuilder: (_, i) {
                final e = _entries[i];
                return Card(
                  color: const Color(0xFF18181B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF27272A)),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    title: Text(
                      e.question,
                      style: const TextStyle(
                        color: Color(0xFFFAFAFA),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Asked: ${e.createdAt}',
                        style: const TextStyle(
                          color: Color(0xFF52525B),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                          onPressed: _deleting ? null : () => _confirmDelete(e),
                          tooltip: 'Delete',
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: const Color(0xFF09090B),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () => _showReviewDialog(e),
                          child: const Text(
                            'Review',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
  bool _deleting = false;

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

  Future<void> _confirmDeleteEntry(KnowledgeEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Delete Entry',
          style: TextStyle(color: Color(0xFFFAFAFA)),
        ),
        content: Text(
          'Delete "${entry.question}"?',
          style: const TextStyle(color: Color(0xFFA1A1AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF71717A)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _deleting = true);
      try {
        await ApiService.deleteKnowledge(entry.questionId);
        _load();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _confirmDeleteAllKnowledge() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Delete All Knowledge',
          style: TextStyle(color: Color(0xFFFAFAFA)),
        ),
        content: Text(
          'Delete all ${_entries.length} knowledge entries? This cannot be undone.',
          style: const TextStyle(color: Color(0xFFA1A1AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF71717A)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _deleting = true);
      try {
        await ApiService.deleteAllKnowledge();
        _load();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showAddDialog() {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final screenHeight = MediaQuery.of(ctx).size.height;
        return AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Add Knowledge Entry',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: screenHeight * 0.65,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: qCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Question',
                      labelStyle: const TextStyle(
                        color: const Color(0xFF52525B),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF09090B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
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
                      labelStyle: const TextStyle(
                        color: const Color(0xFF52525B),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF09090B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF71717A)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_entries.length} entries',
                style: const TextStyle(color: const Color(0xFF52525B)),
              ),
              Row(
                children: [
                  if (_entries.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text(
                          'Delete All',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: _deleting
                            ? null
                            : _confirmDeleteAllKnowledge,
                      ),
                    ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Add Entry',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: _showAddDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_deleting)
          const LinearProgressIndicator(
            color: Color(0xFFDC2626),
            backgroundColor: Color(0xFF27272A),
            minHeight: 3,
          ),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFF3B82F6),
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _entries.length,
              itemBuilder: (_, i) {
                final e = _entries[i];
                return Card(
                  color: const Color(0xFF18181B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    iconColor: const Color(0xFF52525B),
                    collapsedIconColor: const Color(0xFF3F3F46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(
                      e.question,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Asked ${e.timesAsked}x • Source: ${e.source}',
                        style: const TextStyle(
                          color: const Color(0xFF3F3F46),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.answer,
                              style: const TextStyle(
                                color: const Color(0xFFA1A1AA),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _CopyIconButton(
                                  text: e.question,
                                  label: 'Question',
                                ),
                                const SizedBox(width: 8),
                                _CopyIconButton(
                                  text: e.answer,
                                  label: 'Answer',
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFDC2626),
                                    size: 20,
                                  ),
                                  onPressed: _deleting
                                      ? null
                                      : () => _confirmDeleteEntry(e),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ],
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
  List<Map<String, dynamic>> _sessions = [];
  bool _loadingSessions = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loadingSessions = true);
    try {
      _sessions = await ApiService.listSessions();
    } catch (_) {}
    if (mounted) setState(() => _loadingSessions = false);
  }

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
          const SnackBar(content: Text('Transcript uploaded & processed')),
        );
      }
      _loadSessions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _processSession(String sessionId) async {
    try {
      await ApiService.processSession(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session processed successfully')),
        );
      }
      _loadSessions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmDeleteSession(Map<String, dynamic> session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Delete Session',
          style: TextStyle(color: Color(0xFFFAFAFA)),
        ),
        content: Text(
          'Delete "${session['title'] ?? 'Untitled'}"?',
          style: const TextStyle(color: Color(0xFFA1A1AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF71717A)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _deleting = true);
      try {
        await ApiService.deleteSession(session['session_id'] as String);
        _loadSessions();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _confirmDeleteAllSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Delete All Sessions',
          style: TextStyle(color: Color(0xFFFAFAFA)),
        ),
        content: Text(
          'Delete all ${_sessions.length} sessions? This cannot be undone.',
          style: const TextStyle(color: Color(0xFFA1A1AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF71717A)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _deleting = true);
      try {
        await ApiService.deleteAllSessions();
        _loadSessions();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      if (mounted) setState(() => _deleting = false);
    }
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
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Session Title',
              labelStyle: const TextStyle(color: Color(0xFF52525B)),
              filled: true,
              fillColor: const Color(0xFF18181B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3F3F46)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3B82F6)),
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
              labelStyle: const TextStyle(color: Color(0xFF52525B)),
              filled: true,
              fillColor: const Color(0xFF18181B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3F3F46)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3B82F6)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
              label: Text(
                _uploading ? 'Uploading...' : 'Upload Transcript',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: _uploading ? null : _upload,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Uploaded Sessions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_sessions.isNotEmpty)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text(
                    'Delete All',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: _deleting ? null : _confirmDeleteAllSessions,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_deleting)
            const LinearProgressIndicator(
              color: Color(0xFFDC2626),
              backgroundColor: Color(0xFF27272A),
              minHeight: 3,
            ),
          if (_loadingSessions)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
              ),
            )
          else if (_sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No sessions uploaded yet',
                  style: TextStyle(color: Color(0xFF52525B)),
                ),
              ),
            )
          else
            ..._sessions.map((s) {
              final processed = s['processed'] == true;
              return Card(
                color: const Color(0xFF18181B),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF27272A)),
                ),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  title: Text(
                    s['title'] ?? 'Untitled',
                    style: const TextStyle(
                      color: Color(0xFFFAFAFA),
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Created: ${s['created_at'] ?? ''}',
                      style: const TextStyle(
                        color: Color(0xFF52525B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (processed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '✓ Processed',
                            style: TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: const Color(0xFF09090B),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () =>
                              _processSession(s['session_id'] as String),
                          child: const Text(
                            'Process',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        onPressed: _deleting
                            ? null
                            : () => _confirmDeleteSession(s),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── Shared Copy Widgets ─────────────────────────────────

class _CopyableBlock extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;

  const _CopyableBlock({required this.text, this.textStyle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 28),
            child: Text(text, style: textStyle),
          ),
          Positioned(top: -4, right: -4, child: _CopyButton(text: text)),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String text;

  const _CopyButton({required this.text});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.copy, size: 15, color: const Color(0xFF3F3F46)),
      tooltip: 'Copy',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      splashRadius: 16,
      onPressed: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            duration: Duration(seconds: 1),
          ),
        );
      },
    );
  }
}

class _CopyIconButton extends StatelessWidget {
  final String text;
  final String label;

  const _CopyIconButton({required this.text, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copied'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.copy, size: 13, color: const Color(0xFF3F3F46)),
            const SizedBox(width: 4),
            Text(
              'Copy $label',
              style: const TextStyle(
                color: const Color(0xFF3F3F46),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
