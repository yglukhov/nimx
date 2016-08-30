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
import nimx.linear_layout


import sequtils
import intsets

import sample01_welcome
import sample02_controls
import sample03_image
import sample04_animation
import sample05_fonts
import sample06_timers
import sample07_collections
import sample08_events
import sample09_docking_tabs
import sample10_text

const isMobile = defined(ios) or defined(android)

proc startApplication() =
    var mainWindow : Window

    when isMobile:
        mainWindow = newFullscreenWindow()
    else:
        mainWindow = newWindow(newRect(40, 40, 800, 600))

    mainWindow.title = "NimX Sample"

    var currentView = View.new(newRect(0, 0, mainWindow.bounds.width - 100, mainWindow.bounds.height))

    let splitView = newHorizontalLayout(mainWindow.bounds)
    splitView.resizingMask = "wh"
    splitView.userResizeable = true
    mainWindow.addSubview(splitView)

    let tableView = newTableView(newRect(0, 0, 120, mainWindow.bounds.height))
    tableView.resizingMask = "rh"
    splitView.addSubview(newScrollView(tableView))
    splitView.addSubview(currentView)
    splitView.setDividerPosition(120, 0)

    tableView.numberOfRows = proc: int = allSamples.len
    tableView.createCell = proc (): TableViewCell =
        result = newTableViewCell(newLabel(newRect(0, 0, 120, 20)))
    tableView.configureCell = proc (c: TableViewCell) =
        TextField(c.subviews[0]).text = allSamples[c.row].name
    tableView.onSelectionChange = proc() =
        let selectedRows = toSeq(items(tableView.selectedRows))
        if selectedRows.len > 0:
            let firstSelectedRow = selectedRows[0]
            let nv = View(newObjectOfClass(allSamples[firstSelectedRow].className))
            nv.init(currentView.frame)
            nv.resizingMask = "wh"
            splitView.replaceSubview(currentView, nv)
            currentView = nv

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

        quitApplication()

    registerTest(generalUITest)
    when defined(runAutoTests):
        startRegisteredTests()

runApplication:
    startApplication()
