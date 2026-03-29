import SwiftUI

/// Profile/logo button used in the top-left of every tab.
/// Shows the business logo if set, otherwise shows person.circle icon.
struct ProfileButtonView: View {
    let action: () -> Void

    private var logoImage: UIImage? {
        guard let path = PersistenceController.shared.getOrCreateBusinessProfile().logoImagePath,
              !path.isEmpty else { return nil }
        return UIImage(contentsOfFile: path)
    }

    var body: some View {
        Button(action: action) {
            if let logo = logoImage {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "person.circle")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}
