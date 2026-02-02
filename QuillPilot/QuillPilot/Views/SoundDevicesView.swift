//
//  SoundDevicesView.swift
//  QuillPilot
//
//  Created by QuillPilot Team
//  Copyright © 2025 QuillPilot. All rights reserved.
//

import SwiftUI

/// A view that displays detected sound devices in poetry
struct SoundDevicesView: View {
    let devices: [SoundDeviceDetector.SoundDevice]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "speaker.wave.3")
                    .foregroundColor(.secondary)
                Text("Sound Devices")
                    .font(.headline)
                Spacer()

                if !devices.isEmpty {
                    Text("\(devices.count) found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if devices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No notable sound devices detected")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ForEach(devices, id: \.type) { device in
                    SoundDeviceRow(device: device)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.windowBackgroundColor) : Color.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

/// Row displaying a single sound device
struct SoundDeviceRow: View {
    let device: SoundDeviceDetector.SoundDevice
    @State private var isExpanded: Bool = false

    private var icon: String {
        switch device.type {
        case .alliteration: return "textformat.abc"
        case .assonance: return "a.circle"
        case .consonance: return "c.circle"
        case .internalRhyme: return "arrow.left.arrow.right"
        case .sibilance: return "s.circle"
        case .onomatopoeia: return "speaker.wave.2"
        }
    }

    private var color: Color {
        switch device.type {
        case .alliteration: return .blue
        case .assonance: return .purple
        case .consonance: return .green
        case .internalRhyme: return .orange
        case .sibilance: return .pink
        case .onomatopoeia: return .red
        }
    }

    private var description: String {
        switch device.type {
        case .alliteration: return "Repetition of initial consonant sounds"
        case .assonance: return "Repetition of vowel sounds"
        case .consonance: return "Repetition of consonant sounds (not at start)"
        case .internalRhyme: return "Rhyming words within a line"
        case .sibilance: return "Repetition of 's', 'sh', 'z' sounds"
        case .onomatopoeia: return "Words that imitate sounds"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.type.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("\(device.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(color.opacity(0.2))
                        )

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            if isExpanded && !device.examples.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Examples:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: 6) {
                        ForEach(device.examples, id: \.self) { example in
                            Text(example)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(color.opacity(0.15))
                                )
                        }
                    }
                }
                .padding(.leading, 32)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.05))
        )
    }
}

// MARK: - NSViewRepresentable for AppKit Integration

struct SoundDevicesHostingView: NSViewRepresentable {
    let devices: [SoundDeviceDetector.SoundDevice]

    func makeNSView(context: Context) -> NSHostingView<SoundDevicesView> {
        let view = NSHostingView(rootView: SoundDevicesView(devices: devices))
        return view
    }

    func updateNSView(_ nsView: NSHostingView<SoundDevicesView>, context: Context) {
        nsView.rootView = SoundDevicesView(devices: devices)
    }
}

// MARK: - Preview

#if DEBUG
struct SoundDevicesView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDevices: [SoundDeviceDetector.SoundDevice] = [
            .init(type: .alliteration, examples: ["sweet summer", "wild winds", "bright burning"], count: 5),
            .init(type: .assonance, examples: ["time, light, night", "moon, room, bloom"], count: 8),
            .init(type: .sibilance, examples: ["whisper", "silence", "softness", "hiss"], count: 12),
            .init(type: .onomatopoeia, examples: ["buzz", "whisper", "crash"], count: 3),
        ]

        SoundDevicesView(devices: sampleDevices)
            .frame(width: 400)
            .padding()
    }
}
#endif
