import SwiftUI

// MARK: - 搖錢起卦

struct CoinsCastView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        CardView(seal: "起卦", title: "搖錢問事") {
            TaijiView(isAnimating: model.casting, currentYao: model.taijiYao, tosses: model.lines)

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
            .disabled(model.casting)

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

// MARK: - 太極生爻

struct TaijiView: View {
    let isAnimating: Bool
    let currentYao: Int
    let tosses: [CoinToss]

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let r = min(size.width, size.height) / 2
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let outerRect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                let white = Color(hex: 0xF9F5EA)
                let black = Color(hex: 0x1A1A1E)
                let gold = Color(hex: 0xC99D4F)
                let line2 = Color(hex: 0xC2B495)

                // 底：白底外圓
                ctx.fill(Path(ellipseIn: outerRect), with: .color(white))

                // 左半黑（外圈左半 + 直徑）
                var leftHalf = Path()
                leftHalf.move(to: CGPoint(x: c.x, y: c.y - r))
                leftHalf.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
                leftHalf.closeSubpath()
                ctx.fill(leftHalf, with: .color(black))

                // 上魚眼凸起（黑）與下魚眼凹陷（白）
                let topCenter = CGPoint(x: c.x, y: c.y - r / 2)
                let bottomCenter = CGPoint(x: c.x, y: c.y + r / 2)
                ctx.fill(Path(ellipseIn: CGRect(x: topCenter.x - r / 2, y: topCenter.y - r / 2, width: r, height: r)), with: .color(black))
                ctx.fill(Path(ellipseIn: CGRect(x: bottomCenter.x - r / 2, y: bottomCenter.y - r / 2, width: r, height: r)), with: .color(white))

                // 外圈
                ctx.stroke(Path(ellipseIn: outerRect), with: .color(line2), lineWidth: 1.5)

                // 魚眼
                let eyeOuterR: CGFloat = 6
                let eyeDotR: CGFloat = 2.5
                // 上眼：白底黑邊 + 金點
                ctx.fill(Path(ellipseIn: CGRect(x: topCenter.x - eyeOuterR, y: topCenter.y - eyeOuterR, width: eyeOuterR * 2, height: eyeOuterR * 2)), with: .color(white))
                ctx.stroke(Path(ellipseIn: CGRect(x: topCenter.x - eyeOuterR, y: topCenter.y - eyeOuterR, width: eyeOuterR * 2, height: eyeOuterR * 2)), with: .color(black), lineWidth: 1)
                ctx.fill(Path(ellipseIn: CGRect(x: topCenter.x - eyeDotR, y: topCenter.y - eyeDotR, width: eyeDotR * 2, height: eyeDotR * 2)), with: .color(gold))
                // 下眼：黑底白邊 + 金點
                ctx.fill(Path(ellipseIn: CGRect(x: bottomCenter.x - eyeOuterR, y: bottomCenter.y - eyeOuterR, width: eyeOuterR * 2, height: eyeOuterR * 2)), with: .color(black))
                ctx.stroke(Path(ellipseIn: CGRect(x: bottomCenter.x - eyeOuterR, y: bottomCenter.y - eyeOuterR, width: eyeOuterR * 2, height: eyeOuterR * 2)), with: .color(white), lineWidth: 1)
                ctx.fill(Path(ellipseIn: CGRect(x: bottomCenter.x - eyeDotR, y: bottomCenter.y - eyeDotR, width: eyeDotR * 2, height: eyeDotR * 2)), with: .color(gold))
            }
            .frame(width: 96, height: 96)
            .rotationEffect(.degrees(isAnimating ? 180 : 0))
            .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.8), value: isAnimating)

            VStack(spacing: 4) {
                ForEach((0..<6).reversed(), id: \.self) { i in
                    if i < currentYao, let t = tosses[safe: i] {
                        HexBars(symbol: t.symbol, moving: t.moving, grow: true)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(
            RadialGradient(colors: [Color.ink.opacity(0.06), .clear], center: .center, startRadius: 20, endRadius: 80)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}