import SwiftUI

struct MessageBubbleShape: Shape {
    let isMine: Bool
    let position: MessageGroupPosition

    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = position.hasTail ? 6 : 0
        let body = CGRect(x: isMine ? rect.minX : rect.minX + tail, y: rect.minY,
            width: max(0, rect.width - tail), height: rect.height)
        var path = Path(roundedRect: body, cornerRadius: min(19, rect.height / 2))
        if position.hasTail {
            let edge = isMine ? body.maxX : body.minX
            let sign: CGFloat = isMine ? 1 : -1
            path.move(to: CGPoint(x: edge - sign * 13, y: rect.maxY - 1))
            path.addQuadCurve(to: CGPoint(x: edge + sign * 6, y: rect.maxY),
                control: CGPoint(x: edge, y: rect.maxY + 1))
            path.addQuadCurve(to: CGPoint(x: edge, y: rect.maxY - 15),
                control: CGPoint(x: edge - sign * 2, y: rect.maxY - 4))
            path.closeSubpath()
        }
        return path
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
            .padding(isMine ? .trailing : .leading, position.hasTail ? 6 : 0)
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
