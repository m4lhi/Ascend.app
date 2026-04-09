sed -i '' -e '/if isRunning && !gpsManager.isAutoPaused { timeElapsed += 1 }/a\
            \
            #if canImport(ActivityKit)\
            if #available(iOS 16.2, *) {\
                let isPaused = !isRunning || gpsManager.isAutoPaused\
                let speedMps = timeElapsed > 0 ? (Double(gpsManager.distance) / Double(timeElapsed)) : 0\
                LiveActivityManager.shared.updateActivity(\
                    duration: Double(timeElapsed),\
                    distanceMeter: gpsManager.distance,\
                    remainingDistanceMeter: navigationManager.totalRemainingDistance,\
                    averageSpeedMps: speedMps,\
                    isPaused: isPaused\
                )\
            }\
            #endif\
' "/Users/philip/Documents/Ascend Main/Ascent/LiveRecordView.swift"

sed -i '' -e '/private func startRecording() {/a\
        #if canImport(ActivityKit)\
        if #available(iOS 16.2, *) {\
            LiveActivityManager.shared.startActivity(mountainName: targetMountain?.name ?? "Mission")\
        }\
        #endif' "/Users/philip/Documents/Ascend Main/Ascent/LiveRecordView.swift"

sed -i '' -e '/func endMission() {/a\
        #if canImport(ActivityKit)\
        if #available(iOS 16.2, *) {\
            LiveActivityManager.shared.endActivity()\
        }\
        #endif' "/Users/philip/Documents/Ascend Main/Ascent/LiveRecordView.swift"
