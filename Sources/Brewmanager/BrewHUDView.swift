import SwiftUI
import DroppyKit

struct BrewHUDView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: DroppySpacing.sm) {
            Image(systemName: "shippingbox.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            
            Spacer(minLength: 0)
            
            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, DroppySpacing.md)
        .padding(.vertical, DroppySpacing.md)
    }
}
