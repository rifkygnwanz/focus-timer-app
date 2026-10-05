import SwiftUI
import WidgetKit

@main
struct FokusWidgetBundle: WidgetBundle {
    var body: some Widget {
        FokusTimerWidget()
        FokusLiveActivity()
    }
}
