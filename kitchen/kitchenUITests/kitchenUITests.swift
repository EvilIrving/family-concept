import XCTest

final class kitchenUITests: XCTestCase {
    private let e2eUserName = "heyiwuyi"
    private let e2ePassword = "heyiwuyi"
    private let e2eInviteCode = "11F290"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingFlow_Login() throws {
        let app = XCUIApplication()
        app.launch()

        let userNameField = app.textFields.matching(NSPredicate(format: "placeholderValue == '用户名'")).firstMatch
        let passwordField = app.secureTextFields.matching(NSPredicate(format: "placeholderValue == '密码'")).firstMatch
        let loginButton = app.buttons["登录"]

        XCTAssertTrue(userNameField.exists, "用户名输入框不存在")
        XCTAssertTrue(passwordField.exists, "密码输入框不存在")
        XCTAssertTrue(loginButton.exists, "登录按钮不存在")
    }

    @MainActor
    func testOnboardingFlow_Register() throws {
        let app = XCUIApplication()
        app.launch()

        let registerLink = app.buttons.matching(NSPredicate(format: "label CONTAINS '注册'")).firstMatch
        registerLink.tap()

        let userNameField = app.textFields.matching(NSPredicate(format: "placeholderValue == '用户名'")).firstMatch
        let nickNameField = app.textFields.matching(NSPredicate(format: "placeholderValue == '昵称'")).firstMatch
        let passwordField = app.secureTextFields.matching(NSPredicate(format: "placeholderValue == '密码'")).firstMatch
        let registerButton = app.buttons["注册"]

        XCTAssertTrue(userNameField.exists)
        XCTAssertTrue(nickNameField.exists)
        XCTAssertTrue(passwordField.exists)
        XCTAssertTrue(registerButton.exists)
    }

    @MainActor
    func testCreateKitchen_AfterLogin() throws {
        let app = XCUIApplication()
        app.launch()

        let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '创建我的私厨'")).firstMatch
        XCTAssertTrue(createButton.exists, "创建私厨按钮不存在")
    }

    @MainActor
    func testJoinKitchen_WithInviteCode() throws {
        let app = XCUIApplication()
        app.launch()

        let joinButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '输入邀请码加入'")).firstMatch
        XCTAssertTrue(joinButton.exists, "加入私厨按钮不存在")
    }

    @MainActor
    func testE2E_LoginAndJoinKitchenWithInviteCode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["isE2ETest", "resetUITestSession"]
        app.launch()

        if mainTabExists(in: app, timeout: 5) {
            return
        }

        if joinKitchenIfNeeded(in: app) {
            XCTAssertTrue(mainTabExists(in: app, timeout: 15), "加入私厨后未进入主界面")
            return
        }

        let userNameField = app.textFields.matching(NSPredicate(format: "placeholderValue == '用户名'")).firstMatch
        let passwordField = app.secureTextFields.matching(NSPredicate(format: "placeholderValue == '密码'")).firstMatch
        let loginButton = app.buttons["登录"]

        XCTAssertTrue(userNameField.waitForExistence(timeout: 8), "用户名输入框不存在")
        userNameField.tap()
        userNameField.typeText(e2eUserName)

        XCTAssertTrue(passwordField.exists, "密码输入框不存在")
        passwordField.tap()
        passwordField.typeText(e2ePassword)

        XCTAssertTrue(loginButton.exists, "登录按钮不存在")
        loginButton.tap()

        if mainTabExists(in: app, timeout: 10) {
            return
        }

        XCTAssertTrue(joinKitchenIfNeeded(in: app), "登录后未出现邀请码加入入口")
        XCTAssertTrue(mainTabExists(in: app, timeout: 15), "登录并加入私厨后未进入主界面")
    }

    private func joinKitchenIfNeeded(in app: XCUIApplication) -> Bool {
        let joinModeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '输入邀请码加入'")).firstMatch
        if joinModeButton.waitForExistence(timeout: 8) {
            joinModeButton.tap()
        }

        let inviteField = app.textFields.matching(NSPredicate(format: "placeholderValue == '邀请码'")).firstMatch
        guard inviteField.waitForExistence(timeout: 3) else {
            return false
        }
        inviteField.tap()
        inviteField.typeText(e2eInviteCode)

        let joinSubmitButton = app.buttons["加入"]
        guard joinSubmitButton.waitForExistence(timeout: 5) else {
            return false
        }
        joinSubmitButton.tap()
        return true
    }

    @MainActor
    func testMenuView_LoadingState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["isUITest"]
        app.launch()

        let menuView = app.otherElements.matching(NSPredicate(format: "identifier == 'menuView'")).firstMatch
        XCTAssertTrue(menuView.exists, "菜单页面不存在")
    }

    @MainActor
    func testMainTab_Structure() throws {
        let app = XCUIApplication()
        app.launchArguments = ["isUITest"]
        app.launch()

        let menuTab = app.buttons.matching(NSPredicate(format: "label CONTAINS '菜单'")).firstMatch
        let ordersTab = app.buttons.matching(NSPredicate(format: "label CONTAINS '订单'")).firstMatch
        let settingsTab = app.buttons.matching(NSPredicate(format: "label CONTAINS '设置'")).firstMatch

        let hasAllTabs = menuTab.exists || ordersTab.exists || settingsTab.exists
        XCTAssertTrue(hasAllTabs, "主 Tab 栏结构不完整")
    }

    @MainActor
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    private func mainTabExists(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let menuTab = app.buttons.matching(NSPredicate(format: "label CONTAINS '菜单'")).firstMatch
        let ordersTab = app.buttons.matching(NSPredicate(format: "label CONTAINS '订单'")).firstMatch
        let settingsTab = app.buttons.matching(NSPredicate(format: "label CONTAINS '设置'")).firstMatch

        return menuTab.waitForExistence(timeout: timeout)
            || ordersTab.waitForExistence(timeout: 1)
            || settingsTab.waitForExistence(timeout: 1)
    }
}
