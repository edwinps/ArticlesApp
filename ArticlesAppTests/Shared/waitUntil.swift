//
//  waitUntil.swift
//  ArticlesAppTests
//
//  Created by Edwinps on 24/2/26.
//

import Foundation
import Testing


func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    pollNanoseconds: UInt64 = 10_000_000,
    _ condition: @MainActor () -> Bool
) async throws {
    let start = ContinuousClock.now
    while await !condition() {
        if ContinuousClock.now.duration(to: start) > .nanoseconds(Int64(timeoutNanoseconds)) {
            #expect(Bool(false), "Timed out waiting for condition after \(timeoutNanoseconds) ns")
            return
        }
        try await Task.sleep(nanoseconds: pollNanoseconds)
    }
}
