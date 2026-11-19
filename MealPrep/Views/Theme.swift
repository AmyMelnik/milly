import CoreText
import SwiftUI

/// Minimal, warm-white look. Colour comes from the ingredient illustrations;
/// the UI itself stays quiet: hairlines, black buttons, Gambetta titles, Open Sans text.
enum Theme {
    static let background = Color(hex: 0xFBFAF7)
    /// Warmer cream for the landing screen, so white products (milk, mayo) stand out.
    static let cream = Color(hex: 0xF3EBDD)
    static let surface = Color.white
    static let subtle = Color(hex: 0xF4F1EB)
    static let line = Color(hex: 0xE7E3DC)
    static let ink = Color(hex: 0x1D1C1A)
    static let secondary = Color(hex: 0x6E6A64)
    static let tertiary = Color(hex: 0xA29E97)
    static let accent = Color(hex: 0xC4552D)   // terracotta, used sparingly
    static let success = Color(hex: 0x3F7A52)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Type

enum AppFonts {
    /// Gambetta (Fontshare) for big titles and numbers.
    static let titleName = "Gambetta-Regular"

    /// Bundled fonts are registered at launch so `Font.custom` can find them.
    static func register() {
        for (name, ext) in [("OpenSans-Regular", "ttf"), ("OpenSans-SemiBold", "ttf"),
                            ("OpenSans-Bold", "ttf"), ("Gambetta-Regular", "otf")] {
            let url = Bundle.main.url(forResource: name, withExtension: ext)
                ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Fonts")
            if let url { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
        }
    }
}

extension Font {
    /// Display face for big titles and big numbers only.
    static func title(_ size: CGFloat) -> Font {
        .custom(AppFonts.titleName, size: size, relativeTo: .largeTitle)
    }

    /// Open Sans for everything else.
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String = switch weight {
        case .semibold: "OpenSans-SemiBold"
        case .bold, .heavy, .black: "OpenSans-Bold"
        default: "OpenSans-Regular"
        }
        return .custom(name, size: size, relativeTo: .body)
    }
}

extension View {
    /// Gambetta for single-line titles and big numbers.
    func titleFont(_ size: CGFloat) -> some View {
        font(.title(size))
    }
}

extension Theme {
    /// Baseline-to-baseline distance for wrapped titles, as a multiple of the font size.
    /// Gambetta's own line height is 1.3×, which leaves big gaps between lines.
    static let titleLineHeight: CGFloat = 1.04
}

/// A title that can wrap onto several lines, with tight, exact line spacing.
/// SwiftUI's `lineSpacing` can't go below a font's built-in line height, so this uses a UILabel.
struct TitleText: UIViewRepresentable {
    let text: String
    var size: CGFloat
    var alignment: NSTextAlignment = .natural
    var color: Color = Theme.ink

    init(_ text: String, size: CGFloat, alignment: NSTextAlignment = .natural, color: Color = Theme.ink) {
        self.text = text
        self.size = size
        self.alignment = alignment
        self.color = color
    }

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.accessibilityTraits = .header
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let scaled = UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: size)
        let font = UIFont(name: AppFonts.titleName, size: scaled) ?? .systemFont(ofSize: scaled)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = scaled * Theme.titleLineHeight
        paragraph.maximumLineHeight = scaled * Theme.titleLineHeight
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        // Avoid a single word stranded on the last line.
        paragraph.lineBreakStrategy = [.pushOut]
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor(color),
            .paragraphStyle: paragraph,
        ])
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let fit = uiView.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        return CGSize(width: min(ceil(fit.width), maxWidth), height: ceil(fit.height))
    }
}

// MARK: - Surfaces

struct CardStyle: ViewModifier {
    var fill: Color = Theme.surface
    var stroke: Color = Theme.line
    var lineWidth: CGFloat = 1
    var radius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(stroke, lineWidth: lineWidth))
    }
}

extension View {
    func card(_ fill: Color = Theme.surface, stroke: Color = Theme.line, lineWidth: CGFloat = 1, radius: CGFloat = 18) -> some View {
        modifier(CardStyle(fill: fill, stroke: stroke, lineWidth: lineWidth, radius: radius))
    }

    /// Plain warm-white page background.
    func pageBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}

/// Small spaced capitals used for labels and section eyebrows.
struct Eyebrow: View {
    let text: String
    var color: Color = Theme.secondary

    init(_ text: String, color: Color = Theme.secondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.sans(11, .semibold))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

/// Quiet rounded label: "4 portions", "Oven", "35 min".
struct Pill: View {
    let text: String
    var systemImage: String?
    var fill: Color = Theme.subtle
    var foreground: Color = Theme.ink

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 10, weight: .medium)) }
            Text(text).font(.sans(12, .semibold))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(fill, in: Capsule())
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sans(16, .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var foreground: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sans(16, .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct CircleIconButton: View {
    let systemImage: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.36, weight: .regular))
                .foregroundStyle(Theme.ink)
                .frame(width: size, height: size)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Selectable chip for quick picks.
struct Chip: View {
    let text: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.sans(14, selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : Theme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(selected ? Theme.ink : Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? Theme.ink : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

/// Text input with a hairline border.
struct InputField: View {
    let placeholder: String
    @Binding var text: String
    var secure = false
    /// Email addresses, codes, keys: no capitals, no autocorrect, single line.
    var plain = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        Group {
            if secure {
                SecureField(placeholder, text: $text)
            } else if plain {
                TextField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...4)
            }
        }
        .font(.sans(16))
        .foregroundStyle(Theme.ink)
        .keyboardType(keyboard)
        .textInputAutocapitalization(secure || plain ? .never : .sentences)
        .autocorrectionDisabled(secure || plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .card(radius: 14)
    }
}

/// Lays out children left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// One of the ingredient illustrations.
struct Art: View {
    let food: Food
    var size: CGFloat = 44
    var tilt: Double = 0

    var body: some View {
        food.image
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .rotationEffect(.degrees(tilt))
            .accessibilityHidden(true)
    }
}

/// Hairline divider.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.line).frame(height: 1)
    }
}

/// A vertical-only scroll view whose content is pinned to the screen width,
/// so nothing inside can make the page drift or scroll sideways.
struct PageScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.vertical) {
            content
                .containerRelativeFrame(.horizontal, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }
}
