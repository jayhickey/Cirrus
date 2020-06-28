import CloudKitCodable
import Foundation

struct URLModel: CloudKitCodable {
  var cloudKitSystemFields: Data? = nil

  var cloudKitIdentifier: String
  let urls: [URL]

  static func resolveConflict(clientModel: URLModel, serverModel: URLModel) -> Self? {
    return nil
  }
}
