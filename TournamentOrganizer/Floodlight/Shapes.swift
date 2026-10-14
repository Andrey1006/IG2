import SwiftUI

struct CornerFlag: Shape {
    var radius: CGFloat = 20
    var notch: CGFloat = 26

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.height / 2, rect.width / 2)
        let n = min(notch, rect.height / 2, rect.width / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - n, y: rect.minY))
        p.addArc(
            center: CGPoint(x: rect.maxX, y: rect.minY),
            radius: n,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: r)
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: r)
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: r)
        p.closeSubpath()
        return p
    }
}

struct Ticket: Shape {
    var stub: CGFloat = 64
    var bite: CGFloat = 7
    var radius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let x = rect.minX + stub
        let r = radius
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: x - bite, y: rect.minY))
        p.addArc(center: CGPoint(x: x, y: rect.minY), radius: bite, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: r)
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: r)
        p.addLine(to: CGPoint(x: x + bite, y: rect.maxY))
        p.addArc(center: CGPoint(x: x, y: rect.maxY), radius: bite, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: r)
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: r)
        p.closeSubpath()
        return p
    }
}

struct Perforation: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY + 10))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 10))
        return p
    }
}

struct Pennant: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.22))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

extension View {
    func flagCard(_ fill: Color = Turf.pitch, radius: CGFloat = 20, notch: CGFloat = 26) -> some View {
        background(
            CornerFlag(radius: radius, notch: notch)
                .fill(fill)
                .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
        )
        .overlay(
            CornerFlag(radius: radius, notch: notch)
                .stroke(Turf.chalk.opacity(0.07), lineWidth: 1)
        )
    }
}
