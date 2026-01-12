//
//  GenerativeAvailabilityGateView.swift
//  chat
//
//  Created by Steven Zhang on 1/12/26.
//

import SwiftUI
import FoundationModels

#if canImport(UIKit)
import UIKit
#endif

struct GenerativeAvailabilityGateView<Content: View>: View {
    private var model = SystemLanguageModel.default
    private let content: () -> Content

    @Environment(\.openURL) private var openURL
    @State private var refreshTick = 0
    #if DEBUG
    @AppStorage(AppleIntelligenceAvailability.overrideDefaultsKey) private var availabilityOverrideRaw = AppleIntelligenceAvailabilityOverride.system.rawValue
    #endif

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            let availability = AppleIntelligenceAvailability.effectiveAvailability(system: model.availability)
            switch availability {
            case .available:
                content()
            case .unavailable(.deviceNotEligible):
                unavailableView(
                    symbol: "iphone.slash",
                    title: "Device Not Supported",
                    description: "This app requires Apple Intelligence, which isn’t available on this device."
                )
            case .unavailable(.appleIntelligenceNotEnabled):
                unavailableView(
                    symbol: "sparkles",
                    title: "Apple Intelligence Is Off",
                    description: "Turn on Apple Intelligence in Settings to use chat.",
                    showsOpenSettings: true
                )
            case .unavailable(.modelNotReady):
                unavailableView(
                    symbol: "icloud.and.arrow.down",
                    title: "Model Not Ready",
                    description: "Apple Intelligence is still downloading or preparing. Try again in a few minutes.",
                    showsProgress: true
                )
            case .unavailable:
                unavailableView(
                    symbol: "exclamationmark.triangle",
                    title: "Model Unavailable",
                    description: "Apple Intelligence isn’t available right now."
                )
            }
        }
        .id(refreshTick)
        #if DEBUG
        .onChange(of: availabilityOverrideRaw) { _, _ in
            refreshTick += 1
        }
        #endif
    }

    @ViewBuilder
    private func unavailableView(
        symbol: String,
        title: String,
        description: String,
        showsOpenSettings: Bool = false,
        showsProgress: Bool = false
    ) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.20),
                    Color.accentColor.opacity(0.06),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Image(systemName: symbol)
                        .font(.system(size: 44, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                        .padding(.bottom, 2)

                    Text(title)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)

                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if showsProgress {
                        ProgressView()
                            .padding(.top, 6)
                    }
                }
                .padding(24)
                .frame(maxWidth: 520)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 10) {
                    if showsOpenSettings {
                        Button("Open Settings") {
                            openSettings()
                        }
                        .buttonStyle(.glassProminent)
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }

                    if showsOpenSettings {
                        Button("Check Again") {
                            refreshTick += 1
                        }
                        .buttonStyle(.glass)
                        .frame(maxWidth: .infinity, minHeight: 48)
                    } else {
                        Button("Check Again") {
                            refreshTick += 1
                        }
                        .buttonStyle(.glassProminent)
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }

                    #if DEBUG
                    if availabilityOverrideRaw != AppleIntelligenceAvailabilityOverride.system.rawValue {
                        Button("Reset Debug Override", role: .destructive) {
                            availabilityOverrideRaw = AppleIntelligenceAvailabilityOverride.system.rawValue
                        }
                        .buttonStyle(.glass)
                        .tint(.red)
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    #endif
                }
                .frame(maxWidth: 520)
                .controlSize(.large)
                .tint(.accentColor)
            }
            .padding(24)
        }
    }

    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
        #endif
    }
}

#Preview {
    GenerativeAvailabilityGateView {
        MainView()
    }
}
