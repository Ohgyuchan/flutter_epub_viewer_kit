import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bookmark.dart';

class BookmarksNotifier extends Notifier<List<Bookmark>> {
  @override
  List<Bookmark> build() {
    return [];
  }

  void addBookmark(Bookmark bookmark) {
    // Prevent duplicates on same page
    if (state.any((b) => b.pageIndex == bookmark.pageIndex)) {
      return;
    }
    state = [...state, bookmark];
  }

  void removeBookmark(Bookmark bookmark) {
    state = state.where((b) => b.pageIndex != bookmark.pageIndex).toList();
  }

  void setBookmarks(List<Bookmark> bookmarks) {
    state = List.from(bookmarks);
  }

  bool isPageBookmarked(int pageIndex) {
    return state.any((b) => b.pageIndex == pageIndex);
  }
}

final bookmarksProvider =
    NotifierProvider<BookmarksNotifier, List<Bookmark>>(BookmarksNotifier.new);
