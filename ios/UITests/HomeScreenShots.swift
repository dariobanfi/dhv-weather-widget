import XCTest

/// Puts the real widgets on the simulator's Home Screen through SpringBoard and
/// screenshots them in each Home Screen appearance (Default, Dark, Clear,
/// Tinted), so the README shows what iOS itself draws, Liquid Glass included.
///
/// Run by CI with `TEST_RUNNER_SHOTS_DIR` pointing at a folder on the host.
/// SpringBoard's labels aren't API, so every step logs the accessibility tree
/// when it can't find what it expects, and the test only fails if no
/// screenshot at all was taken.
final class HomeScreenShots: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private var shots = 0
    private var loggedCustomize = false

    private lazy var outDir: URL = {
        let path = ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? NSTemporaryDirectory()
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    override func setUp() {
        continueAfterFailure = true
    }

    func testHomeScreenAppearances() throws {
        // Open the app once so it downloads the forecast and iOS registers the widgets.
        let app = XCUIApplication()
        app.launch()
        sleep(8)
        XCUIDevice.shared.press(.home)
        sleep(2)

        addWidget(swipes: 1) // DHV Wetter, large
        addWidget(swipes: 0) // DHV Wetter, medium (lands above the large one)
        leaveEditMode()

        // Give the widgets time to fetch and render their timeline.
        sleep(25)
        shoot("hs-default")

        for (label, name) in [("Dark", "hs-dark"), ("Clear", "hs-clear"), ("Tinted", "hs-tinted")] {
            if setAppearance(label) {
                sleep(4)
                shoot(name)
            }
        }
        // Clear also comes in a dark variant on iOS 26.
        if setAppearance("Clear", variant: "Dark") {
            sleep(4)
            shoot("hs-clear-dark")
        }
        _ = setAppearance("Default")

        XCTAssertGreaterThan(shots, 0, "No Home Screen screenshot was taken")
    }

    // MARK: - SpringBoard steps

    private func enterEditMode() -> Bool {
        if springboard.buttons["Done"].exists { return true }
        // Long-press one of our widgets (or an empty spot before they exist);
        // the context menu offers "Edit Home Screen". A long press on empty
        // space goes straight to jiggle mode.
        let widget = springboard.icons["DHV Wetter"].firstMatch
        if widget.exists, widget.isHittable {
            widget.press(forDuration: 1.6)
        } else {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.80)).press(forDuration: 1.6)
        }
        sleep(1)
        let editHome = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Edit Home Screen")).firstMatch
        if editHome.exists { editHome.tap(); sleep(1) }
        if springboard.buttons["Done"].waitForExistence(timeout: 4) { return true }
        dump("enterEditMode")
        return false
    }

    private func openEditMenu(_ item: String) -> Bool {
        guard enterEditMode() else { return false }
        let edit = springboard.buttons["Edit"]
        if edit.waitForExistence(timeout: 3) {
            edit.tap()
            sleep(1)
        }
        for query in [springboard.buttons, springboard.menuItems, springboard.staticTexts] {
            let element = query[item]
            if element.waitForExistence(timeout: 2) {
                element.tap()
                sleep(2)
                return true
            }
        }
        dump("openEditMenu(\(item))")
        return false
    }

    private func addWidget(swipes: Int) {
        guard openEditMenu("Add Widget") else { return }

        let search = springboard.searchFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText("DHV")
            sleep(2)
        } else {
            dump("widget gallery search")
        }

        var opened = false
        for query in [springboard.cells, springboard.buttons, springboard.staticTexts] {
            let result = query.matching(NSPredicate(format: "label CONTAINS[c] %@", "DHV Wetter")).firstMatch
            if result.waitForExistence(timeout: 2), result.isHittable {
                result.tap()
                opened = true
                break
            }
        }
        guard opened else { dump("widget gallery result"); return }
        sleep(2)

        for _ in 0..<swipes {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.45))
                .press(forDuration: 0.05, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.45)))
            sleep(1)
        }

        let add = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Add Widget")).firstMatch
        if add.waitForExistence(timeout: 4) {
            add.tap()
            sleep(3)
        } else {
            dump("add widget button")
        }
    }

    private func leaveEditMode() {
        let done = springboard.buttons["Done"]
        if done.waitForExistence(timeout: 2) { done.tap() }
        sleep(1)
    }

    /// Picks an appearance in Edit → Customize. Returns false if it couldn't.
    private func setAppearance(_ label: String, variant: String? = nil) -> Bool {
        guard openEditMenu("Customize") else { return false }
        if !loggedCustomize {
            loggedCustomize = true
            print("HOMESHOT Customize panel:")
            print(springboard.debugDescription)
        }
        var picked = false
        for query in [springboard.buttons, springboard.cells, springboard.staticTexts] {
            let option = query[label]
            if option.waitForExistence(timeout: 2) {
                option.tap()
                picked = true
                break
            }
        }
        if !picked { dump("Customize: \(label)") }
        if picked, let variant {
            let toggle = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", variant)).firstMatch
            if toggle.waitForExistence(timeout: 2) { toggle.tap() } else { dump("Customize variant: \(variant)"); picked = false }
        }
        sleep(1)
        // The Home button closes the Customize panel and then ends jiggle mode.
        XCUIDevice.shared.press(.home)
        sleep(1)
        if springboard.buttons["Done"].exists { XCUIDevice.shared.press(.home); sleep(1) }
        leaveEditMode()
        return picked
    }

    // MARK: - Output

    private func shoot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        do {
            try png.write(to: outDir.appendingPathComponent("\(name).png"))
            shots += 1
            print("HOMESHOT saved \(name).png")
        } catch {
            print("HOMESHOT could not write \(name).png: \(error)")
        }
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func dump(_ step: String) {
        print("HOMESHOT missing element at step: \(step)")
        print(springboard.debugDescription)
        shoot("debug-\(shots)-\(step.filter { $0.isLetter || $0.isNumber })")
        shots -= 1 // debug frames don't count as results
    }
}
