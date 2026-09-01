import SwiftUI
import SideoutEngine

/// Mirrors the watch's new-game options and adds what the watch shouldn't
/// carry (team names). The phone never originates a rally — this screen
/// edits and previews `GameSettings` and moves to the Scoreboard, but
/// actual play is always started from the watch; there is no
/// phone-to-watch control channel in this app, by design (see the
/// handoff's state-management section: the watch alone decides).
struct SetupView: View {
    @EnvironmentObject private var appModel: PhoneAppModel
    @EnvironmentObject private var connectivity: PhoneConnectivityManager
    @State private var draft: GameSettings = SettingsStore.load()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("New game")
                    .font(PType.largeTitle)
                    .tracking(-0.6)
                    .foregroundStyle(.white)
                    .padding(.bottom, 20)

                startCard
                    .padding(.bottom, 26)

                sectionHeader("FORMAT")
                GroupCard {
                    segmentedRow("Scoring", selection: Binding(
                        get: { draft.format == .sideOut ? 0 : 1 },
                        set: { draft.format = $0 == 0 ? .sideOut : .rally }
                    ), options: ["Side-out", "Rally"])
                    rowDivider
                    segmentedRow("Players", selection: Binding(
                        get: { draft.players == .singles ? 0 : 1 },
                        set: { draft.players = $0 == 0 ? .singles : .doubles }
                    ), options: ["Singles", "Doubles"])
                    rowDivider
                    segmentedRow("Points to win", selection: Binding(
                        get: { [11, 15, 21].firstIndex(of: draft.pointsToWin) ?? 0 },
                        set: { draft.pointsToWin = [11, 15, 21][$0] }
                    ), options: ["11", "15", "21"])
                    rowDivider
                    toggleRow("Hard cap at \(draft.pointsToWin + 4)", isOn: Binding(
                        get: { draft.hardCap != nil },
                        set: { draft.hardCap = $0 ? draft.pointsToWin + 4 : nil }
                    ))
                    rowDivider
                    segmentedRow("First serve", selection: Binding(
                        get: { draft.firstServer == .a ? 0 : 1 },
                        set: { draft.firstServer = $0 == 0 ? .a : .b }
                    ), options: ["Us", "Them"])
                }
                .padding(.bottom, 26)

                sectionHeader("TEAMS")
                GroupCard {
                    textRow("Our name", text: Binding(
                        get: { draft.teamNames[.a] ?? "Us" },
                        set: { draft.teamNames[.a] = $0 }
                    ))
                    rowDivider
                    textRow("Their name", text: Binding(
                        get: { draft.teamNames[.b] ?? "Them" },
                        set: { draft.teamNames[.b] = $0 }
                    ))
                }
                .padding(.bottom, 26)

                Button {
                    SettingsStore.save(draft)
                    appModel.startWatchingScoreboard()
                } label: {
                    Text("Start game")
                        .font(PType.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: PMetric.cardRadius).fill(PColor.card))
                }

                Text(connectionStatusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PColor.meta)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
            .padding(.horizontal, PMetric.listMargin)
            .padding(.top, 58)
        }
        .background(PColor.bgApp.ignoresSafeArea())
    }

    private var connectionStatusText: String {
        let output = appModel.appSettings.audioOutputName ?? "phone speaker"
        return connectivity.currentState != nil ? "Watch connected · \(output)" : "Watch not connected"
    }

    private var startCard: some View {
        Button {
            SettingsStore.save(draft)
            appModel.startWatchingScoreboard()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start — same as last time")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                Text(draft.summary)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(RoundedRectangle(cornerRadius: PMetric.cardRadius).fill(PColor.serve))
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(PType.sectionHeader)
            .tracking(0.6)
            .foregroundStyle(PColor.secondary)
            .padding(.top, 26)
            .padding(.bottom, 8)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color(hex: 0x2C2C2E))
            .frame(height: 1)
            .padding(.leading, 16)
    }

    private func segmentedRow(_ label: String, selection: Binding<Int>, options: [String]) -> some View {
        HStack {
            Text(label).font(PType.rowLabel).foregroundStyle(.white)
            Spacer()
            SegmentedControl(selection: selection, options: options)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label).font(PType.rowLabel).foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(PColor.serve)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func textRow(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).font(PType.rowLabel).foregroundStyle(.white)
            Spacer()
            TextField("", text: text)
                .font(.system(size: 17))
                .foregroundStyle(PColor.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct GroupCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: PMetric.groupRadius).fill(PColor.card))
    }
}

struct SegmentedControl: View {
    @Binding var selection: Int
    let options: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                Text(options[index])
                    .font(PType.segment)
                    .foregroundStyle(index == selection ? .black : PColor.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: PMetric.pillRadius)
                            .fill(index == selection ? Color.white : Color.clear)
                    )
                    .onTapGesture { selection = index }
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: PMetric.segmentTrackRadius).fill(PColor.control))
    }
}
