import AppKit
import AVFoundation
import SwiftUI

final class Preview: NSView {
    private let surface = NSView()
    private let video: AVCaptureVideoPreviewLayer
    private let placeholder: NSHostingView<CameraPlaceholder>

    init(video: AVCaptureVideoPreviewLayer, action: @escaping () -> Void) {
        self.video = video
        placeholder = NSHostingView(rootView: CameraPlaceholder(state: .starting, action: action))
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor(srgbRed: 0.07, green: 0.10, blue: 0.10, alpha: 1).cgColor

        surface.wantsLayer = true
        surface.layer?.masksToBounds = true
        surface.layer?.cornerCurve = .continuous
        surface.layer?.backgroundColor = NSColor.black.cgColor
        video.videoGravity = .resizeAspectFill
        video.isHidden = true
        surface.layer?.addSublayer(video)

        surface.translatesAutoresizingMaskIntoConstraints = false
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surface)
        surface.addSubview(placeholder)
        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            surface.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            surface.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            surface.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            placeholder.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            placeholder.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            placeholder.topAnchor.constraint(equalTo: surface.topAnchor),
            placeholder.bottomAnchor.constraint(equalTo: surface.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("Use init(video:action:)") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        video.frame = surface.bounds
        CATransaction.commit()
    }

    func applyAppearance(hex: Int, width: Double, radius: Double) {
        surface.layer?.borderColor = Appearance.color(hex).cgColor
        surface.layer?.borderWidth = width
        surface.layer?.cornerRadius = radius
    }

    func setState(_ state: CameraState) {
        let live = state == .live
        video.isHidden = !live
        placeholder.isHidden = live
        placeholder.rootView.state = state
        needsLayout = true
    }
}

struct CameraPlaceholder: View {
    var state: CameraState
    let action: () -> Void

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(red: 0.10, green: 0.22, blue: 0.20),
                                    Color(red: 0.045, green: 0.075, blue: 0.079)],
                           center: .init(x: 0.5, y: 0.36), startRadius: 0, endRadius: 330)
            Canvas { context, size in
                var grid = Path()
                for x in stride(from: (size.width / 2).truncatingRemainder(dividingBy: 22),
                                to: size.width, by: 22.0) {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0.0, to: size.height, by: 22.0) {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.045)), lineWidth: 0.5)
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Image(systemName: state == .permission || state == .starting ? "video" : "video.slash")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(Color(nsColor: Appearance.color(0x9BF1CC)))
                    .frame(width: 55, height: 55)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12)))
                    .accessibilityHidden(true)

                VStack(spacing: 5) {
                    Text(copy.title).font(.system(size: 18, weight: .semibold))
                    if let detail = copy.detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                if let label = copy.button {
                    Button(label, action: action)
                        .buttonStyle(.borderedProminent)
                        .tint(Color(nsColor: Appearance.color(0xA2F1CF)))
                        .foregroundStyle(Color(nsColor: Appearance.color(0x0B261D)))
                        .controlSize(.regular)
                }
            }
            .padding(18)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
        }
        .environment(\.colorScheme, .dark)
    }

    private var copy: (title: String, detail: String?, button: String?) {
        switch state {
        case .permission: ("Enable your camera", "Allow camera access to start the live preview.", "Enable Camera")
        case .denied: ("Camera access is off", "Allow Sideglance in Privacy & Security → Camera.", "Open System Settings")
        case .restricted: ("Camera access is restricted", "This Mac’s privacy settings restrict camera access.", nil)
        case .unavailable: ("No camera connected", "Connect a camera to start the preview.", "Try Again")
        case .failed: ("Camera couldn’t start", "Check your camera connection or choose another camera from the Camera menu.", "Try Again")
        case .interrupted: ("Camera interrupted", "The preview will resume when the camera is available.", "Try Again")
        case .inactive, .starting, .live: ("Starting camera…", nil, nil)
        }
    }
}
