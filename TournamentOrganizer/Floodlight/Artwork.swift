import SwiftUI
import UIKit

enum Artwork: String {
    case floodlights = "hero_floodlights"
    case centreSpot = "empty_pitch"
    case benchWhistle = "empty_whistle"
    case goldenBoot = "golden_boot"
    case cleanCards = "empty_cards"
    case trophy = "trophy_cup"
    case trophyShelf = "hall_shelf"
    case drawBowl = "draw_bowl"
    case posterBand = "poster_banner"

    var emoji: String {
        switch self {
        case .floodlights: return "🏟️"
        case .centreSpot: return "⚽️"
        case .benchWhistle: return "📣"
        case .goldenBoot: return "👟"
        case .cleanCards: return "🟨"
        case .trophy: return "🏆"
        case .trophyShelf: return "🏅"
        case .drawBowl: return "🎱"
        case .posterBand: return "🏟️"
        }
    }

    var image: UIImage? { UIImage(named: rawValue) }
}

struct Art: View {
    let art: Artwork
    var height: CGFloat = 140
    var medallion = false

    var body: some View {
        if let ui = art.image, medallion {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: height, height: height)
                .clipShape(Circle())
                .overlay(Circle().stroke(Turf.chalk.opacity(0.25), lineWidth: 1))
        } else if let ui = art.image {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .frame(height: height)
        } else {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Turf.stripe, Turf.pitch.opacity(0)], center: .center, startRadius: 4, endRadius: height * 0.55))
                Text(art.emoji)
                    .font(.system(size: height * 0.42))
            }
            .frame(width: height, height: height)
        }
    }
}

struct ArtBand: View {
    let art: Artwork
    var height: CGFloat = 150
    var emblem = true

    var body: some View {
        ZStack {
            if let ui = art.image {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [Turf.stripe, Turf.night], startPoint: .top, endPoint: .bottom)
                HStack(spacing: 46) {
                    ForEach(0..<3, id: \.self) { i in
                        Ellipse()
                            .fill(Turf.floodlight.opacity(i == 1 ? 0.5 : 0.32))
                            .frame(width: 90, height: 34)
                            .blur(radius: 18)
                    }
                }
                .offset(y: -height * 0.28)
                if emblem {
                    Text(art.emoji)
                        .font(.system(size: height * 0.32))
                        .offset(y: height * 0.12)
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

enum TabGlyph: String {
    case fixtures = "tab_fixtures"
    case table = "tab_table"
    case whistle = "tab_whistle"
    case leaders = "tab_leaders"
    case desk = "tab_desk"

    var symbol: String {
        switch self {
        case .fixtures: return "calendar.day.timeline.left"
        case .table: return "list.number"
        case .whistle: return "stopwatch"
        case .leaders: return "soccerball"
        case .desk: return "clipboard"
        }
    }

    var image: Image {
        if let ui = UIImage(named: rawValue) {
            return Image(uiImage: ui.withRenderingMode(.alwaysTemplate))
        }
        return Image(systemName: symbol)
    }
}
