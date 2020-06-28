import CloudKit
import Foundation

public protocol CloudKitEncodable: Encodable {}

public protocol CloudKitDecodable: Decodable {}

public typealias CloudKitIdentifier = String

public protocol CloudKitCodable: CloudKitEncodable & CloudKitDecodable & Hashable {
  /// A property for storing system fields from CloudKit.
  ///
  /// This value is managed by the sync engine and should be set to nil when creating a new model.
  /// If you are persisting your models locally, be sure to persist this property so it can be read by the sync
  /// engine when peforming updates to your model.
  var cloudKitSystemFields: Data? { get set }

  /// A unique identifier for the model used to locate records in the CloudKit database.
  var cloudKitIdentifier: CloudKitIdentifier { get }

  /// A function for resolving conflicts between a the server and client record. Use this to determine
  /// how conflicts between two models with the same `cloudKitIdentifier` should be resolved.
  static func resolveConflict(clientModel: Self, serverModel: Self) -> Self?
}
