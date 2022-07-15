@_implementationOnly import CKRecordCoder
import CloudKit
import CloudKitCodable
import Foundation
import os.log

final class DeleteRecordContext<Persistable: CloudKitCodable>: RecordModifyingContext {

  private let defaults: UserDefaults
  private let zoneID: CKRecordZone.ID
  private let logHandler: (String, OSLogType) -> Void

  private lazy var deleteBufferKey = "DELETEBUFFER-\(zoneID.zoneName))"

  init(
    defaults: UserDefaults, zoneID: CKRecordZone.ID,
    logHandler: @escaping (String, OSLogType) -> Void
  ) {
    self.defaults = defaults
    self.zoneID = zoneID
    self.logHandler = logHandler
  }

  func buffer(_ values: [Persistable]) {
    let recordIDs: [CKRecord.ID]
    do {
      recordIDs = try values.map { try CKRecordEncoder(zoneID: zoneID).encode($0).recordID }
    } catch let error {
      logHandler("Failed to encode records for delete: \(String(describing: error))", .error)
      recordIDs = values.compactMap { try? CKRecordEncoder(zoneID: zoneID).encode($0).recordID }
    }
    recordIDsToDelete.append(contentsOf: recordIDs)
  }

  // MARK: - RecordModifying

  let name = "delete"
  var savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .ifServerRecordUnchanged

  var recordsToSave: [CKRecord.ID: CKRecord] = [:]

  var recordIDsToDelete: [CKRecord.ID] {
    get {
      guard let data = defaults.data(forKey: deleteBufferKey) else { return [] }
      do {
        return try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [CKRecord.ID] ?? []
      } catch {
        logHandler("Failed to decode CKRecord.IDs from defaults key deleteBufferKey", .error)
        return []
      }
    }
    set {
      do {
        logHandler("Updating \(newValue.count) buffer with %d items", .info)
        let data = try NSKeyedArchiver.archivedData(
          withRootObject: newValue, requiringSecureCoding: true)
        defaults.set(data, forKey: deleteBufferKey)
      } catch {
        logHandler("Failed to encode record ids for deletion: \(String(describing: error))", .error)
      }
    }
  }

  func modelChangeForUpdatedRecords<T: CloudKitCodable>(
    recordsSaved: [CKRecord], recordIDsDeleted: [CKRecord.ID]
  )
    -> SyncEngine<T>.ModelChange
  {
    let recordIdentifiersDeletedSet = Set(recordIDsDeleted.map(\.recordName))

    recordIDsToDelete.removeAll { recordIDsDeleted.contains($0) }

    return .deleted(recordIdentifiersDeletedSet)
  }

  func failedToUpdateRecords(recordsSaved: [CKRecord], recordIDsDeleted: [CKRecord.ID]) {
    recordIDsToDelete.removeAll { recordIDsDeleted.contains($0) }
  }
}
