#!/usr/local/bin/nim c -r --noMain

import sample_registry

import nimx.view
import nimx.system_logger
import nimx.app
import nimx.scroll_view
import nimx.table_view
import nimx.text_field
import sequtils
import intsets

import sample01_welcome
import sample02_controls
import sample03_image
import sample04_animation


when defined js:
    import nimx.js_canvas_window
    type PlatformWindow = JSCanvasWindow
else:
    import nimx.sdl_window
    type PlatformWindow = SdlWindow

const isMobile = defined(ios) or defined(android)

template c*(a: string) = discard

proc startApplication() =
    var mainWindow : PlatformWindow
    mainWindow.new()

    when isMobile:
        mainWindow.initFullscreen()
    else:
        mainWindow.init(newRect(0, 0, 800, 600))

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

when defined js:
    import dom
    window.onload = proc (e: ref TEvent) =
        startApplication()
        startAnimation()
else:
    try:
        startApplication()
        runUntilQuit()
    except:
        logi "Exception caught: ", getCurrentExceptionMsg()
        logi getCurrentException().getStackTrace()
