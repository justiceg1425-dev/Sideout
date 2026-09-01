import Foundation
import HealthKit

/// Runs a HealthKit workout session for the duration of the game so the
/// watch app stays frontmost through wrist drops — the screen is live for
/// the whole game, which is why the dead gutter and touch-up commit matter
/// so much elsewhere in the app. Every finished game logs a workout to
/// Health; the game-over screen acknowledges that in one line.
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private(set) var startDate: Date?

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let typesToShare: Set = [HKObjectType.workoutType()]
        healthStore.requestAuthorization(toShare: typesToShare, read: []) { _, _ in }
    }

    func start() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let configuration = HKWorkoutConfiguration()
        // .pickleball needs a newer SDK than this app's watchOS 8 floor
        // (Series 3 support); racquetball is the closest category on
        // older watchOS and a harmless Health-app label choice either way.
        if #available(watchOS 9.0, *) {
            configuration.activityType = .pickleball
        } else {
            configuration.activityType = .racquetball
        }
        configuration.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            self.session = session
            self.builder = builder
            let start = Date()
            startDate = start
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
        } catch {
            session = nil
            builder = nil
            startDate = nil
        }
    }

    func stop() {
        guard let session, let builder else { return }
        session.end()
        let end = Date()
        builder.endCollection(withEnd: end) { _, _ in
            builder.finishWorkout { _, _ in }
        }
        self.session = nil
        self.builder = nil
    }

    var elapsedMinutes: Int {
        guard let startDate else { return 0 }
        return max(0, Int(Date().timeIntervalSince(startDate) / 60))
    }
}
