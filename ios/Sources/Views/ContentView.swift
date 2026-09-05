import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var note: NoteItem? = nil

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    modePicker
                    if model.mode == .coins {
                        CoinsCastView()
                    } else {
                        NumbersCastView()
                    }
                    if let result = model.result {
                        ResultView(result: result, note: $note)
                        BaihuaView(result: result)
                        bookmarkChip(result: result)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .overlay(alignment: .bottom) {
            if let note {
                NoteCard(note: note) { self.note = nil }
                    .padding(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if model.showBookmark, let result = model.result {
                BookmarkOverlay(result: result) {
                    withAnimation(Theme.spring) { model.showBookmark = false }
                    HapticManager.shared.impact(.light, intensity: 0.3)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: note)
        .onAppear { HapticManager.shared.prepare() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("易")
                .font(Theme.kai(34))
                .foregroundColor(.paper2)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.cinnabar)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.cinnabarDeep, lineWidth: 2))
                )
                .padding(.top, 14)
            Text("六爻排盤")
                .font(Theme.kai(26))
                .foregroundColor(.ink)
            Rectangle().fill(Color.cinnabar).frame(width: 34, height: 2)
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text("占日")
                        .font(Theme.kai(14))
                        .foregroundColor(.ink2)
                    DatePicker("", selection: $model.castDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: model.castDate) { model.updateDay() }
                    Spacer()
                }
                Text(model.ganzhiText)
                    .font(Theme.song(12.5))
                    .foregroundColor(.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.paper2, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            modeButton("搖錢起卦", .coins)
            modeButton("報數起卦", .numbers)
        }
        .background(Color.paper2, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.line2, lineWidth: 1))
    }

    @Namespace private var modeNS

    private func modeButton(_ title: String, _ m: Mode) -> some View {
        Button {
            HapticManager.shared.selectionChanged()
            withAnimation(Theme.spring) { model.mode = m }
        } label: {
            Text(title)
                .font(Theme.kai(15))
                .foregroundColor(model.mode == m ? .paper2 : .ink2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background {
                    if model.mode == m {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.cinnabar)
                            .matchedGeometryEffect(id: "modeBG", in: modeNS)
                    }
                }
        }
    }

    private func bookmarkChip(result: CastResult) -> some View {
        Button {
            HapticManager.shared.impact(.medium, intensity: 0.6)
            withAnimation(Theme.spring) { model.showBookmark = true }
        } label: {
            HStack(spacing: 10) {
                Text("籤")
                    .font(Theme.kai(11))
                    .foregroundColor(.cinnabar)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.cinnabar, lineWidth: 1.2))
                Text("\(result.hg.name) · \(model.grade?.label ?? "")")
                    .font(Theme.kai(14))
                    .foregroundColor(.ink2)
                Spacer()
                Text("點開籤文書籤")
                    .font(Theme.song(11))
                    .foregroundColor(.ink3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.paper2, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundColor(Color.line2))
        }
    }
}

// MARK: - 註釋卡片（點擊顯示）

struct NoteItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let text: String
}

struct NoteCard: View {
    let note: NoteItem
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.title)
                    .font(Theme.kai(14))
                    .foregroundColor(.cinnabar)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.ink3)
                }
            }
            Text(note.text)
                .font(Theme.song(13))
                .foregroundColor(.ink2)
                .lineSpacing(3)
        }
        .padding(14)
        .background(Color.paper2, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.line2, lineWidth: 1))
        .shadow(color: .ink.opacity(0.18), radius: 10, y: 3)
    }
}

func makeNote(_ title: String, _ text: String) -> NoteItem { NoteItem(title: title, text: text) }