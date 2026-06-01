import Foundation

public extension Array where Element: Sendable {
    /// Transforms each element concurrently while keeping at most `maxConcurrency`
    /// tasks in flight, returning the results in the original element order.
    ///
    /// This is the bounded fan-out primitive behind the portfolio snapshot: a
    /// large Netlify account (140+ sites) would be painfully slow to walk one
    /// request at a time, but an unbounded fan-out would hammer the API rate
    /// limit. A fixed in-flight window keeps wall-clock low while staying gentle
    /// on Netlify, and order preservation means callers can reason about results
    /// positionally without an extra sort.
    ///
    /// - Parameters:
    ///   - maxConcurrency: Upper bound on simultaneously running tasks. Values
    ///     below 1 are clamped to 1 (degrading gracefully to a sequential walk).
    ///   - transform: An async, `Sendable` transform applied to each element.
    /// - Returns: The transformed elements in the same order as the receiver.
    func concurrentMap<T: Sendable>(
        maxConcurrency: Int,
        _ transform: @Sendable @escaping (Element) async -> T
    ) async -> [T] {
        guard !isEmpty else { return [] }
        let limit = Swift.max(1, maxConcurrency)

        return await withTaskGroup(of: (Int, T).self) { group in
            var results = [T?](repeating: nil, count: count)
            var submitted = 0

            // Prime the group up to the concurrency ceiling.
            while submitted < Swift.min(limit, count) {
                let index = submitted
                let element = self[index]
                group.addTask { (index, await transform(element)) }
                submitted += 1
            }

            // Each completion backfills its slot and admits the next element, so
            // exactly `limit` tasks stay in flight until the work is drained.
            while let (index, value) = await group.next() {
                results[index] = value
                if submitted < count {
                    let nextIndex = submitted
                    let element = self[nextIndex]
                    group.addTask { (nextIndex, await transform(element)) }
                    submitted += 1
                }
            }

            // Every slot is guaranteed filled once the group is exhausted.
            return results.compactMap { $0 }
        }
    }
}
