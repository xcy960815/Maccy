import SwiftUI
import Defaults

struct IgnoreRegexpsSettingsView: View {
  @Default(.ignoreRegexp) private var ignoredRegexps

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

      HStack(spacing: 8) {
        Button {
          ignoredRegexps.append("^[a-zA-Z0-9]{50}$")
          focus = "^[a-zA-Z0-9]{50}$"
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

      Text("IgnoredRegexpsDescription", tableName: "IgnoreSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
    }.padding()
  }

  private func remove(_ regexp: String?) {
    guard let regexp else { return }

    ignoredRegexps.removeAll(where: { $0 == regexp })
  }

  @ViewBuilder
  private var rows: some View {
    ForEach(ignoredRegexps) { regexp in
      TextField("", text: Binding(
        get: { regexp },
        set: {
          guard !$0.isEmpty, regexp != $0 else { return }
          edit = $0
        })
      )
      .onSubmit {
        remove(regexp)
        ignoredRegexps.append(edit)
      }
      .focused($focus, equals: regexp)
      .tag(regexp)
      .contentShape(Rectangle())
      .onTapGesture {
        selection = regexp
      }
    }
  }
}

private struct IgnoreRegexpsSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    IgnoreRegexpsSettingsView()
      .environment(\.locale, .init(identifier: "en"))
  }
}
