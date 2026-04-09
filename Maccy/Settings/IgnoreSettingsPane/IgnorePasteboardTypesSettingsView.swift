import Defaults
import SwiftUI

struct IgnorePasteboardTypesSettingsView: View {
  @Default(.ignoredPasteboardTypes) private var ignoredPasteboardTypes

  @FocusState private var focus: String.ID?
  @State private var edit = ""
  @State private var selection = ""

  var body: some View {
    VStack(alignment: .leading) {
      if #available(macOS 13.0, *) {
        List(selection: $selection) {
          rows
        }
        .onDeleteCommand {
          remove(selection)
        }
      } else {
        List {
          rows
        }
        .onDeleteCommand {
          remove(selection)
        }
      }

      HStack {
        HStack(spacing: 8) {
          Button {
            ignoredPasteboardTypes.insert("xxx.yyy.zzz")
            focus = "xxx.yyy.zzz"
          } label: {
            Image(systemName: "plus")
          }

          Button {
            remove(selection)
          } label: {
            Image(systemName: "minus")
          }
        }
        .frame(width: 50)

        Spacer()

        Button {
          Defaults.reset(.ignoredPasteboardTypes)
        } label: {
          Text("IgnoredPasteboardTypesReset", tableName: "IgnoreSettings")
        }
      }

      Text("IgnoredPasteboardTypesDescription", tableName: "IgnoreSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
    }
    .padding()
  }

  private func remove(_ type: String?) {
    guard let type else { return }

    ignoredPasteboardTypes.remove(type)
  }

  @ViewBuilder
  private var rows: some View {
    ForEach(ignoredPasteboardTypes.sorted()) { type in
      TextField("", text: Binding(
        get: { type },
        set: {
          guard !$0.isEmpty, type != $0 else { return }
          edit = $0
        })
      )
      .onSubmit {
        remove(type)
        ignoredPasteboardTypes.insert(edit)
      }
      .focused($focus, equals: type)
      .tag(type)
      .contentShape(Rectangle())
      .onTapGesture {
        selection = type
      }
    }
  }
}

private struct IgnorePasteboardTypesSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    IgnorePasteboardTypesSettingsView()
      .environment(\.locale, .init(identifier: "en"))
  }
}
