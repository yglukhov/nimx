#!/usr/local/bin/nim c -r --threads:on
import sample_registry

import nimx / [ view, scroll_view, table_view, text_field, layout, autotest, window, split_view ]
import sequtils, intsets

{.warning[UnusedImport]: off.}

import sample01_welcome
import sample02_controls
import sample03_image
import sample04_animation
# import sample15_animation_easings
import sample05_fonts
import sample06_timers
import sample07_collections
import sample08_events
import sample09_docking_tabs
import sample10_text
import sample11_expanded_views
import sample12_menus
import sample13_drag_and_drop
import sample14_layout


const isMobile = defined(ios) or defined(android)

proc startApplication() =
    let mainWindow = when isMobile:
            newFullscreenWindow()
        else:
            newWindow(newRect(40, 40, 800, 600))

    mainWindow.makeLayout:
        title: "NimX Sample"

        - SplitView as splitView:
            origin == super
            size == super

            - ScrollView:
                width >= 80
                width <= super / 3 @ MEDIUM
                - TableView as tableView:

                    # width == 120
                    numberOfRows do() -> int:
                        allSamples.len

                    createCell do() -> TableViewCell:
                        result = TableViewCell.new(zeroRect)
                        result.makeLayout:
                            top == super
                            bottom == super

                            - Label:
                                frame == super
                                width == 200

                    configureCell do(c: TableViewCell):
                        Label(c.subviews[0]).text = allSamples[c.row].name

                    onSelectionChange do():
                        let selectedRows = toSeq(items(tableView.selectedRows))
                        if selectedRows.len > 0:
                            let firstSelectedRow = selectedRows[0]
                            let nv = View(newObjectOfClass(allSamples[firstSelectedRow].className))
                            nv.init(zeroRect)
                            splitView.replaceSubview(1, nv)

            - View: # Placeholder
                discard

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
