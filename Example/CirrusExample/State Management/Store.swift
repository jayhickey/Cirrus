import Foundation

public typealias Effect = () -> Void

public typealias Reducer = (inout AppState, AppAction) -> [Effect]

public func defaultStore() -> Store {
  let appState = PersistentStore.load()
  return Store(value: appState ?? AppState(), reducer: appReducer)
}

public class Store: ObservableObject {
  @Published public internal(set) var value: AppState
  private let reducer: Reducer

  lazy var defaultEffects: [Effect] = [
    { PersistentStore.save(state: self.value) }
  ]

  public init(value: AppState, reducer: @escaping Reducer) {
    self.value = value
    self.reducer = reducer
  }

  public func dispatch(_ action: AppAction) {
    let effects = reducer(&value, action)
    (effects + defaultEffects).forEach { $0() }
  }
}
