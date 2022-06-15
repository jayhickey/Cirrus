import CloudKit
import Foundation
import os.log

extension SyncEngine {

  // MARK: - Internal

  func performUpdate(with context: RecordModifyingContext) {
    os_log("%{public}@", log: log, type: .debug, #function)

    guard !context.recordIDsToDelete.isEmpty || !context.recordsToSave.isEmpty else { return }

    os_log(
      "Using %{public}@ context, found %d local items(s) for upload and %d for deletion.",
      log: self.log, type: .debug, context.name, context.recordsToSave.count,
      context.recordIDsToDelete.count)

    modifyRecords(with: context)
  }

  func modifyRecords(with context: RecordModifyingContext) {
    modifyRecords(
      toSave: Array(context.recordsToSave.values), recordIDsToDelete: context.recordIDsToDelete,
      context: context)
  }

  // MARK: - Private

  private func modifyRecords(
    toSave recordsToSave: [CKRecord],
    recordIDsToDelete: [CKRecord.ID],
    context: RecordModifyingContextProvider
  ) {
    guard !recordIDsToDelete.isEmpty || !recordsToSave.isEmpty else { return }

    os_log(
      "%{public}@ with %d record(s) for upload and %d record(s) for deletion.", log: log,
      type: .debug, #function, recordsToSave.count, recordIDsToDelete.count)

    let operation = CKModifyRecordsOperation(
      recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)

    operation.modifyRecordsCompletionBlock = { [weak self] serverRecords, deletedRecordIDs, error in
      guard let self = self else { return }

      if let error = error {
        os_log(
          "Failed to %{public}@ records: %{public}@", log: self.log, type: .error, context.name,
          String(describing: error))

        self.workQueue.async {
          self.handleError(
            error,
            toSave: recordsToSave,
            recordIDsToDelete: recordIDsToDelete,
            context: context
          )
        }
      } else {
        os_log(
          "Successfully %{public}@ record(s). Saved %d and deleted %d", log: self.log, type: .info,
          context.name, recordsToSave.count, recordIDsToDelete.count)

        self.workQueue.async {
          self.modelsChangedSubject.send(
            context.modelChangeForUpdatedRecords(
              recordsSaved: serverRecords ?? [],
              recordIDsDeleted: deletedRecordIDs ?? []
            )
          )
        }
      }
    }

    operation.savePolicy = context.savePolicy
    operation.qualityOfService = .userInitiated
    operation.database = privateDatabase

    cloudOperationQueue.addOperation(operation)
  }

  // MARK: - Private

  private func handleError(
    _ error: Error,
    toSave recordsToSave: [CKRecord],
    recordIDsToDelete: [CKRecord.ID],
    context: RecordModifyingContextProvider
  ) {
    guard let ckError = error as? CKError else {
      os_log(
        "Error was not a CKError, giving up: %{public}@", log: self.log, type: .fault,
        String(describing: error))
      return
    }

    switch ckError {

    case _ where ckError.isCloudKitZoneDeleted:
      os_log(
        "Zone was deleted, recreating zone: %{public}@", log: self.log, type: .error,
        String(describing: error))
      guard initializeZone(with: self.cloudOperationQueue) else {
        os_log(
          "Unable to create zone, error is not recoverable", log: self.log, type: .fault,
          String(describing: error))
        return
      }
      self.modifyRecords(
        toSave: recordsToSave,
        recordIDsToDelete: recordIDsToDelete,
        context: context
      )

    case _ where ckError.code == CKError.Code.limitExceeded:
      os_log(
        "CloudKit batch limit exceeded, trying to %{public}@ records in chunks", log: self.log,
        type: .error, context.name)

      let firstHalfSave = Array(recordsToSave[0..<recordsToSave.count / 2])
      let secondHalfSave = Array(recordsToSave[recordsToSave.count / 2..<recordsToSave.count])

      let firstHalfDelete = Array(recordIDsToDelete[0..<recordIDsToDelete.count / 2])
      let secondHalfDelete = Array(
        recordIDsToDelete[recordIDsToDelete.count / 2..<recordIDsToDelete.count])

      let results = [(firstHalfSave, firstHalfDelete), (secondHalfSave, secondHalfDelete)].map {
        (save: [CKRecord], delete: [CKRecord.ID]) in
        error.retryCloudKitOperationIfPossible(self.log, queue: self.workQueue) {
          self.modifyRecords(
            toSave: save,
            recordIDsToDelete: delete,
            context: context
          )
        }
      }

      if !results.allSatisfy({ $0 == true }) {
        os_log(
          "Error is not recoverable: %{public}@", log: self.log, type: .error,
          String(describing: error))
      }

    case _ where ckError.code == .partialFailure:
      if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
        let recordIDsNotSavedOrDeleted = Set(partialErrors.keys)

        let batchRequestFailedRecordIDs = Set(
          partialErrors.filter({ (_, error) in
            if let error = error as? CKError,
              error.code == .batchRequestFailed
            {
              return true
            }
            return false
          }).keys)

        let serverRecordChangedErrors = partialErrors.filter({ (_, error) in
          if let error = error as? CKError,
            error.code == .serverRecordChanged
          {
            return true
          }
          return false
        }).values

        let unknownItemRecordIDs = Set(
          partialErrors.filter({ (_, error) in
            if let error = error as? CKError,
              error.code == .unknownItem
            {
              return true
            }
            return false
          }).keys)

        context.failedToUpdateRecords(
          recordsSaved: recordsToSave.filter { unknownItemRecordIDs.contains($0.recordID) },
          recordIDsDeleted: recordIDsToDelete.filter(unknownItemRecordIDs.contains)
        )

        let recordsToSaveWithoutUnknowns =
          recordsToSave
          .filter { recordIDsNotSavedOrDeleted.contains($0.recordID) }
          .filter { !unknownItemRecordIDs.contains($0.recordID) }

        let recordIDsToDeleteWithoutUnknowns =
          recordIDsToDelete
          .filter(recordIDsNotSavedOrDeleted.contains)
          .filter { !unknownItemRecordIDs.contains($0) }

        let resolvedConflictsToSave =
          serverRecordChangedErrors
          .compactMap { $0.resolveConflict(log, with: Model.resolveConflict) }

        let conflictsToSaveSet = Set(resolvedConflictsToSave.map(\.recordID))
        let batchRequestFailureRecordsToSave = recordsToSaveWithoutUnknowns.filter {
          !conflictsToSaveSet.contains($0.recordID)
            && batchRequestFailedRecordIDs.contains($0.recordID)
        }

        modifyRecords(
          toSave: batchRequestFailureRecordsToSave + resolvedConflictsToSave,
          recordIDsToDelete: recordIDsToDeleteWithoutUnknowns,
          context: context
        )
      }

    case _ where ckError.code == .serverRecordChanged:
      if let resolvedRecord = error.resolveConflict(log, with: Model.resolveConflict) {
        os_log("Conflict resolved, will retry upload", log: self.log, type: .info)
        self.modifyRecords(
          toSave: [resolvedRecord],
          recordIDsToDelete: [],
          context: context
        )
      } else {
        os_log(
          "Resolving conflict returned a nil record. Giving up.",
          log: self.log,
          type: .error
        )
      }

    case _
    where ckError.code == .serviceUnavailable
      || ckError.code == .networkUnavailable
      || ckError.code == .networkFailure
      || ckError.code == .serverResponseLost:
      os_log(
        "Unable to connect to iCloud servers: %{public}@", log: self.log, type: .info,
        String(describing: error))

    case _ where ckError.code == .unknownItem:
      os_log(
        "Unknown item, ignoring: %{public}@", log: self.log, type: .info, String(describing: error))

    default:
      let result = error.retryCloudKitOperationIfPossible(self.log, queue: self.workQueue) {
        self.modifyRecords(
          toSave: recordsToSave,
          recordIDsToDelete: recordIDsToDelete,
          context: context
        )
      }

      if !result {
        os_log(
          "Error is not recoverable: %{public}@", log: self.log, type: .error,
          String(describing: error))
        context.failedToUpdateRecords(
          recordsSaved: recordsToSave, recordIDsDeleted: recordIDsToDelete)
      }
    }
  }
}
