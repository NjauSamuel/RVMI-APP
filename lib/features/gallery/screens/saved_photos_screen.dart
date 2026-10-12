import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/gallery_repository.dart';
import '../models/media_item.dart';
import '../widgets/media_grid.dart';
import 'media_viewer_screen.dart';

class SavedPhotosScreen extends ConsumerStatefulWidget {
  const SavedPhotosScreen({super.key});

  @override
  ConsumerState<SavedPhotosScreen> createState() => _SavedPhotosScreenState();
}

class _SavedPhotosScreenState extends ConsumerState<SavedPhotosScreen> {
  final _items = <MediaItem>[];
  var _page = 1;
  var _lastPage = 1;
  var _loading = true;
  var _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({required bool refresh}) async {
    if (!refresh && (_loadingMore || _page > _lastPage)) return;
    setState(() {
      if (refresh) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final result = await ref.read(galleryRepositoryProvider).saved(page: refresh ? 1 : _page);
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _items
            ..clear()
            ..addAll(result.items);
        } else {
          _items.addAll(result.items);
        }
        _page = result.currentPage + 1;
        _lastPage = result.lastPage;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Could not load saved photos.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: Text(_error!)),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No saved photos yet.')),
        ],
      );
    }

    return MediaGrid(
      items: _items,
      loadingMore: _loadingMore,
      onNearEnd: () => _load(refresh: false),
      onOpen: (item, index) async {
        await openMediaViewer(context, items: _items, index: index);
        if (mounted) await _load(refresh: true);
      },
    );
  }
}
