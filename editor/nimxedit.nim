import tables

import nimx/matrixes
import nimx/system_logger
import nimx/animation
import nimx/image
import nimx/window
import nimx/autotest
import nimx/button, nimx/text_field
import nimx/all_views
import nimx/editor/edit_view

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
  startNimxEditor(mainWindow)
  runAutoTestsIfNeeded()

runApplication:
  startApplication()
