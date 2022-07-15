import CloudKit
import Foundation
import os.log

extension SyncEngine {

  // MARK: - Internal

  func performUpdate(with context: RecordModifyingContext) {
    self.logHandler("\(#function)", .debug)

    guard !context.recordIDsToDelete.isEmpty || !context.recordsToSave.isEmpty else { return }

    self.logHandler(
      "Using \(context.name) context, found %d local items(s) for upload and \(context.recordsToSave.count) for deletion.",
      .debug
    )

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

    logHandler(
      "Sending \(recordsToSave.count) record(s) for upload and \(recordIDsToDelete.count) record(s) for deletion.",
      .debug)

    let operation = CKModifyRecordsOperation(
      recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)

    operation.modifyRecordsCompletionBlock = { [weak self] serverRecords, deletedRecordIDs, error in
      guard let self = self else { return }

      if let error = error {
        self.logHandler("Failed to \(context.name) records: \(String(describing: error))", .error)

        self.workQueue.async {
          self.handleError(
            error,
            toSave: recordsToSave,
            recordIDsToDelete: recordIDsToDelete,
            context: context
          )
        }
      } else {
        self.logHandler(
          "Successfully \(context.name) record(s). Saved \(recordsToSave.count) and deleted \(recordIDsToDelete.count)",
          .info)

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
      logHandler(
        "Error was not a CKError, giving up: \(String(describing: error))", .fault)
      return
    }

    switch ckError {

    case _ where ckError.isCloudKitZoneDeleted:
      logHandler(
        "Zone was deleted, recreating zone: \(String(describing: error))", .error)
      guard initializeZone(with: self.cloudOperationQueue) else {
        logHandler(
          "Unable to create zone, error is not recoverable: \(String(describing: error))", .fault)
        return
      }
      self.modifyRecords(
        toSave: recordsToSave,
        recordIDsToDelete: recordIDsToDelete,
        context: context
      )

    case _ where ckError.code == CKError.Code.limitExceeded:
      logHandler(
        "CloudKit batch limit exceeded, trying to \(context.name) records in chunks", .error)

      let firstHalfSave = Array(recordsToSave[0..<recordsToSave.count / 2])
      let secondHalfSave = Array(recordsToSave[recordsToSave.count / 2..<recordsToSave.count])

      let firstHalfDelete = Array(recordIDsToDelete[0..<recordIDsToDelete.count / 2])
      let secondHalfDelete = Array(
        recordIDsToDelete[recordIDsToDelete.count / 2..<recordIDsToDelete.count])

      let results = [(firstHalfSave, firstHalfDelete), (secondHalfSave, secondHalfDelete)].map {
        (save: [CKRecord], delete: [CKRecord.ID]) in
        error.retryCloudKitOperationIfPossible(self.logHandler, queue: self.workQueue) {
          self.modifyRecords(
            toSave: save,
            recordIDsToDelete: delete,
            context: context
          )
        }
      }

      if !results.allSatisfy({ $0 == true }) {
        logHandler(
          "Error is not recoverable: \(String(describing: error))", .error)
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
          .compactMap { $0.resolveConflict(logHandler, with: Model.resolveConflict) }

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
      if let resolvedRecord = error.resolveConflict(logHandler, with: Model.resolveConflict) {
        logHandler("Conflict resolved, will retry upload", .info)
        self.modifyRecords(
          toSave: [resolvedRecord],
          recordIDsToDelete: [],
          context: context
        )
      } else {
        logHandler(
          "Resolving conflict returned a nil record. Giving up.", .error
        )
      }

    case _
    where ckError.code == .serviceUnavailable
      || ckError.code == .networkUnavailable
      || ckError.code == .networkFailure
      || ckError.code == .serverResponseLost:
      logHandler(
        "Unable to connect to iCloud servers: \(String(describing: error))", .info)

    case _ where ckError.code == .unknownItem:
      logHandler(
        "Unknown item, ignoring: \(String(describing: error))", .info)

    default:
      let result = error.retryCloudKitOperationIfPossible(self.logHandler, queue: self.workQueue) {
        self.modifyRecords(
          toSave: recordsToSave,
          recordIDsToDelete: recordIDsToDelete,
          context: context
        )
      }

      if !result {
        logHandler(
          "Error is not recoverable: \( String(describing: error))", .error)
        context.failedToUpdateRecords(
          recordsSaved: recordsToSave, recordIDsDeleted: recordIDsToDelete)
      }
    }
  }
}
