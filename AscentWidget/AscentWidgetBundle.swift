//
//  AscentWidgetBundle.swift
//  AscentWidget
//
//  Created by Philip on 09.04.26.
//

import WidgetKit
import SwiftUI

@main
struct AscentWidgetBundle: WidgetBundle {
    var body: some Widget {
        AscentWidget()
        AscentWidgetControl()
        AscentWidgetLiveActivity()
    }
}
