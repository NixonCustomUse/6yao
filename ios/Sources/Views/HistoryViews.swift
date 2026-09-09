import SwiftUI

// MARK: - HistoryPreview（底部常駐，最近 3 筆）

struct HistoryPreview: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        CardView(seal: "史", title: "歷史紀錄") {
            if model.history.isEmpty {
                Text("歷史尚無記錄。起一卦後會自動存檔。")
                    .font(Theme.song(13))
                    .foregroundColor(.ink3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(model.history.prefix(3)) { r in
                        HistoryRow(record: r)
                    }
                }
                if model.history.count > 3 {
                    HStack {
                        Spacer()
                        Button {
                            HapticManager.shared.selectionChanged()
                            model.showHistory = true
                        } label: {
                            Text("查看全部 →")
                                .font(Theme.song(13))
                                .foregroundColor(.cinnabar)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - HistorySheet（完整列表，NavigationView + List）

struct HistorySheet: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationView {
            List {
                if model.history.isEmpty {
                    Text("尚無歷史")
                        .font(Theme.song(14))
                        .foregroundColor(.ink3)
                        .listRowBackground(Color.paper2)
                } else {
                    ForEach(model.history) { r in
                        HistoryRow(record: r)
                            .listRowBackground(Color.paper2)
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    }
                    .onDelete { idx in
                        let ids = idx.map { model.history[$0].id }
                        for id in ids {
                            model.removeHistory(id: id)
                        }
                        HapticManager.shared.impact(.light, intensity: 0.4)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .navigationTitle("歷史紀錄（\(model.history.count)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") {
                        model.showHistory = false
                    }
                    .foregroundColor(.cinnabar)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清空全部", role: .destructive) {
                        model.clearHistory()
                        HapticManager.shared.impact(.medium, intensity: 0.5)
                    }
                    .disabled(model.history.isEmpty)
                }
            }
        }
    }
}

// MARK: - HistoryRow（單筆：左卦名→變卦，右分級徽章 + ×，整列可點還原）

struct HistoryRow: View {
    @EnvironmentObject private var model: AppModel
    let record: HistoryRecord

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(Theme.kai(14))
                    .foregroundColor(.ink)
                    .lineLimit(1)
                Text(subtitleText)
                    .font(Theme.song(11))
                    .foregroundColor(.ink3)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let label = model.gradeForRecord(record)?.label, !label.isEmpty {
                Text(label)
                    .font(Theme.kai(11))
                    .foregroundColor(.cinnabar)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.cinnabar, lineWidth: 1.2))
            }
            Button {
                HapticManager.shared.impact(.light, intensity: 0.4)
                model.removeHistory(id: record.id)
            } label: {
                Text("×")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.ink3)
                    .frame(width: 26, height: 26)
                    .background(Color.paper3, in: Circle())
                    .overlay(Circle().stroke(Color.line2, lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.paper, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.line, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.selectionChanged()
            model.restore(record: record)
            model.showHistory = false
        }
    }

    private var titleText: String {
        if let changed = record.changedName, !changed.isEmpty {
            return "\(record.hgName) → \(changed)"
        }
        return record.hgName
    }

    private var subtitleText: String {
        var parts: [String] = []
        parts.append(record.dateISO)
        if !record.ganzhiText.isEmpty {
            parts.append(record.ganzhiText)
        }
        if !record.yongshen.isEmpty {
            parts.append(record.yongshen)
        }
        return parts.joined(separator: " · ")
    }
}
