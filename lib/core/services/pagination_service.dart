import 'package:flutter/foundation.dart';
import 'package:rocis_tasks/core/config/app_config.dart';

/// Generic pagination service for handling large datasets
class PaginationService<T> extends ChangeNotifier {
  final List<T> Function() _getAllItems;
  final int _pageSize;

  List<T> _allItems = [];
  List<T> _currentPageItems = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMoreItems = true;

  PaginationService(
    this._getAllItems, {
    int pageSize = AppConfig.maxTasksPerPage,
  }) : _pageSize = pageSize;

  /// Current page items
  List<T> get items => _currentPageItems;

  /// Current page number (0-based)
  int get currentPage => _currentPage;

  /// Whether more items are available
  bool get hasMoreItems => _hasMoreItems;

  /// Whether currently loading
  bool get isLoading => _isLoading;

  /// Total number of items
  int get totalItems => _allItems.length;

  /// Total number of pages
  int get totalPages => (_allItems.length / _pageSize).ceil();

  /// Initialize pagination with all items
  void initialize() {
    _allItems = _getAllItems();
    _currentPage = 0;
    _loadCurrentPage();
  }

  /// Refresh data and reset to first page
  void refresh() {
    _allItems = _getAllItems();
    _currentPage = 0;
    _loadCurrentPage();
    notifyListeners();
  }

  /// Load next page
  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMoreItems) return;

    _isLoading = true;
    notifyListeners();

    // Simulate loading delay for better UX
    await Future.delayed(const Duration(milliseconds: 100));

    _currentPage++;
    _loadCurrentPage();

    _isLoading = false;
    notifyListeners();
  }

  /// Load previous page
  void loadPreviousPage() {
    if (_currentPage > 0) {
      _currentPage--;
      _loadCurrentPage();
      notifyListeners();
    }
  }

  /// Jump to specific page
  void goToPage(int page) {
    if (page >= 0 && page < totalPages) {
      _currentPage = page;
      _loadCurrentPage();
      notifyListeners();
    }
  }

  /// Load items for current page
  void _loadCurrentPage() {
    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, _allItems.length);

    if (_currentPage == 0) {
      // First page - replace all items
      _currentPageItems = _allItems.sublist(startIndex, endIndex);
    } else {
      // Subsequent pages - append items (for infinite scroll)
      final newItems = _allItems.sublist(startIndex, endIndex);
      _currentPageItems.addAll(newItems);
    }

    _hasMoreItems = endIndex < _allItems.length;
  }

  /// Reset pagination (useful for filtering/sorting)
  void reset() {
    _currentPage = 0;
    _currentPageItems.clear();
    _hasMoreItems = true;
    _loadCurrentPage();
    notifyListeners();
  }

  /// Get items for infinite scroll (loads more items as needed)
  List<T> getItemsForInfiniteScroll() {
    return _currentPageItems;
  }

  /// Check if should load more items (for infinite scroll)
  bool shouldLoadMore(int index) {
    return index >= _currentPageItems.length - 5 &&
        _hasMoreItems &&
        !_isLoading;
  }
}
