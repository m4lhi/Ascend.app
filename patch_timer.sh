sed -i '' 's/if isRunning && !gpsManager.isAutoPaused { timeElapsed += 1 }/if isRunning \&\& !gpsManager.isAutoPaused { \
                timeElapsed += 1 \
                appState.trackerElapsedSeconds = timeElapsed\
            }\
            appState.trackerDistanceKm = gpsManager.distance \/ 1000.0\
            appState.trackerElevationGain = gpsManager.elevationGain\
            appState.isTrackerPaused = !isRunning || gpsManager.isAutoPaused/' Ascent/LiveRecordView.swift
