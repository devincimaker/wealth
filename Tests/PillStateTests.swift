import Foundation
import Testing
@testable import Wealth

// The pill is derived purely from persisted captures, which is what lets it
// rehydrate after a lock or relaunch.
@MainActor
struct PillStateTests {
    @Test func noCapturesMeansNoPill() {
        #expect(PillState(captures: []) == nil)
    }

    @Test func workingShowsTheCurrentItem() throws {
        let capture = makeCapture(status: .working, title: "Logging AR$ 40.000 · Cena…")
        let state = try #require(PillState(captures: [capture]))
        #expect(state.kind == .working)
        #expect(state.label == "Logging AR$ 40.000 · Cena…")
        #expect(state.queuedBehind == 0)
    }

    @Test func queuedItemsBecomeTheBadgeCount() throws {
        let captures = [
            makeCapture(status: .queued, title: "Third"),
            makeCapture(status: .queued, title: "Second"),
            makeCapture(status: .working, title: "First"),
        ]
        let state = try #require(PillState(captures: captures))
        #expect(state.queuedBehind == 2)
    }

    @Test func workingOutranksFailures() throws {
        let captures = [
            makeCapture(status: .failed, title: "Didn't catch an amount"),
            makeCapture(status: .working, title: "Logging…"),
        ]
        #expect(try #require(PillState(captures: captures)).kind == .working)
    }

    @Test func aSingleLandedCaptureShowsItsOwnLabel() throws {
        let capture = makeCapture(status: .applied, title: "Logged AR$ 40.000 · Food & Drink")
        let state = try #require(PillState(captures: [capture]))
        #expect(state.kind == .landed)
        #expect(state.label == "Logged AR$ 40.000 · Food & Drink")
        #expect(state.autoHides)
    }

    @Test func severalLandedCapturesCollapseIntoACount() throws {
        let captures = (1...3).map { makeCapture(status: .applied, title: "Logged \($0)") }
        #expect(try #require(PillState(captures: captures)).label == "3 logged")
    }

    @Test func failureStatesStickAndCountBothSides() throws {
        let captures = [
            makeCapture(status: .applied, title: "Logged 1"),
            makeCapture(status: .applied, title: "Logged 2"),
            makeCapture(status: .failed, title: "Didn't catch an amount"),
        ]
        let state = try #require(PillState(captures: captures))
        #expect(state.kind == .failed)
        #expect(state.label == "2 logged · 1 failed")
        #expect(!state.autoHides)
    }

    @Test func oldLandedCapturesStopShowing() {
        let capture = makeCapture(status: .applied, title: "Logged yesterday")
        capture.createdAt = Date.now.addingTimeInterval(-3600)
        #expect(PillState(captures: [capture]) == nil)
    }

    @Test func undoneAndCanceledCapturesShowNoPill() {
        let captures = [
            makeCapture(status: .rewound, title: "Logged AR$ 9.800"),
            makeCapture(status: .canceled, title: "Canceled"),
        ]
        #expect(PillState(captures: captures) == nil)
    }

    private func makeCapture(status: CaptureStatus, title: String) -> VoiceCapture {
        let capture = VoiceCapture(audioFileName: "\(UUID().uuidString).m4a")
        capture.captureStatus = status
        capture.title = title
        return capture
    }
}
