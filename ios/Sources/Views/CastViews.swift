import SwiftUI

// MARK: - 搖錢起卦

struct CoinsCastView: View {
    @EnvironmentObject private var model: AppModel
    @State private var spin = 0.0

    var body: some View {
        CardView(seal: "起卦", title: "搖錢問事") {
            HStack(spacing: 26) {
                ForEach(0..<3, id: \.self) { i in
                    CoinView(face: model.lines.last.map { $0.coins[i] ? "背" : "字" } ?? "背",
                             spinDegrees: spin)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .onChange(of: model.lines.count) {
                withAnimation(Theme.spring) {
                    spin = (spin.truncatingRemainder(dividingBy: 360)) + 360
                }
            }

            Text("三背 ○ 老陽 · 二背 — 少陽 · 一背 - - 少陰 · 無背 × 老陰")
                .font(Theme.song(12))
                .foregroundColor(.ink3)
                .multilineTextAlignment(.center)

            Button {
                Task { await model.startCasting() }
            } label: {
                Text(model.casting ? "擲卦中…" : "擲銅錢")
                    .font(Theme.kai(16))
                    .foregroundColor(.paper2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cinnabar, in: RoundedRectangle(cornerRadius: 4))
            }
            .disabled(model.casting || model.lines.count >= 6)

            if !model.lines.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(model.lines.enumerated().reversed()), id: \.offset) { i, toss in
                        LineRowView(index: i + 1, toss: toss, animate: i == model.lines.count - 1, delay: Double(model.lines.count - 1 - i) * 0.08)
                    }
                }
                .animation(Theme.spring, value: model.lines.count)

                HStack(spacing: 12) {
                    Button("退一爻") { model.undo() }
                        .miniButtonStyle()
                    Button("重新起卦") { model.reset() }
                        .miniButtonStyle()
                }
                .padding(.top, 10)
            }
        }
    }
}

struct CoinView: View {
    let face: String
    let spinDegrees: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xECD089), Color(hex: 0xCFA252), Color(hex: 0xAD833A)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().stroke(Color(hex: 0x8A6626), lineWidth: 1.5))
            Circle().stroke(Color(hex: 0x8A6626).opacity(0.5), lineWidth: 1).padding(4)
            Text(face)
                .font(Theme.kai(15))
                .foregroundColor(Color(hex: 0x4A3508))
        }
        .frame(width: 56, height: 56)
        .rotation3DEffect(.degrees(spinDegrees), axis: (x: 1, y: 0, z: 0))
        .shadow(color: .ink.opacity(0.15), radius: 3, y: 2)
    }
}

struct LineRowView: View {
    let index: Int
    let toss: CoinToss
    let animate: Bool
    let delay: Double

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 14) {
            Text("\(index)")
                .font(Theme.song(12))
                .foregroundColor(.ink3)
                .frame(width: 18)
            HexBars(symbol: toss.symbol, moving: toss.moving, grow: animate)
            Spacer()
        }
        .padding(.vertical, 7)
        .background(Rectangle().fill(Color.clear))
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color.line.opacity(0.6)), alignment: .bottom)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(x: appeared ? 1 : 0.85, y: appeared ? 1 : 0.85)
        .onAppear {
            if animate {
                withAnimation(Theme.spring.delay(delay)) { appeared = true }
            } else {
                appeared = true
            }
        }
        .onChange(of: animate) { _, new in
            if new {
                withAnimation(Theme.spring.delay(delay)) { appeared = true }
            }
        }
    }
}

// MARK: - 報數起卦

struct NumbersCastView: View {
    @EnvironmentObject private var model: AppModel
    @State private var a = ""
    @State private var b = ""
    @State private var c = ""

    var body: some View {
        CardView(seal: "報數", title: "三數起卦") {
            HStack(spacing: 10) {
                numField("一數（上卦）", $a)
                numField("二數（下卦）", $b)
                numField("三數（動爻）", $c)
            }
            Button {
                model.castNumbers(Int(a) ?? 0, Int(b) ?? 0, Int(c) ?? 0)
            } label: {
                Text("起卦")
                    .font(Theme.kai(16))
                    .foregroundColor(.paper2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cinnabar, in: RoundedRectangle(cornerRadius: 4))
            }
            if !model.numError.isEmpty {
                Text(model.numError)
                    .font(Theme.song(13))
                    .foregroundColor(.cinnabar)
            }
            Text("一數除 8 取餘得上卦，二數除 8 取餘得下卦（1 乾、2 兌、3 離、4 震、5 巽、6 坎、7 艮、8 坤，餘 0 為 8）；三數除 6 取餘得動爻（餘 0 為 6）")
                .font(Theme.song(12))
                .foregroundColor(.ink3)
                .lineSpacing(3)
        }
    }

    private func numField(_ label: String, _ text: Binding<String>) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(Theme.song(12.5))
                .foregroundColor(.ink2)
            TextField("", text: text)
                .keyboardType(.numberPad)
                .font(Theme.kai(16))
                .foregroundColor(.ink)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .background(Color.paper3, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.line2, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 通用卡片

struct CardView<Content: View>: View {
    let seal: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                SealTag(text: seal)
                Text(title)
                    .font(Theme.kai(17))
                    .foregroundColor(.ink)
            }
            content
        }
        .padding(16)
        .background(Color.paper2, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.line2, lineWidth: 1))
    }
}

// MARK: - 卦畫

struct HexBars: View {
    let symbol: String
    let moving: Bool
    let grow: Bool

    var body: some View {
        HStack(spacing: 6) {
            if symbol == "—" || symbol == "○" {
                bar(46)
            } else {
                bar(19)
                bar(19)
            }
            if moving {
                Text(symbol)
                    .font(Theme.kai(13))
                    .foregroundColor(.cinnabar)
            }
        }
        .frame(minHeight: 16, alignment: .leading)
        .scaleEffect(x: grow ? 0 : 1, y: 1, anchor: .leading)
        .animation(.easeOut(duration: 0.35), value: grow)
    }

    private func bar(_ width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(moving ? Color.cinnabar : Color.ink)
            .frame(width: width, height: 10)
    }
}