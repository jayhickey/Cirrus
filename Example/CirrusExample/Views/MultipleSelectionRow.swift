import SwiftUI

struct MultipleSelectionRow<Content: View>: View {
  var childView: Content
  var isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: self.action) {
      HStack {
        childView
        if self.isSelected {
          Spacer()
          Image(systemName: "checkmark")
        }
      }
    }
  }
}
