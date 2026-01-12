//
//  AppleIntelligenceAvailability.swift
//  chat
//
//  Created by Steven Zhang on 1/12/26.
//

import Foundation
import FoundationModels

enum AppleIntelligenceAvailabilityOverride: String, CaseIterable, Identifiable {
    case system
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .available: "Force Available"
        case .deviceNotEligible: "Force: Device Not Eligible"
        case .appleIntelligenceNotEnabled: "Force: Not Enabled"
        case .modelNotReady: "Force: Model Not Ready"
        }
    }

    var forcedAvailability: SystemLanguageModel.Availability? {
        switch self {
        case .system:
            return nil
        case .available:
            return .available
        case .deviceNotEligible:
            return .unavailable(.deviceNotEligible)
        case .appleIntelligenceNotEnabled:
            return .unavailable(.appleIntelligenceNotEnabled)
        case .modelNotReady:
            return .unavailable(.modelNotReady)
        }
    }
}

enum AppleIntelligenceAvailability {
    static let overrideDefaultsKey = "aiAvailabilityOverride"

    static func effectiveAvailability(system: SystemLanguageModel.Availability) -> SystemLanguageModel.Availability {
        #if DEBUG
        let raw = UserDefaults.standard.string(forKey: overrideDefaultsKey) ?? AppleIntelligenceAvailabilityOverride.system.rawValue
        if let override = AppleIntelligenceAvailabilityOverride(rawValue: raw),
           let forced = override.forcedAvailability {
            return forced
        }
        #endif
        return system
    }

    static func description(_ availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .available:
            return "Available"
        case .unavailable(.deviceNotEligible):
            return "Unavailable: Device not eligible"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Unavailable: Apple Intelligence not enabled"
        case .unavailable(.modelNotReady):
            return "Unavailable: Model not ready"
        case .unavailable:
            return "Unavailable"
        }
    }
}

