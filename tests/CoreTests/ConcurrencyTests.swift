import XCTest
@testable import NetlifyPortfolioSentinelCore

final class ConcurrencyTests: XCTestCase {
    private actor Tracker {
        private(set) var inFlight = 0
        private(set) var peak = 0
        func enter() { inFlight += 1; peak = max(peak, inFlight) }
        func leave() { inFlight -= 1 }
    }

    func testConcurrentMapPreservesOrder() async {
        let input = Array(0..<100)
        let output = await input.concurrentMap(maxConcurrency: 8) { value in
            // Reverse-bias the delay so later items can finish first if order
            // were not enforced; the result must still match input order.
            try? await Task.sleep(nanoseconds: UInt64((100 - value) * 10_000))
            return value * 2
        }
        XCTAssertEqual(output, input.map { $0 * 2 })
    }

    func testConcurrentMapRespectsConcurrencyCeiling() async {
        let tracker = Tracker()
        let input = Array(0..<40)
        let limit = 5
        let output = await input.concurrentMap(maxConcurrency: limit) { value in
            await tracker.enter()
            try? await Task.sleep(nanoseconds: 2_000_000) // 2ms overlap window
            await tracker.leave()
            return value
        }
        let peak = await tracker.peak
        XCTAssertEqual(output, input)
        XCTAssertLessThanOrEqual(peak, limit, "In-flight tasks must never exceed the ceiling")
        XCTAssertGreaterThan(peak, 1, "Expected real concurrency, not serial execution")
    }

    func testConcurrentMapHandlesEmpty() async {
        let input: [Int] = []
        let output = await input.concurrentMap(maxConcurrency: 4) { $0 }
        XCTAssertTrue(output.isEmpty)
    }

    func testConcurrentMapClampsNonPositiveConcurrency() async {
        let input = Array(0..<5)
        let output = await input.concurrentMap(maxConcurrency: 0) { $0 + 1 }
        XCTAssertEqual(output, [1, 2, 3, 4, 5])
    }
}
