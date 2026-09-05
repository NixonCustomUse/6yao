import SwiftUI

struct BookmarkOverlay: View {
    let result: CastResult
    let onDismiss: () -> Void

    @State private var showCard = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            ScrollView {
                BookmarkCard(result: result)
                    .padding(.vertical, 40)
            }
            .overlay(alignment: .topTrailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.ink3)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Color.line2, lineWidth: 1))
                        .background(Color.paper, in: Circle())
                }
                .padding(.trailing, 18)
                .padding(.top, 14)
            }
        }
        .scaleEffect(showCard ? 1 : 0.92)
        .opacity(showCard ? 1 : 0)
        .onAppear {
            withAnimation(Theme.spring) { showCard = true }
        }
    }
}

struct BookmarkCard: View {
    @EnvironmentObject private var model: AppModel
    let result: CastResult

    var body: some View {
        let rs = readingSections(c: result, movingSymbols: model.movingSymbols, data: model.data)
        let grade = model.grade
        return VStack(spacing: 0) {
            Circle()
                .fill(Color.paper3)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(Color.line2, lineWidth: 1))
            Rectangle()
                .fill(LinearGradient(colors: [.gold, .cinnabar], startPoint: .top, endPoint: .bottom))
                .frame(width: 1.5, height: 46)
            Text(result.hg.name)
                .font(Theme.kai(34))
                .foregroundColor(.ink)
                .padding(.top, 8)
            Text(grade?.label ?? "")
                .font(Theme.kai(13))
                .foregroundColor(.cinnabar)
                .tracking(4)
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.cinnabar, lineWidth: 1.5))
                .padding(.top, 8)

            bars(bits: result.hg.bits)
                .padding(.vertical, 14)

            VStack(spacing: 3) {
                ForEach(rs.bookmarkQuote, id: \.self) { q in
                    Text(q)
                        .font(Theme.kai(12.5))
                        .foregroundColor(.ink2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 9)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.line), alignment: .top)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.line), alignment: .bottom)

            Text(rs.bookmarkBai.joined(separator: "\n"))
                .font(Theme.song(11))
                .foregroundColor(.ink3)
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            Text("六爻排盤")
                .font(Theme.song(10))
                .tracking(4)
                .foregroundColor(.ink3)
                .padding(.top, 14)
        }
        .frame(width: 236)
        .padding(.vertical, 26)
        .padding(.horizontal, 22)
        .background(Color.paper2, in: RoundedRectangle(cornerRadius: 2))
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.line, lineWidth: 1))
        .shadow(color: .ink.opacity(0.22), radius: 14, y: 5)
    }

    private func bars(bits: [Int]) -> some View {
        VStack(spacing: 4) {
            ForEach(Array(bits.enumerated().reversed()), id: \.offset) { _, bit in
                HStack(spacing: 6) {
                    if bit == 1 {
                        RoundedRectangle(cornerRadius: 1).fill(Color.ink).frame(width: 46, height: 5)
                    } else {
                        RoundedRectangle(cornerRadius: 1).fill(Color.ink).frame(width: 19, height: 5)
                        RoundedRectangle(cornerRadius: 1).fill(Color.ink).frame(width: 19, height: 5)
                    }
                }
            }
        }
    }
}

