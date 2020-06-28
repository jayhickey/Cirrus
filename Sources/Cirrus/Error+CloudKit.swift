@_implementationOnly import CKRecordCoder
import CloudKit
import CloudKitCodable
import Foundation
import os.log

extension Error {

  /// Whether this error represents a "zone not found" or a "user deleted zone" error
  var isCloudKitZoneDeleted: Bool {
    guard let effectiveError = self as? CKError else { return false }

    return [.zoneNotFound, .userDeletedZone].contains(effectiveError.code)
  }

  /// Uses the `resolver` closure to resolve a conflict, returning the conflict-free record
  ///
  /// - Parameter resolver: A closure that will receive the client record as the first param and the server record as the second param.
  /// This closure is responsible for handling the conflict and returning the conflict-free record.
  /// - Returns: The conflict-free record returned by `resolver`
  func resolveConflict<Persistable: CloudKitCodable>(
    _ log: OSLog = .default, with resolver: (Persistable, Persistable) -> Persistable?
  ) -> CKRecord? {
    guard let effectiveError = self as? CKError else {
      os_log(
        "resolveConflict called on an error that was not a CKError. The error was %{public}@",
        log: log,
        type: .fault,
        String(describing: self))
      return nil
    }

    guard effectiveError.code == .serverRecordChanged else {
      os_log(
        "resolveConflict called on a CKError that was not a serverRecordChanged error. The error was %{public}@",
        log: log,
        type: .fault,
        String(describing: effectiveError))
      return nil
    }

    guard let clientRecord = effectiveError.clientRecord else {
      os_log(
        "Failed to obtain client record from serverRecordChanged error. The error was %{public}@",
        log: log,
        type: .fault,
        String(describing: effectiveError))
      return nil
    }

    guard let serverRecord = effectiveError.serverRecord else {
      os_log(
        "Failed to obtain server record from serverRecordChanged error. The error was %{public}@",
        log: log,
        type: .fault,
        String(describing: effectiveError))
      return nil
    }

    os_log(
      "CloudKit conflict with record of type %{public}@. Running conflict resolver", log: log,
      type: .error, serverRecord.recordType)

    // Always return the server record so we don't end up in a conflict loop (the server record has the change tag we want to use)
    // https://developer.apple.com/documentation/cloudkit/ckerror/2325208-serverrecordchanged
    guard
      let clientPersistable = try? CKRecordDecoder().decode(
        Persistable.self, from: clientRecord),
      let serverPersistable = try? CKRecordDecoder().decode(
        Persistable.self, from: serverRecord),
      let resolvedPersistable = resolver(clientPersistable, serverPersistable),
      let resolvedRecord = try? CKRecordEncoder(zoneID: serverRecord.recordID.zoneID).encode(
        resolvedPersistable)
    else { return nil }
    resolvedRecord.allKeys().forEach { serverRecord[$0] = resolvedRecord[$0] }
    return serverRecord
  }

  /// Retries a CloudKit operation if the error suggests it
  ///
  /// - Parameters:
  ///   - log: The logger to use for logging information about the error handling, uses the default one if not set
  ///   - block: The block that will execute the operation later if it can be retried
  /// - Returns: Whether or not it was possible to retry the operation
  @discardableResult func retryCloudKitOperationIfPossible(
    _ log: OSLog? = nil, queue: DispatchQueue, with block: @escaping () -> Void
  ) -> Bool {
    let effectiveLog: OSLog = log ?? .default

    guard let effectiveError = self as? CKError else { return false }

    guard let retryDelay: Double = effectiveError.retryAfterSeconds else {
      os_log("Error is not recoverable", log: effectiveLog, type: .error)
      return false
    }

    os_log(
      "Error is recoverable. Will retry after %{public}f seconds", log: effectiveLog, type: .error,
      retryDelay)

    queue.asyncAfter(deadline: .now() + retryDelay) {
      block()
    }

    return true
  }

}
