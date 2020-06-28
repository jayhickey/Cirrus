import Cirrus
import CloudKit
import CloudKitCodable
import Combine
import Foundation

public class AppSyncManager: ObservableObject {
  public let engine: SyncEngine<Bookmark>

  @Published public private(set) var accountStatus: AccountStatus = .unknown

  private let dispatch: (AppAction) -> Void
  private var cancellables = Set<AnyCancellable>()

  public init(
    initialItems: Set<Bookmark>,
    dispatch: @escaping (AppAction) -> Void
  ) {

    self.engine = SyncEngine<Bookmark>(initialItems: Array(initialItems))

    self.dispatch = dispatch

    self.engine.$accountStatus
      .assign(to: \.accountStatus, on: self)
      .store(in: &cancellables)

    engine.modelsChanged
      .receive(on: DispatchQueue.main)
      .sink { [weak self] change in
        switch change {
        case let .updated(models):
          self?.dispatch(.cloudUpdated(models))
        case let .deleted(bookmarkIDs):
          self?.dispatch(.cloudDeleted(bookmarkIDs))
        }
      }
      .store(in: &cancellables)
  }
}
