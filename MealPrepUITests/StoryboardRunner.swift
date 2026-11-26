import XCTest

/// Plays `Demo/storyboard.json` scene by scene so `Demo/make_video.py` can record each one.
///
/// It is driven by the host script, which passes two environment variables
/// (through xcodebuild's TEST_RUNNER_ prefix):
///   DEMO_STORYBOARD  path to the storyboard JSON
///   DEMO_SIGNAL_DIR  folder both sides use to hand off ("ready_0", "recording_0", …)
/// Run it with `python3 Demo/make_video.py`, not on its own.
final class StoryboardRunner: XCTestCase {
    private var signalDir: URL!
    private var app: XCUIApplication!
    /// When each on-camera action happened (Unix time), so the edit can speed up the gaps between them.
    private var events: [[String: Double]] = []
    private var recording = false

    override func setUp() {
        continueAfterFailure = true
    }

    func testRecordStoryboard() throws {
        let env = ProcessInfo.processInfo.environment
        guard let storyboardPath = env["DEMO_STORYBOARD"], let dir = env["DEMO_SIGNAL_DIR"] else {
            throw XCTSkip("Run through Demo/make_video.py")
        }
        signalDir = URL(fileURLWithPath: dir)
        let data = try Data(contentsOf: URL(fileURLWithPath: storyboardPath))
        let storyboard = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let scenes = storyboard["scenes"] as? [[String: Any]] ?? []

        for (index, scene) in scenes.enumerated() {
            signal("ready_\(index)")
            guard waitFor("go_\(index)", timeout: 60) else { return }

            app = XCUIApplication()
            app.launchArguments = (scene["launch"] as? [String]) ?? ["-PreviewSkipOnboarding"]
            app.launch()
            _ = app.wait(for: .runningForeground, timeout: 15)

            // Steps that get the screen ready before the camera rolls.
            run(scene["setup"] as? [[String: Any]] ?? [], scene: index)
            Thread.sleep(forTimeInterval: (scene["settle"] as? Double) ?? 1.0)

            signal("rolling_\(index)")
            guard waitFor("recording_\(index)", timeout: 30) else { return }
            Thread.sleep(forTimeInterval: (scene["leadIn"] as? Double) ?? 0.6)

            events = []
            recording = true
            run(scene["steps"] as? [[String: Any]] ?? [], scene: index)
            recording = false
            Thread.sleep(forTimeInterval: (scene["hold"] as? Double) ?? 1.2)

            if let json = try? JSONSerialization.data(withJSONObject: events) {
                try? json.write(to: signalDir.appendingPathComponent("events_\(index).json"))
            }
            signal("done_\(index)")
            _ = waitFor("stopped_\(index)", timeout: 30)
            app.terminate()
        }
        signal("finished")
    }

    // MARK: - Steps

    private func run(_ steps: [[String: Any]], scene: Int) {
        for (number, step) in steps.enumerated() {
            do {
                try perform(step)
            } catch {
                let message = "scene \(scene + 1), step \(number + 1) \(describe(step)): \(error.localizedDescription)"
                appendError(message)
                XCTFail(message)
            }
            Thread.sleep(forTimeInterval: (step["after"] as? Double) ?? 0.5)
        }
    }

    private func perform(_ step: [String: Any]) throws {
        if let label = step["tap"] as? String {
            try quickTap(element(label, contains: step["contains"] as? Bool ?? false, index: step["index"] as? Int ?? 0))
        } else if let point = step["tapAt"] as? [Double], point.count == 2 {
            mark { app.coordinate(withNormalizedOffset: CGVector(dx: point[0], dy: point[1])).tap() }
        } else if let text = step["type"] as? String {
            if let field = step["into"] as? String {
                try quickTap(element(field, contains: false, index: 0))
                Thread.sleep(forTimeInterval: 0.4)
            }
            let start = Date().timeIntervalSince1970
            // Type a few characters at a time so it looks like a person typing.
            for chunk in text.chunked(into: 2) {
                app.typeText(chunk)
                Thread.sleep(forTimeInterval: 0.06)
            }
            if recording { events.append(["start": start, "end": Date().timeIntervalSince1970]) }
        } else if let direction = step["swipe"] as? String {
            mark(gesture: true) { drag(direction, amount: step["amount"] as? Double ?? 0.45, speed: step["speed"] as? Double ?? 900) }
        } else if let label = step["scrollTo"] as? String {
            let target = app.descendants(matching: .any).matching(predicate(label, contains: step["contains"] as? Bool ?? false)).firstMatch
            var tries = 0
            while !(target.exists && target.isHittable && isComfortablyOnScreen(target)) && tries < 10 {
                mark(gesture: true) { drag(step["direction"] as? String ?? "up", amount: 0.3, speed: step["speed"] as? Double ?? 900) }
                Thread.sleep(forTimeInterval: 0.4)
                tries += 1
            }
            if !target.exists { throw StepError("couldn't find “\(label)” after scrolling") }
        } else if let seconds = step["wait"] as? Double {
            Thread.sleep(forTimeInterval: seconds)
        } else if let label = step["waitFor"] as? String {
            let target = app.descendants(matching: .any).matching(predicate(label, contains: step["contains"] as? Bool ?? false)).firstMatch
            if !target.waitForExistence(timeout: step["timeout"] as? Double ?? 20) {
                throw StepError("“\(label)” never appeared")
            }
        } else if step["back"] != nil {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.waitForExistence(timeout: 3) { try quickTap(back) } else { throw StepError("no back button") }
        } else {
            throw StepError("unknown step")
        }
    }

    /// Taps the element's centre as a raw touch. Much quicker than `element.tap()`, which re-finds the
    /// element and checks for alerts first, and it lets us note the exact moment of the touch.
    private func quickTap(_ element: XCUIElement) throws {
        let frame = element.frame
        guard !frame.isEmpty else {
            mark { element.tap() }
            return
        }
        let origin = app.coordinate(withNormalizedOffset: .zero)
        mark { origin.withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap() }
    }

    /// Runs an action and, while the camera rolls, records when it happened.
    private func mark(gesture: Bool = false, _ action: () -> Void) {
        let start = Date().timeIntervalSince1970
        action()
        guard recording else { return }
        // A tap is instant; a drag lasts until the call returns (minus XCUITest's ~0.3 s idle wait).
        events.append(["start": start, "end": gesture ? Date().timeIntervalSince1970 - 0.3 : start])
    }

    /// Finds a button first (most taps are buttons), then any element with that label, text or identifier.
    private func element(_ label: String, contains: Bool, index: Int) throws -> XCUIElement {
        let pred = predicate(label, contains: contains)
        let button = app.buttons.matching(pred).element(boundBy: index)
        if button.waitForExistence(timeout: 2) { return button }
        let any = app.descendants(matching: .any).matching(pred).element(boundBy: index)
        if any.waitForExistence(timeout: 8) { return any }
        throw StepError("couldn't find “\(label)” on screen")
    }

    private func predicate(_ label: String, contains: Bool) -> NSPredicate {
        contains
            ? NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@ OR value CONTAINS[c] %@", label, label, label)
            : NSPredicate(format: "label == %@ OR identifier == %@ OR value == %@", label, label, label)
    }

    private func isComfortablyOnScreen(_ element: XCUIElement) -> Bool {
        let screen = app.frame
        let frame = element.frame
        return frame.minY > screen.height * 0.15 && frame.maxY < screen.height * 0.85
    }

    /// A finger-speed drag instead of XCUITest's flick, so scrolling looks natural on video.
    private func drag(_ direction: String, amount: Double, speed: Double) {
        let half = amount / 2
        let (start, end): (CGVector, CGVector) = switch direction {
        case "up": (CGVector(dx: 0.5, dy: 0.5 + half), CGVector(dx: 0.5, dy: 0.5 - half))
        case "down": (CGVector(dx: 0.5, dy: 0.5 - half), CGVector(dx: 0.5, dy: 0.5 + half))
        case "left": (CGVector(dx: 0.5 + half, dy: 0.5), CGVector(dx: 0.5 - half, dy: 0.5))
        default: (CGVector(dx: 0.5 - half, dy: 0.5), CGVector(dx: 0.5 + half, dy: 0.5))
        }
        let from = app.coordinate(withNormalizedOffset: start)
        let to = app.coordinate(withNormalizedOffset: end)
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: XCUIGestureVelocity(rawValue: speed), thenHoldForDuration: 0.1)
    }

    // MARK: - Hand-off with the host script

    private func signal(_ name: String) {
        FileManager.default.createFile(atPath: signalDir.appendingPathComponent(name).path, contents: Data())
    }

    private func waitFor(_ name: String, timeout: TimeInterval) -> Bool {
        let path = signalDir.appendingPathComponent(name).path
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: path) { return true }
            Thread.sleep(forTimeInterval: 0.05)
        }
        appendError("timed out waiting for the recorder (\(name))")
        return false
    }

    private func appendError(_ message: String) {
        let url = signalDir.appendingPathComponent("errors.txt")
        let line = Data((message + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }

    private func describe(_ step: [String: Any]) -> String {
        step.map { "\($0.key): \($0.value)" }.sorted().joined(separator: ", ")
    }
}

private struct StepError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

private extension String {
    func chunked(into size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            return String(self[start..<end])
        }
    }
}
