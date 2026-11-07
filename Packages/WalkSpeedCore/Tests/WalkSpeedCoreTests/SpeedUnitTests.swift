import Foundation
import Testing
import WalkSpeedCore

@Suite("SpeedUnit")
struct SpeedUnitTests {
    @Test func convertsMetresPerSecond() {
        #expect(isClose(SpeedUnit.kilometresPerHour.value(fromMetresPerSecond: 1), 3.6))
        #expect(isClose(SpeedUnit.milesPerHour.value(fromMetresPerSecond: 1), 2.236_936, tolerance: 1e-6))
    }

    @Test(arguments: SpeedUnit.allCases)
    func roundTripsValues(unit: SpeedUnit) {
        let speed = 1.37
        #expect(isClose(unit.metresPerSecond(from: unit.value(fromMetresPerSecond: speed)), speed))
    }

    @Test func snapsLimitOntoTheStepGridBeforeStepping() {
        let limit = 1.5 // 5.4 km/h, 3.355… mph
        let mph = SpeedUnit.milesPerHour
        #expect(isClose(mph.value(fromMetresPerSecond: mph.steppedLimit(limit, by: 1)), 3.5))
        #expect(isClose(mph.value(fromMetresPerSecond: mph.steppedLimit(limit, by: -1)), 3.3))
        #expect(isClose(mph.value(fromMetresPerSecond: mph.steppedLimit(limit, by: 0)), 3.4))

        let kmh = SpeedUnit.kilometresPerHour
        #expect(isClose(kmh.value(fromMetresPerSecond: kmh.steppedLimit(limit, by: 1)), 5.5))
        #expect(isClose(kmh.value(fromMetresPerSecond: kmh.steppedLimit(limit, by: -3)), 5.1))
    }

    @Test(arguments: SpeedUnit.allCases)
    func clampsSteppedLimitToRange(unit: SpeedUnit) {
        let top = unit.metresPerSecond(from: unit.limitRange.upperBound)
        let bottom = unit.metresPerSecond(from: unit.limitRange.lowerBound)
        #expect(isClose(unit.steppedLimit(top, by: 5), top))
        #expect(isClose(unit.steppedLimit(bottom, by: -5), bottom))
    }

    @Test func formatsWithOneDecimalInTheGivenLocale() {
        let speed = SpeedUnit.kilometresPerHour.metresPerSecond(from: 5.44)
        #expect(SpeedUnit.kilometresPerHour.formatted(speed, locale: Locale(identifier: "en_US")) == "5.4")
        #expect(SpeedUnit.kilometresPerHour.formatted(speed, locale: Locale(identifier: "de_DE")) == "5,4")
    }

    @Test(arguments: [
        ("en_US", SpeedUnit.milesPerHour),
        ("en_GB", .milesPerHour),
        ("fr_FR", .kilometresPerHour),
        ("de_DE", .kilometresPerHour),
        ("ja_JP", .kilometresPerHour),
    ])
    func prefersTheRegionsUnit(identifier: String, expected: SpeedUnit) {
        #expect(SpeedUnit.preferred(for: Locale(identifier: identifier)) == expected)
    }

    @Test func rawValuesAreStableStorageKeys() {
        #expect(SpeedUnit(rawValue: "kmh") == .kilometresPerHour)
        #expect(SpeedUnit(rawValue: "mph") == .milesPerHour)
    }
}

func isClose(_ lhs: Double, _ rhs: Double, tolerance: Double = 1e-9) -> Bool {
    abs(lhs - rhs) <= tolerance
}
