import CloudKit
import Foundation
import os.log

public enum AccountStatus: Equatable {
  case unknown
  case couldNotDetermine
  case available
  case restricted
  case noAccount
}

extension SyncEngine {

  // MARK: - Internal

  func observeAccountStatus() {
    NotificationCenter.default.publisher(for: .CKAccountChanged, object: nil).sink {
      [weak self] _ in
      self?.updateAccountStatus()
    }
    .store(in: &cancellables)

    updateAccountStatus()
  }

  // MARK: - Private

  private func updateAccountStatus() {
    logHandler(#function, .debug)
    container.accountStatus { [weak self] status, error in
      if let error = error {
        self?.logHandler(
          "Error retriving iCloud account status: \(error.localizedDescription)", .error)
      }

      DispatchQueue.main.async {
        let accountStatus: AccountStatus
        switch status {
        case .available:
          accountStatus = .available
        case .couldNotDetermine:
          accountStatus = .couldNotDetermine
        case .noAccount:
          accountStatus = .noAccount
        case .restricted:
          accountStatus = .restricted
        default:
          accountStatus = .unknown
        }
        self?.accountStatus = accountStatus
      }
    }
  }
}
