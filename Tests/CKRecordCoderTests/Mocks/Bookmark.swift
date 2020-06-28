import CloudKit
import CloudKitCodable
import Foundation

struct Bookmark: CloudKitCodable {
  var cloudKitSystemFields: Data?
  var cloudKitIdentifier: String
  var title: String

  static func resolveConflict(
    clientModel clientRecord: Bookmark, serverModel serverRecord: Bookmark
  ) -> Bookmark? {
    return nil
  }
}

extension Bookmark {
  static var testIdentifier = "29C1D1AD-18E0-47C1-B064-265D2458E650"
  static var bookmarkWithoutSystemFields = Bookmark(
    cloudKitSystemFields: nil,
    cloudKitIdentifier: Bookmark.testIdentifier,
    title: "Apple"
  )
}
