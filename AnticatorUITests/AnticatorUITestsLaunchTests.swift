//
//  AnticatorUITestsLaunchTests.swift
//  AnticatorUITests
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import XCTest

final class AnticatorUITestsLaunchTests: XCTestCase {
    
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Verificar que la app se lanzó correctamente
        XCTAssertEqual(app.state, .runningForeground)
        
        // Capturar screenshot del estado inicial
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    @MainActor
    func testLaunchInLightMode() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIUserInterfaceStyleLightMode"]
        app.launch()
        
        XCTAssertEqual(app.state, .runningForeground)
        
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Light Mode"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    @MainActor
    func testLaunchInDarkMode() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIUserInterfaceStyleDarkMode"]
        app.launch()
        
        XCTAssertEqual(app.state, .runningForeground)
        
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Dark Mode"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
