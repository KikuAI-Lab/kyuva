import SwiftUI

/// View for upgrading to Pro
struct ProUpgradeView: View {
    @ObservedObject var store = StoreManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Close button
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Header
            VStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
                
                Text("Upgrade to Pro")
                    .font(.title.bold())
                
                Text("Unlock all features")
                    .foregroundColor(.secondary)
            }
            
            // Features
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "mic.fill", text: "Voice-Follow Scrolling")
                FeatureRow(icon: "doc.on.doc.fill", text: "Unlimited Scripts")
                FeatureRow(icon: "keyboard", text: "Custom Hotkeys")
                FeatureRow(icon: "arrow.up.circle.fill", text: "Lifetime Updates")
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            // Price & Purchase
            VStack(spacing: 12) {
                if let product = store.proProduct {
                    Text(product.displayPrice)
                        .font(.title2.bold())
                    
                    Text("One-time purchase")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        Task {
                            await store.purchasePro()
                        }
                    }) {
                        HStack {
                            if case .purchasing = store.purchaseState {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            }
                            Text("Purchase Pro")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(store.purchaseState == .purchasing)
                } else {
                    // No products loaded - show message instead of infinite loader
                    Text("App Store not connected")
                        .foregroundColor(.secondary)
                    Text("Pro features will be available after App Store release")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Button("Restore Purchases") {
                    Task {
                        await store.restorePurchases()
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Not now button
                Button("Not now") {
                    dismiss()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Error
            if case .failed(let error) = store.purchaseState {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(24)
        .frame(width: 320, height: 520)
        .onChange(of: store.isPro) { newValue in
            if newValue {
                dismiss()
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
            Spacer()
            Image(systemName: "checkmark")
                .foregroundColor(.green)
        }
    }
}

#Preview {
    ProUpgradeView()
}
