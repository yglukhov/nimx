import nimx

proc runAutoTestsIfNeeded() =
    uiTest generalUITest:
        discard
        quitApplication()

    registerTest(generalUITest)
    when defined(runAutoTests):
        startRegisteredTests()

proc startApplication() =
    when mobile:
        var mainWindow = newFullscreenWindow()
    else:
        var mainWindow = newWindow(newRect(40, 40, 1200, 600))
    mainWindow.title = "nimx"
    startNimxEditor(mainWindow)
    runAutoTestsIfNeeded()

runApplication:
    startApplication()
