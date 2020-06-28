import CloudKitCodable
import Foundation

public enum AppAction {
  case addBookmark(URL)
  case removeBookmarks(Set<Bookmark>)
  case modifyBookmarks(Set<Bookmark>)

  // Cloud Sync
  case cloudUpdated(Set<Bookmark>)
  case cloudDeleted(Set<CloudKitIdentifier>)
  case fetchCloudChanges
}
