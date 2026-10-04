import SwiftUI

struct MessageBubbleShape: Shape {
    let isMine: Bool
    let position: MessageGroupPosition

    func path(in rect: CGRect) -> Path {
        let radius = min(19, rect.height / 2)
        let right = rect.maxX - 6
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: right - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: right, y: rect.minY + radius),
            control: CGPoint(x: right, y: rect.minY))
        if position.hasTail {
            path.addLine(to: CGPoint(x: right, y: rect.maxY - radius))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                control1: CGPoint(x: right, y: rect.maxY - 5),
                control2: CGPoint(x: right + 1, y: rect.maxY - 2))
            path.addQuadCurve(to: CGPoint(x: right - 12, y: rect.maxY - 2),
                control: CGPoint(x: right - 2, y: rect.maxY + 1))
            path.addQuadCurve(to: CGPoint(x: right - radius, y: rect.maxY),
                control: CGPoint(x: right - 15, y: rect.maxY))
        } else {
            path.addLine(to: CGPoint(x: right, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: right - radius, y: rect.maxY),
                control: CGPoint(x: right, y: rect.maxY))
        }
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return isMine ? path : path.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1,
            tx: rect.minX + rect.maxX, ty: 0))
    }
}

struct MessageBubble: View {
    let text: String
    let emotionURLs: [String: String]
    let isMine: Bool
    let position: MessageGroupPosition
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        PrivateMessageText(text: text, emotionURLs: emotionURLs)
            .font(.body)
            .foregroundStyle(isMine ? .white : .primary)
            .padding(.horizontal, 15).padding(.vertical, 9)
            .padding(isMine ? .trailing : .leading, 6)
            .background(isMine ? Color(contrast == .increased ? .systemIndigo : .systemBlue) : Color(.secondarySystemBackground),
                in: MessageBubbleShape(isMine: isMine, position: position))
    }
}

struct MessageTimestampView: View {
    let date: Date
    private var dayLabel: String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.year().month().day())
    }
    var body: some View {
        HStack(spacing: 4) {
            Text(dayLabel)
            Text(date, style: .time)
        }
        .font(.caption).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity).padding(.top, 16).padding(.bottom, 10)
        .accessibilityElement(children: .combine)
    }
}

struct MessageDeliveryStatusView: View {
    let state: MessageDeliveryState
    var body: some View {
        Text(state.rawValue).font(.caption2)
            .foregroundStyle(state == .failed ? Color.red : Color.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 8).padding(.top, 3)
            .accessibilityIdentifier("conversation.delivery")
    }
}
