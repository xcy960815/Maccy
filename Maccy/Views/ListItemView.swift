import Defaults
import SwiftUI

enum SelectionAppearance {
  case none
  case topConnection
  case bottomConnection
  case topBottomConnection

  func rect(cornerRadius: CGFloat) -> some Shape {
    switch self {
    case .none:
      return SelectionShape(
        topLeading: cornerRadius,
        topTrailing: cornerRadius,
        bottomLeading: cornerRadius,
        bottomTrailing: cornerRadius
      )
    case .topConnection:
      return SelectionShape(
        bottomLeading: cornerRadius,
        bottomTrailing: cornerRadius
      )
    case .bottomConnection:
      return SelectionShape(
        topLeading: cornerRadius,
        topTrailing: cornerRadius
      )
    case .topBottomConnection:
      return SelectionShape()
    }
  }
}

private struct SelectionShape: Shape {
  var topLeading: CGFloat = 0
  var topTrailing: CGFloat = 0
  var bottomLeading: CGFloat = 0
  var bottomTrailing: CGFloat = 0

  func path(in rect: CGRect) -> Path {
    let topLeading = min(topLeading, min(rect.width, rect.height) / 2)
    let topTrailing = min(topTrailing, min(rect.width, rect.height) / 2)
    let bottomLeading = min(bottomLeading, min(rect.width, rect.height) / 2)
    let bottomTrailing = min(bottomTrailing, min(rect.width, rect.height) / 2)

    var path = Path()
    path.move(to: CGPoint(x: rect.minX + topLeading, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - topTrailing, y: rect.minY))

    if topTrailing > 0 {
      path.addArc(
        center: CGPoint(x: rect.maxX - topTrailing, y: rect.minY + topTrailing),
        radius: topTrailing,
        startAngle: .degrees(-90),
        endAngle: .degrees(0),
        clockwise: false
      )
    }

    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomTrailing))

    if bottomTrailing > 0 {
      path.addArc(
        center: CGPoint(x: rect.maxX - bottomTrailing, y: rect.maxY - bottomTrailing),
        radius: bottomTrailing,
        startAngle: .degrees(0),
        endAngle: .degrees(90),
        clockwise: false
      )
    }

    path.addLine(to: CGPoint(x: rect.minX + bottomLeading, y: rect.maxY))

    if bottomLeading > 0 {
      path.addArc(
        center: CGPoint(x: rect.minX + bottomLeading, y: rect.maxY - bottomLeading),
        radius: bottomLeading,
        startAngle: .degrees(90),
        endAngle: .degrees(180),
        clockwise: false
      )
    }

    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeading))

    if topLeading > 0 {
      path.addArc(
        center: CGPoint(x: rect.minX + topLeading, y: rect.minY + topLeading),
        radius: topLeading,
        startAngle: .degrees(180),
        endAngle: .degrees(270),
        clockwise: false
      )
    }

    path.closeSubpath()
    return path
  }
}

struct ListItemView<Title: View, ID: Hashable>: View {
  var id: ID
  var selectionId: UUID
  var appIcon: ApplicationImage?
  var image: NSImage?
  var accessoryImage: NSImage?
  var attributedTitle: AttributedString?
  var shortcuts: [KeyShortcut]
  var isSelected: Bool
  var selectionIndex: Int?
  var help: LocalizedStringKey?
  var selectionAppearance: SelectionAppearance = .none
  @ViewBuilder var title: () -> Title

  @Default(.showApplicationIcons) private var showIcons
  @Default(.imageMaxHeight) private var imageMaxHeight
  @EnvironmentObject private var modifierFlags: ModifierFlags

  private var imagePreviewHeight: CGFloat {
    max(
      Popup.itemHeight,
      min(CGFloat(imageMaxHeight), Popup.itemHeight + 6)
    )
  }

  private var imagePreviewWidth: CGFloat {
    max(imagePreviewHeight, min(imagePreviewHeight * 1.5, 56))
  }

  var body: some View {
    HStack(spacing: 0) {
      if showIcons, let appIcon {
        VStack {
          Spacer(minLength: 0)
          AppImageView(appImage: appIcon, size: NSSize(width: 15, height: 15))
          Spacer(minLength: 0)
        }
        .padding(.leading, 4)
        .padding(.vertical, 5)
      }

      Spacer()
        .frame(width: showIcons ? 5 : 10)

      if let accessoryImage {
        Image(nsImage: accessoryImage)
          .accessibilityIdentifier("copy-history-item")
          .frame(width: Popup.itemHeight, height: Popup.itemHeight)
          .padding(.trailing, 5)
          .padding(.vertical, 5)
      }

      if let image {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
          .accessibilityIdentifier("copy-history-item")
          .frame(width: imagePreviewWidth, height: imagePreviewHeight)
          .background(
            Color.primary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
          )
          .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
          .padding(.trailing, 5)
          .padding(.vertical, 3)
      }

      ListItemTitleView(attributedTitle: attributedTitle, title: title)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 5)
        .layoutPriority(1)

      Spacer()

      HStack(spacing: 5) {
        if let index = selectionIndex {
          Text("\(index + 1)")
            .font(.caption)
            .frame(minWidth: 10, alignment: .center)
            .padding(3)
            .background(
              Color.secondary.opacity(isSelected ? 0.5 : 0.8),
              in: Capsule()
            )
            .foregroundStyle(Color.white)
        }

        if !shortcuts.isEmpty {
          ZStack(alignment: .trailing) {
            ForEach(shortcuts) { shortcut in
              let visible = shortcut.isVisible(shortcuts, modifierFlags.flags)
              KeyboardShortcutView(shortcut: shortcut)
                .opacity(visible ? 1 : 0)
                .frame(width: visible ? nil : 0)
            }
          }
        }
      }
      .padding(.trailing, 10)
    }
    .frame(minHeight: Popup.itemHeight)
    .id(id)
    .frame(maxWidth: .infinity, alignment: .leading)
    .foregroundStyle(isSelected ? Color.white : .primary)
    // macOS 26 broke hovering if no background is present.
    // The slight opcaity white background is a workaround
    .background(isSelected ? Color.accentColor.opacity(0.8) : .white.opacity(0.001))
    .clipShape(selectionAppearance.rect(cornerRadius: Popup.cornerRadius))
    .hoverSelectionId(selectionId)
    .help(help ?? "")
  }
}
