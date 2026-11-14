import AppKit
import SwiftUI

final class Appearance: ObservableObject {
    private let defaults = UserDefaults.standard

    static let palette: [(name: String, hex: Int)] = [
        ("Mint", 0x86E6BE), ("Cloud", 0xF2F5F4), ("Ink", 0x181E21),
        ("Sky", 0x8DBAFF), ("Lilac", 0xCFB3FB), ("Coral", 0xFFA28F)
    ]

    @Published var borderHex = 0x86E6BE {
        didSet { defaults.set(borderHex, forKey: "borderHex") }
    }
    @Published var borderWidth = 3.0 {
        didSet { defaults.set(borderWidth, forKey: "borderWidth") }
    }
    @Published var cornerRadius = 12.0 {
        didSet { defaults.set(cornerRadius, forKey: "cornerRadius") }
    }
    @Published var pinned = true {
        didSet { defaults.set(pinned, forKey: "pinned") }
    }
    @Published var mirrored = true {
        didSet { defaults.set(mirrored, forKey: "mirrored") }
    }
    @Published var hexText = ""

    init() {
        defaults.register(defaults: ["borderHex": 0x86E6BE, "borderWidth": 3.0,
                                     "cornerRadius": 12.0, "pinned": true, "mirrored": true])
        borderHex = min(max(defaults.integer(forKey: "borderHex"), 0), 0xFFFFFF)
        borderWidth = min(max(defaults.double(forKey: "borderWidth"), 0), 20)
        cornerRadius = min(max(defaults.double(forKey: "cornerRadius"), 0), 48)
        pinned = defaults.bool(forKey: "pinned")
        mirrored = defaults.bool(forKey: "mirrored")
    }

    static func color(_ hex: Int) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

struct AppearanceView: View {
    @ObservedObject var appearance: Appearance
    @FocusState private var editingHex: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Border")
                .font(.system(size: 16, weight: .semibold))
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 8) {
                Text("Color").font(.callout.weight(.medium))
                HStack(spacing: 8) {
                    ForEach(Appearance.palette, id: \.hex) { preset in
                        swatch(preset.name, hex: preset.hex)
                    }
                    Spacer(minLength: 0)
                    TextField("Hex color", text: $appearance.hexText)
                        .font(.system(size: 11, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 73)
                        .focused($editingHex)
                        .help("Enter a six-digit hex color")
                        .onChange(of: appearance.hexText) { _, value in applyHex(value) }
                        .onChange(of: editingHex) { _, focused in
                            if !focused { appearance.hexText = formattedHex }
                        }
                        .onSubmit { appearance.hexText = formattedHex }
                }
            }

            VStack(spacing: 12) {
                setting("Width", value: $appearance.borderWidth, range: 0...20)
                setting("Corner radius", value: $appearance.cornerRadius, range: 0...48)
            }

            Divider()
            Toggle("Mirror preview", isOn: $appearance.mirrored)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(16)
        .frame(width: 310)
        .onAppear { appearance.hexText = formattedHex }
    }

    private var formattedHex: String { String(format: "#%06X", appearance.borderHex) }

    private func swatch(_ name: String, hex: Int) -> some View {
        let selected = appearance.borderHex == hex
        return Button {
            appearance.borderHex = hex
            appearance.hexText = formattedHex
        } label: {
            Circle()
                .fill(Color(nsColor: Appearance.color(hex)))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.16)))
                .padding(3)
                .overlay(Circle().strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 2))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func applyHex(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.hasPrefix("#") ? trimmed.dropFirst() : trimmed[...]
        guard digits.utf8.count == 6, digits.utf8.allSatisfy({
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }), let value = Int(digits, radix: 16), value != appearance.borderHex else { return }
        appearance.borderHex = value
    }

    private func setting(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.callout.weight(.medium))
                Spacer()
                Text("\(Int(value.wrappedValue)) pt")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Slider(value: value, in: range, step: 1) { Text(title) }
                .labelsHidden()
                .controlSize(.small)
        }
    }
}
