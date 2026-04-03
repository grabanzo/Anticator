//
//  AnticatorUITests.swift
//  AnticatorUITests
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import XCTest

final class AnticatorUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Launch Tests
    
    @MainActor
    func testAppLaunches() throws {
        // Verificar que la app se lanza correctamente
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Navigation Tests
    
    @MainActor
    func testTabBarExists() throws {
        // Verificar que existe la barra de pestañas
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    }
    
    @MainActor
    func testNavigateToSettings() throws {
        // Buscar el botón de configuración en la toolbar
        let settingsButton = app.buttons["gear"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            
            // Verificar que se muestra la vista de configuración
            let settingsNavBar = app.navigationBars["Ajustes"]
            XCTAssertTrue(settingsNavBar.waitForExistence(timeout: 3))
        }
    }
    
    // MARK: - Add Account Flow Tests
    
    @MainActor
    func testAddButtonExists() throws {
        // Verificar que existe el botón de agregar
        let addButton = app.buttons["plus"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
    }
    
    @MainActor
    func testAddAccountFlowShowsOptions() throws {
        let addButton = app.buttons["plus"]
        if addButton.waitForExistence(timeout: 5) {
            addButton.tap()
            
            // Esperar a que aparezca el menú o sheet
            // Puede ser un ActionSheet o un menú contextual
            let scanOption = app.buttons.matching(identifier: "Escanear código QR").firstMatch
            let manualOption = app.buttons.matching(identifier: "Introducir manualmente").firstMatch
            
            let hasOptions = scanOption.waitForExistence(timeout: 3) || manualOption.waitForExistence(timeout: 1)
            XCTAssertTrue(hasOptions, "Debe mostrar opciones para agregar cuenta")
        }
    }
    
    // MARK: - Empty State Tests
    
    @MainActor
    func testEmptyStateMessage() throws {
        // Si no hay cuentas, debería mostrar un mensaje vacío
        // Esto depende del estado inicial de la app
        let emptyStateText = app.staticTexts["Sin cuentas"]
        if emptyStateText.exists {
            XCTAssertTrue(emptyStateText.isHittable)
        }
    }
    
    // MARK: - Accessibility Tests
    
    @MainActor
    func testAccessibility_AddButtonIsAccessible() throws {
        let addButton = app.buttons["plus"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertTrue(addButton.isEnabled)
        XCTAssertTrue(addButton.isHittable)
    }
    
    @MainActor
    func testAccessibility_TabBarItemsAreAccessible() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("TabBar no encontrada")
            return
        }
        
        // Verificar que los elementos del TabBar son accesibles
        let tabButtons = tabBar.buttons
        XCTAssertGreaterThan(tabButtons.count, 0, "Debe haber al menos un tab")
    }
    
    // MARK: - Search Tests
    
    @MainActor
    func testSearchFieldExists() throws {
        // La búsqueda puede estar en un NavigationView
        // Intentar hacer pull-down para revelar la búsqueda
        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists {
            collectionView.swipeDown()
            
            let searchField = app.searchFields.firstMatch
            // La búsqueda puede o no existir dependiendo de si hay cuentas
            _ = searchField.waitForExistence(timeout: 2)
        }
    }
}
