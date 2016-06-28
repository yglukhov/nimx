import tables

import nimx.matrixes
import nimx.system_logger
import nimx.animation
import nimx.image
import nimx.window
import nimx.autotest
import nimx.button, nimx.text_field

import nimx.edit_view

const isMobile = defined(ios) or defined(android)

proc runAutoTestsIfNeeded() =
    uiTest generalUITest:
        discard
        quitApplication()

    registerTest(generalUITest)
    when defined(runAutoTests):
        startRegisteredTests()

proc startApplication() =
    when isMobile:
        var mainWindow = newFullscreenWindow()
    else:
        var mainWindow = newWindow(newRect(40, 40, 1200, 600))

    mainWindow.title = "nimx"

    let editedView = View.new(mainWindow.bounds)
    editedView.autoresizingMask = {afFlexibleWidth, afFlexibleHeight}
    mainWindow.addSubview(editedView)

    let dummyButton = Button.new(newRect(100, 100, 60, 25))
    dummyButton.title = "Hello!"
    editedView.addSubview(dummyButton)

    discard editedView.newTextField(newPoint(180, 100), newSize(60, 25), "World!")

    discard editedView.startEditingInView(mainWindow)

    runAutoTestsIfNeeded()

runApplication:
    startApplication()
