#!/usr/local/bin/nim c -r --noMain

import sample_registry

import nimx.view
import nimx.system_logger
import nimx.app
import nimx.scroll_view
import nimx.table_view
import nimx.text_field
import nimx.autotest
import nimx.window

import sequtils
import intsets

import sample01_welcome
import sample02_controls
import sample03_image
import sample04_animation
import sample05_fonts

const isMobile = defined(ios) or defined(android)

template c*(a: string) = discard

proc startApplication() =
    var mainWindow : Window

    when isMobile:
        mainWindow = newFullscreenWindow()
    else:
        mainWindow = newWindow(newRect(40, 40, 800, 600))

    mainWindow.title = "NimX Sample"

    var currentView : View = nil

    let tableView = newTableView(newRect(20, 20, 100, mainWindow.bounds.height - 40))
    tableView.autoresizingMask = { afFlexibleMaxX, afFlexibleHeight }
    mainWindow.addSubview(newScrollView(tableView))

    tableView.numberOfRows = proc: int = allSamples.len
    tableView.createCell = proc (): TableViewCell =
        result = newTableViewCell(newLabel(newRect(0, 0, 100, 20)))
    tableView.configureCell = proc (c: TableViewCell) =
        TextField(c.subviews[0]).text = allSamples[c.row].name
    tableView.onSelectionChange = proc() =
        if not currentView.isNil: currentView.removeFromSuperview()
        let selectedRows = toSeq(items(tableView.selectedRows))
        if selectedRows.len > 0:
            let firstSelectedRow = selectedRows[0]
            currentView = allSamples[firstSelectedRow].view
            currentView.setFrame(newRect(140, 20, mainWindow.bounds.width - 160, mainWindow.bounds.height - 40))
            currentView.autoresizingMask = { afFlexibleWidth, afFlexibleHeight }
            mainWindow.addSubview(currentView)

    tableView.reloadData()
    tableView.selectRow(0)

    uiTest generalUITest:
        sendMouseDownEvent(mainWindow, newPoint(50, 60))
        sendMouseUpEvent(mainWindow, newPoint(50, 60))

        sendMouseDownEvent(mainWindow, newPoint(50, 90))
        sendMouseUpEvent(mainWindow, newPoint(50, 90))

        sendMouseDownEvent(mainWindow, newPoint(50, 120))
        sendMouseUpEvent(mainWindow, newPoint(50, 120))

        sendMouseDownEvent(mainWindow, newPoint(50, 90))
        sendMouseUpEvent(mainWindow, newPoint(50, 90))

        sendMouseDownEvent(mainWindow, newPoint(50, 60))
        sendMouseUpEvent(mainWindow, newPoint(50, 60))

        sendMouseDownEvent(mainWindow, newPoint(50, 30))
        sendMouseUpEvent(mainWindow, newPoint(50, 30))

        when not defined(js):
            quit()

    registerTest(generalUITest)
    when defined(runAutoTests):
        startRegisteredTests()

when defined js:
    import dom
    dom.window.onload = proc (e: dom.Event) =
        startApplication()
else:
    try:
        startApplication()
        runUntilQuit()
    except:
        logi "Exception caught: ", getCurrentExceptionMsg()
        logi getCurrentException().getStackTrace()
