import AppKit
import SwiftUI

struct PointerTrackingView: NSViewRepresentable {
  var onEntered: (() -> Void)? = nil
  var onExited: (() -> Void)? = nil
  var onMoved: (() -> Void)? = nil

  func makeNSView(context: Context) -> TrackingView {
    let view = TrackingView()
    view.onEntered = onEntered
    view.onExited = onExited
    view.onMoved = onMoved
    return view
  }

  func updateNSView(_ nsView: TrackingView, context: Context) {
    nsView.onEntered = onEntered
    nsView.onExited = onExited
    nsView.onMoved = onMoved
    nsView.updateTrackingAreas()
  }
}

final class TrackingView: NSView {
  var onEntered: (() -> Void)?
  var onExited: (() -> Void)?
  var onMoved: (() -> Void)?

  private var trackingArea: NSTrackingArea?

  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    if let trackingArea {
      removeTrackingArea(trackingArea)
    }

    var options: NSTrackingArea.Options = [
      .activeInKeyWindow,
      .inVisibleRect
    ]

    if onEntered != nil || onExited != nil {
      options.insert(.mouseEnteredAndExited)
    }

    if onMoved != nil {
      options.insert(.mouseMoved)
    }

    let trackingArea = NSTrackingArea(
      rect: bounds,
      options: options,
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    self.trackingArea = trackingArea
  }

  override func mouseEntered(with event: NSEvent) {
    onEntered?()
  }

  override func mouseExited(with event: NSEvent) {
    onExited?()
  }

  override func mouseMoved(with event: NSEvent) {
    onMoved?()
  }
}
