import SwiftUI
import SideoutEngine

struct SettingsView: View {
    @EnvironmentObject private var appModel: PhoneAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Settings")
                        .font(PType.largeTitle)
                        .tracking(-0.6)
                        .foregroundStyle(.white)
                    Spacer()
                    // The only path here is a long press on the
                    // scoreboard, so Done always returns to it — there's
                    // no other screen a "back" here could mean.
                    Button("Done") {
                        appModel.screen = .scoreboard
                    }
                    .font(PType.button)
                    .foregroundStyle(PColor.serve)
                }

                // Not part of the original brief's flow, added after
                // testing surfaced it: without this there was no way
                // back to Setup at all once you'd left it — a dead end
                // especially before any real game is syncing from the
                // watch. Styled as a real navigation row (not plain
                // caption text, which read as inert on a first pass) so
                // it's discoverable, but in its own card below Done so it
                // stays visually secondary — Done is the common mid-game
                // case (glance at settings, get back to the board), this
                // is the rarer "start over" case. Safe mid-game too — the
                // watch ignores pushed settings while a game is already
                // in progress (see GameSessionController.applyReceivedSettings).
                GroupCard {
                    Button {
                        appModel.screen = .setup
                    } label: {
                        HStack {
                            Text("Change format & teams")
                                .font(PType.rowLabel)
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PColor.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                .padding(.bottom, 12)

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

                #if DEBUG
                debugSimulationSection
                #endif
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

    #if DEBUG
    /// Debug-only: feeds fake watch updates through the real
    /// PhoneConnectivityManager.apply(_:) path, so the phone's whole
    /// reaction pipeline can be verified on real hardware without a
    /// physical watch — see PhoneConnectivityManager.simulateRally.
    private var debugSimulationSection: some View {
        Group {
            sectionHeader("DEBUG — SIMULATE WATCH")
            GroupCard {
                Button {
                    appModel.connectivity.simulateRally(wonBy: .a, settings: SettingsStore.load())
                } label: {
                    row("Simulate: Us won rally") {
                        Image(systemName: "chevron.right").foregroundStyle(PColor.secondary)
                    }
                }
                divider
                Button {
                    appModel.connectivity.simulateRally(wonBy: .b, settings: SettingsStore.load())
                } label: {
                    row("Simulate: Them won rally") {
                        Image(systemName: "chevron.right").foregroundStyle(PColor.secondary)
                    }
                }
                divider
                Button {
                    appModel.connectivity.resetDebugSimulation()
                } label: {
                    row("Reset simulated game") {
                        EmptyView()
                    }
                }
            }
            Text("Debug builds only — never ships. Exercises the exact code path a real watch message would, without needing one.")
                .font(.system(size: 12))
                .foregroundStyle(PColor.secondary)
                .padding(.top, 8)
        }
    }
    #endif

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
