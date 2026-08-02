import SwiftUI

struct WelcomeView: View {
    let useEmail: () -> Void
    let useApple: () -> Void
    let useGoogle: () -> Void

    var body: some View {
        ZStack {
            RooBinTheme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: RooBinTheme.Spacing.spacious) {
                    Spacer(minLength: 56)

                    VStack(spacing: RooBinTheme.Spacing.compact) {
                        Image("RooBinBanner")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 360, maxHeight: 220)
                            .accessibilityLabel("RooBin")

                        Text("The digital sin bin for teams")
                            .font(.headline)
                            .foregroundStyle(RooBinTheme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    RooBinCard {
                        VStack(spacing: 12) {
                            Button(action: useApple) {
                                Label("Continue with Apple", systemImage: "apple.logo")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
                            .foregroundStyle(.black)
                            .frame(minHeight: RooBinTheme.Control.minimumTargetSize)
                            .accessibilityIdentifier("auth.apple")

                            Button(action: useGoogle) {
                                Label("Continue with Google", systemImage: "person.crop.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .frame(minHeight: RooBinTheme.Control.minimumTargetSize)
                            .accessibilityIdentifier("auth.google")

                            Button(action: useEmail) {
                                Label("Continue with email", systemImage: "envelope")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .frame(minHeight: RooBinTheme.Control.minimumTargetSize)
                            .accessibilityIdentifier("auth.email")
                        }
                    }

                    Text("By continuing, you agree to RooBin’s terms and acknowledge its privacy policy.")
                        .font(.footnote)
                        .foregroundStyle(RooBinTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("auth.legalNotice")

                    Spacer(minLength: 24)
                }
                .padding(RooBinTheme.Spacing.standard)
            }
        }
        .navigationBarBackButtonHidden()
    }
}
