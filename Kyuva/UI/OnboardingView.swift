import SwiftUI

/// Onboarding wizard shown on first launch
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    private let totalPages = 3
    
    var body: some View {
        VStack(spacing: 0) {
            // Content - manual page switching
            Group {
                switch currentPage {
                case 0:
                    WelcomePage()
                case 1:
                    FeaturesPage()
                case 2:
                    GettingStartedPage()
                default:
                    WelcomePage()
                }
            }
            .frame(maxHeight: .infinity)
            
            // Navigation
            HStack {
                if currentPage > 0 {
                    Button(action: { currentPage -= 1 }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                } else {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")
                .accessibilityAddTraits(.isStaticText)
                
                Spacer()
                
                if currentPage < totalPages - 1 {
                    Button(action: { currentPage += 1 }) {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { completeOnboarding() }) {
                        HStack {
                            Text("Get Started")
                            Image(systemName: "arrow.right")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
        }
        .frame(width: 650, height: 580)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        isPresented = false
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Icon
            Image(systemName: "text.alignleft")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
                .padding()
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                )
            
            Text("Welcome to Kyuva")
                .font(.largeTitle.bold())
            
            Text("Your camera-side teleprompter")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Kyuva displays your notes right next to your camera —")
                Text("so you can read while maintaining natural eye contact")
                Text("during video calls and presentations.")
            }
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            
            HStack(spacing: 12) {
                Image(systemName: "arrow.up")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
                    .padding(12)
                    .background(Circle().fill(Color.accentColor.opacity(0.15)))
                
                VStack(alignment: .leading) {
                    Text("Look up at your screen")
                        .font(.headline)
                    Text("The prompter appears near your camera")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Features Page

struct FeaturesPage: View {
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: "eye")
                .font(.system(size: 40))
                .foregroundColor(.green)
                .accessibilityHidden(true)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 70, height: 70)
                )
            
            Text("Your Camera-Side Teleprompter")
                .font(.title2.bold())
            
            Text("Keep your notes close while you speak")
                .font(.callout)
                .foregroundColor(.secondary)
            
            // Feature grid - more compact
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                FeatureCard(
                    icon: "person.fill",
                    iconColor: .blue,
                    title: "Natural Eye Contact",
                    description: "Text appears next to your camera"
                )
                
                FeatureCard(
                    icon: "rectangle.on.rectangle",
                    iconColor: .orange,
                    title: "Capture Visibility",
                    description: "May appear in screen shares or recordings; verify the preview or share a single app window that omits Kyuva"
                )
                
                FeatureCard(
                    icon: "text.alignleft",
                    iconColor: .purple,
                    title: "Auto-Scrolling",
                    description: "Focus on speaking, not scrolling"
                )
                
                FeatureCard(
                    icon: "macwindow.on.rectangle",
                    iconColor: .cyan,
                    title: "Always on Top",
                    description: "Visible above all windows"
                )
            }
            .padding(.horizontal, 20)
        }
        .padding()
    }
}

struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .accessibilityHidden(true)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(iconColor.opacity(0.15)))
            
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
}

// MARK: - Getting Started Page

struct GettingStartedPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Icon
            Image(systemName: "gearshape.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .accessibilityHidden(true)
                .padding()
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 100, height: 100)
                )
            
            Text("Getting Started")
                .font(.title.bold())
            
            Text("How to use Kyuva")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                StepRow(number: 1, title: "Add your notes", description: "Open Settings from the menu bar to write or import a script")
                StepRow(number: 2, title: "Place the overlay", description: "Drag or resize the camera-side overlay so it fits your setup")
                StepRow(number: 3, title: "Control the scroll", description: "Use the overlay controls, scroll manually, or use the fixed global shortcuts")
                StepRow(number: 4, title: "Verify your share", description: "Check the meeting preview, then use Hide Teleprompter from the menu bar when finished")
            }
            .padding(.horizontal, 50)
            
            Spacer()
        }
        .padding()
    }
}

struct StepRow: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
