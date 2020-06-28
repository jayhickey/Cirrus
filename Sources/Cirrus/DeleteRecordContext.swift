@_implementationOnly import CKRecordCoder
import CloudKit
import CloudKitCodable
import Foundation
import os.log

final class DeleteRecordContext<Persistable: CloudKitCodable>: RecordModifyingContext {

  private let defaults: UserDefaults
  private let zoneID: CKRecordZone.ID
  private let log: OSLog

  private lazy var deleteBufferKey = "DELETEBUFFER-\(zoneID.zoneName))"

  init(defaults: UserDefaults, zoneID: CKRecordZone.ID, log: OSLog) {
    self.defaults = defaults
    self.zoneID = zoneID
    self.log = log
  }

  func buffer(_ values: [Persistable]) {
    let recordIDs: [CKRecord.ID]
    do {
      recordIDs = try values.map { try CKRecordEncoder(zoneID: zoneID).encode($0).recordID }
    } catch let error {
      os_log(
        "Failed to encode records for delete:  %{public}@", log: log, type: .error,
        String(describing: error))
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
        os_log(
          "Failed to decode CKRecord.IDs from defaults key deleteBufferKey", log: log, type: .error)
        return []
      }
    }
    set {
      do {
        os_log(
          "Updating %{public}@ buffer with %d items", log: log, type: .info, name, newValue.count)
        let data = try NSKeyedArchiver.archivedData(
          withRootObject: newValue, requiringSecureCoding: true)
        defaults.set(data, forKey: deleteBufferKey)
      } catch {
        os_log(
          "Failed to encode record ids for deletion: %{public}@", log: log, type: .error,
          String(describing: error))
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
