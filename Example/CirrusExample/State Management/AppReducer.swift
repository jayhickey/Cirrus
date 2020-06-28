import Cirrus
import Foundation

public func appReducer(appState: inout AppState, actions: AppAction) -> [Effect] {
  switch actions {
  case let .addBookmark(url):
    let bookmark = Bookmark(
      created: Date(), title: url.host ?? "New Bookmark",
      url: url)
    appState.bookmarks.insert(bookmark)
    return [{ syncManager?.engine.upload(bookmark) }]

  case .removeBookmarks(let bookmarks):
    let bookmarksToDelete = appState.bookmarks
      .filter { bookmarks.map(\.cloudKitIdentifier).contains($0.cloudKitIdentifier) }
    bookmarksToDelete
      .forEach { appState.bookmarks.remove($0) }
    return [{ syncManager?.engine.delete(Array(bookmarksToDelete)) }]

  case .modifyBookmarks(let bookmarks):
    let bookmarks: [Bookmark] = bookmarks.compactMap { updatedBookmark in
      guard
        var bookmark = appState.bookmarks.first(where: {
          $0.cloudKitIdentifier == updatedBookmark.cloudKitIdentifier
        }),
        let randomNewURL = testURLs.randomElement()
      else { return nil }
      bookmark.title = randomNewURL.host ?? "New Bookmark"
      bookmark.url = randomNewURL
      return bookmark
    }
    bookmarks.forEach { appState.bookmarks.insertOrReplace($0) }
    return [{ syncManager?.engine.upload(bookmarks) }]

  case .cloudUpdated(let bookmarks):
    bookmarks.forEach { appState.bookmarks.insertOrReplace($0) }
    return []

  case .cloudDeleted(let identifiers):
    let bookmarksToDelete = appState.bookmarks
      .filter { identifiers.contains($0.cloudKitIdentifier) }
    bookmarksToDelete
      .forEach { appState.bookmarks.remove($0) }
    return []

  case .fetchCloudChanges:
    return [{ syncManager?.engine.forceSync() }]
  }
}

extension Set where Set.Element == Bookmark {
  mutating func insertOrReplace(_ item: Bookmark) {
    if let bookmark = self.first(where: { $0.cloudKitIdentifier == item.cloudKitIdentifier }) {
      remove(bookmark)
    }
    insert(item)
  }
}
