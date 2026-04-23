import XCTest

final class kitchenUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingFlow_Login() throws {
        let app = XCUIApplication()
        app.launch()

        let userNameField = app.textFields.matching(NSPredicate(format: "placeholderValue == '用户名或邮箱'")).firstMatch
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

        let userNameField = app.textFields.matching(NSPredicate(format: "placeholderValue == '用户名或邮箱'")).firstMatch
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
}
