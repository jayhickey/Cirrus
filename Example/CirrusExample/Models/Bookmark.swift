import CloudKitCodable
import Foundation

public struct Bookmark {
  public var id: UUID
  public var cloudKitSystemFields: Data?
  public var cloudKitIdentifier: CloudKitIdentifier {
    return id.uuidString
  }

  public var created: Date
  public var title: String
  public var url: URL

  public init(
    id: UUID = UUID(),
    created: Date = Date(),
    title: String,
    url: URL
  ) {
    self.id = id
    self.created = created
    self.title = title
    self.url = url
  }
}

extension Bookmark: CloudKitCodable {
  public static func resolveConflict(clientModel: Self, serverModel: Self) -> Self? {
    if let clientDate = clientModel.cloudKitLastModifiedDate,
      let serverDate = serverModel.cloudKitLastModifiedDate
    {
      return clientDate > serverDate ? clientModel : serverModel
    }
    return serverModel
  }
}
