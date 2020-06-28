import CloudKitCodable
import Foundation

struct UUIDModel: CloudKitCodable {
  var cloudKitSystemFields: Data?
  var cloudKitIdentifier: String
  var uuid: UUID

  static func resolveConflict(
    clientModel clientRecord: UUIDModel, serverModel serverRecord: UUIDModel
  ) -> UUIDModel? {
    return nil
  }
}

extension UUIDModel {
  static var uuidModelMock = UUIDModel(
    cloudKitSystemFields: nil,
    cloudKitIdentifier: UUID().uuidString,
    uuid: UUID(uuidString: "0D2E7B29-AC4C-4A04-B57E-5CA0D208E55F")!
  )
}
