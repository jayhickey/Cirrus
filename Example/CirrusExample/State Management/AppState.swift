import Foundation

public struct AppState: Codable {
  public internal(set) var bookmarks: Set<Bookmark> = []
}
