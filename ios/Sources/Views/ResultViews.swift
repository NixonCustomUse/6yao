import SwiftUI

// MARK: - 排盤（本卦/變卦 爻行）＋ 卦象解讀

struct ResultView: View {
    @EnvironmentObject private var model: AppModel
    let result: CastResult
    @Binding var note: NoteItem?

    var body: some View {
        CardView(seal: "排盤", title: "卦象解讀") {
            yongshenPicker
            HStack(alignment: .top, spacing: 12) {
                HexColumnView(hg: result.hg, moving: result.moving, symbols: model.movingSymbols,
                              isBen: true, model: model, note: $note)
                if let changed = result.changed {
                    HexColumnView(hg: changed, moving: [], symbols: [:],
                                  isBen: false, model: model, note: $note)
                } else {
                    VStack {
                        Text("無動爻").font(Theme.kai(15)).foregroundColor(.ink3)
                        Text("無變卦").font(Theme.kai(15)).foregroundColor(.ink3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
            }
            readingBlock(result: result, data: model.data)
        }
    }

    private var yongshenPicker: some View {
        HStack(spacing: 8) {
            Text("占問事項")
                .font(Theme.kai(14))
                .foregroundColor(.ink2)
            Picker("用神", selection: $model.yongshen) {
                Text("不限").tag("")
                Text("財運／求財").tag("妻財")
                Text("感情婚姻").tag("妻財")
                Text("事業官運").tag("官鬼")
                Text("健康疾病").tag("官鬼")
                Text("考試學業").tag("父母")
                Text("父母長輩／文書").tag("父母")
                Text("子女晚輩").tag("子孫")
                Text("合夥朋友").tag("兄弟")
                Text("自身平安（看世爻）").tag("世爻")
            }
            .pickerStyle(.menu)
            .tint(.cinnabar)
            Spacer()
        }
    }

    private func readingBlock(result: CastResult, data: YiData) -> some View {
        let rs = readingSections(c: result, movingSymbols: model.movingSymbols, data: data)
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(rs.classical, id: \.title) { sec in
                VStack(alignment: .leading, spacing: 4) {
                    Text(sec.title)
                        .font(Theme.kai(15))
                        .foregroundColor(.ink)
                    ForEach(sec.lines, id: \.self) { line in
                        if line.hasPrefix("卦辭：") {
                            Text(line).kaiText()
                        } else if line.hasPrefix("象曰：") {
                            Text(line).kaiText()
                        } else {
                            Text(line)
                                .font(Theme.song(14))
                                .foregroundColor(.ink2)
                        }
                    }
                }
            }
        }
    }
}

extension Text {
    func kaiText() -> some View {
        self.font(Theme.kai(14.5)).foregroundColor(.ink2)
    }
}

// MARK: - 爻行欄

struct HexColumnView: View {
    let hg: Hexagram
    let moving: [Int]
    let symbols: [Int: String]
    let isBen: Bool
    @ObservedObject var model: AppModel
    @Binding var note: NoteItem?

    private var shen: [String] { sixShen(dayGan: model.dayInfo.dayGan) }
    private var kong: [Int] { xunkongBranches(dayIdx: model.dayInfo.dayIdx) }

    private func yongshenIndex(_ i: Int) -> Bool {
        model.yongshen == "世爻" ? i == hg.shi : hg.liuqin[i] == model.yongshen
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(hg.name)
                    .font(Theme.kai(17))
                    .foregroundColor(.ink)
                    .onTapGesture {
                        note = makeNote("卦名", isBen ? "本卦：起卦所得之卦，代表當前狀態" : "變卦：由動爻變化而成的卦，代表未來發展")
                    }
                Text("\(isBen ? "本卦" : "變卦") · \(hg.palace)宮")
                    .font(Theme.song(11.5))
                    .foregroundColor(.ink3)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.paper3, in: RoundedRectangle(cornerRadius: 4))
            .padding(.bottom, 6)

            ForEach(0..<6, id: \.self) { j in
                let i = 5 - j
                let isMove = moving.contains(i)
                let isYS = yongshenIndex(i)
                let inKong = kong.contains(BRANCH_IDX[hg.branches[i]] ?? -1)
                let mark = isMove && isBen ? (symbols[i] ?? "") : nil
                row(i: i, isMove: isMove, isYS: isYS, inKong: inKong, mark: mark)
            }
        }
        .frame(maxWidth: .infinity)
        .background(isBen ? Color.paper2 : Color.paper2.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.line, lineWidth: 1))
    }

    private func row(i: Int, isMove: Bool, isYS: Bool, inKong: Bool, mark: String?) -> some View {
        HStack(spacing: 6) {
            Text(shen[i])
                .font(Theme.song(12))
                .foregroundColor(.ink2)
                .frame(width: 44, alignment: .center)
                .onTapGesture { note = makeNote(shen[i], SIXSHEN_NOTE[shen[i]] ?? "") }

            Group {
                if i == hg.shi {
                    SealMini(text: "世", filled: true)
                        .onTapGesture { note = makeNote("世", "世：代表所占之事中的自己") }
                } else if i == hg.ying {
                    SealMini(text: "應", filled: false)
                        .onTapGesture { note = makeNote("應", "應：代表對方、所問之事與環境") }
                } else {
                    Text("").frame(width: 20, height: 20)
                }
            }
            .frame(width: 26, alignment: .center)

            HexBars(symbol: hg.bits[i] == 1 ? "—" : "- -", moving: isMove, grow: false)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Text(hg.branches[i])
                        .font(Theme.song(13))
                        .foregroundColor(.ink)
                        .onTapGesture { note = makeNote(hg.branches[i], branchNote(hg.branches[i])) }
                    if inKong {
                        Text("空")
                            .font(Theme.song(10.5))
                            .foregroundColor(.cinnabar)
                            .onTapGesture { note = makeNote("旬空", "旬空：此爻值旬空，主此事暫無著落、虛而不實") }
                    }
                }
                Text(hg.liuqin[i])
                    .font(Theme.song(12))
                    .foregroundColor(isYS ? .cinnabar : .ink2)
                    .onTapGesture { note = makeNote(hg.liuqin[i], LIUQIN_NOTE[hg.liuqin[i]] ?? "") }
            }
            .frame(width: 62, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(isYS ? Color.cinnabarSoft : (isMove ? Color.cinnabar.opacity(0.06) : Color.clear))
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color.line.opacity(0.6)), alignment: .bottom)
    }
}

// MARK: - 白話解讀

struct BaihuaView: View {
    @EnvironmentObject private var model: AppModel
    let result: CastResult

    var body: some View {
        let rs = readingSections(c: result, movingSymbols: model.movingSymbols, data: model.data)
        CardView(seal: "白話", title: "白話解讀") {
            ForEach(rs.vernacular, id: \.title) { sec in
                VStack(alignment: .leading, spacing: 6) {
                    Text(sec.title)
                        .font(Theme.kai(15))
                        .foregroundColor(.ink)
                    ForEach(sec.lines, id: \.self) { line in
                        Text(line)
                            .font(Theme.song(14.5))
                            .foregroundColor(.ink2)
                            .lineSpacing(5)
                    }
                }
            }
        }
    }
}