import SwiftUI
import DroppyKit

struct BrewHUDView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: DroppySpacing.sm) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
            
            Spacer(minLength: 0)
            
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, DroppySpacing.md)
        .padding(.vertical, DroppySpacing.xs)
    }
}
