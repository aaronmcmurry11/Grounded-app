import SwiftUI

/// The profile avatar: the existing Tier A leaf mark on one of the four category washes
/// already used by the shelves. No photo upload, no new assets, no new colors — the mark
/// sits at full opacity because it's on a category fill rather than neutral dark.
struct AvatarMark: View {
    let washHex: String
    var diameter: CGFloat = 58
    var isSelected: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.categoryColor(washHex))
            BotanicalSprig(lineWidth: max(0.9, diameter / 56))
                .frame(width: diameter * 0.40, height: diameter * 0.56)
        }
        .frame(width: diameter, height: diameter)
        .overlay {
            Circle()
                .strokeBorder(
                    isSelected ? Theme.cream : Theme.cream.opacity(0.14),
                    lineWidth: isSelected ? 2 : 1
                )
        }
    }
}
