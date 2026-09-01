import SwiftUI
import SideoutEngine

struct SettingsView: View {
    @EnvironmentObject private var appModel: PhoneAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(PType.largeTitle)
                    .tracking(-0.6)
                    .foregroundStyle(.white)

                sectionHeader("VOICE")
                GroupCard {
                    row("Voice") { Text(appModel.appSettings.voiceName).foregroundStyle(PColor.secondary) }
                    divider
                    volumeRow
                    divider
                    Button {
                        appModel.announcer.speak(previewClips)
                    } label: {
                        row("Test callout") {
                            Text("Play").font(.system(size: 17, weight: .semibold)).foregroundStyle(PColor.serve)
                        }
                    }
                }

                sectionHeader("ANNOUNCE")
                GroupCard {
                    announceModeRow(.everyRally)
                    divider
                    announceModeRow(.scoreChangesAndSideOutsOnly)
                    divider
                    toggleRow("Announce game point", isOn: Binding(
                        get: { appModel.appSettings.announceGamePoint },
                        set: { appModel.appSettings.announceGamePoint = $0 }
                    ))
                }

                sectionHeader("AUDIO OUTPUT")
                GroupCard {
                    row("Output") {
                        Text(appModel.appSettings.audioOutputName ?? "None").foregroundStyle(PColor.secondary)
                    }
                }
                if appModel.appSettings.audioOutputName == nil {
                    noSpeakerNote
                }

                sectionHeader("SCOREBOARD")
                GroupCard {
                    toggleRow("Keep screen awake", isOn: Binding(
                        get: { appModel.appSettings.keepScreenAwake },
                        set: { appModel.appSettings.keepScreenAwake = $0 }
                    ))
                    divider
                    row("Announce missed rallies on reconnect") {
                        Text(appModel.appSettings.reconnectBehavior.label).foregroundStyle(PColor.secondary)
                    }
                    .onTapGesture {
                        appModel.appSettings.reconnectBehavior = appModel.appSettings.reconnectBehavior == .latestOnly ? .nothing : .latestOnly
                    }
                }
            }
            .padding(.horizontal, PMetric.listMargin)
            .padding(.top, 58)
        }
        .background(PColor.bgApp.ignoresSafeArea())
    }

    private var previewClips: [SpokenClip] { [.number(5), .number(3), .number(2)] }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(PType.sectionHeader)
            .tracking(0.6)
            .foregroundStyle(PColor.secondary)
            .padding(.top, 18)
            .padding(.bottom, 7)
    }

    private var divider: some View {
        Rectangle().fill(Color(hex: 0x2C2C2E)).frame(height: 1).padding(.leading, 16)
    }

    private func row(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        HStack {
            Text(label).font(PType.rowLabel).foregroundStyle(.white)
            Spacer()
            value()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        row(label) {
            Toggle("", isOn: isOn).labelsHidden().tint(PColor.serve)
        }
    }

    private func announceModeRow(_ mode: AnnounceMode) -> some View {
        Button {
            appModel.appSettings.announceMode = mode
        } label: {
            row(mode.label) {
                if appModel.appSettings.announceMode == mode {
                    Image(systemName: "checkmark").foregroundStyle(PColor.serve)
                }
            }
        }
    }

    private var volumeRow: some View {
        HStack {
            Text("Volume").font(PType.rowLabel).foregroundStyle(.white)
            Spacer()
            Slider(value: Binding(
                get: { appModel.appSettings.volume },
                set: { appModel.appSettings.volume = $0 }
            ), in: 0...1)
            .frame(width: 120)
            .tint(.white)
            Text("\(Int(appModel.appSettings.volume * 100))%")
                .foregroundStyle(PColor.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var noSpeakerNote: some View {
        Text("No Bluetooth speaker. Callouts will play through the phone.")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(PColor.warnFg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(RoundedRectangle(cornerRadius: 12).fill(PColor.warnBg))
            .padding(.top, 12)
    }
}
