//
//  FitnessWidgetBundle.swift
//  FitnessWidget
//
//  Created by Davide Corso on 30/05/2026.
//

import WidgetKit
import SwiftUI

@main
struct FitnessWidgetBundle: WidgetBundle {
    var body: some Widget {
        FitnessWidget()
        if #available(iOS 18.0, *) {
            PausaControl()
        }
        #if canImport(ActivityKit) && os(iOS)
        RunLiveActivity()
        RestLiveActivity()
        #endif
    }
}
