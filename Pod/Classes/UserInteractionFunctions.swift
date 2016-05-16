//
//  UserInteractionFunctions.swift
//  Pods
//
//  Created by Jay Thomas on 2016-05-12.
//
//


extension JTAppleCalendarView {
    /// Returns the cellStatus of a date that is visible on the screen. If the row and column for the date cannot be found, then nil is returned
    /// - Paramater row: Int row of the date to find
    /// - Paramater column: Int column of the date to find
    /// - returns:
    ///     - CellState: The start date of the current section
    public func cellStatusForDateAtRow(row: Int, column: Int) -> CellState? {
        if // the row or column falls within an invalid range
            row < 0 || row >= numberOfRowsPerMonth ||
                column < 0 || column >= MAX_NUMBER_OF_DAYS_IN_WEEK {
            return nil
        }
        
        let Offset: Int
        let convertedRow: Int
        let convertedSection: Int
        if direction == .Horizontal {
            Offset = Int(round(calendarView.contentOffset.x / (calendarView.collectionViewLayout as! JTAppleCalendarLayoutProtocol).itemSize.width))
            convertedRow = (row * MAX_NUMBER_OF_DAYS_IN_WEEK) + ((column + Offset) % MAX_NUMBER_OF_DAYS_IN_WEEK)
            convertedSection = (Offset + column) / MAX_NUMBER_OF_DAYS_IN_WEEK
        } else {
            Offset = Int(round(calendarView.contentOffset.y / (calendarView.collectionViewLayout as! JTAppleCalendarLayoutProtocol).itemSize.height))
            convertedRow = ((row * MAX_NUMBER_OF_DAYS_IN_WEEK) +  column + (Offset * MAX_NUMBER_OF_DAYS_IN_WEEK)) % (MAX_NUMBER_OF_DAYS_IN_WEEK * numberOfRowsPerMonth)
            convertedSection = (Offset + row) / numberOfRowsPerMonth
        }
        
        let indexPathToFind = NSIndexPath(forItem: convertedRow, inSection: convertedSection)
        if let  date = dateFromPath(indexPathToFind) {
            let stateOfCell = cellStateFromIndexPath(indexPathToFind, withDate: date)
            return stateOfCell
        }
        return nil
    }
    
    /// Change the number of rows per month on the calendar view. Once the row count is changed, the calendar view will auto-focus on the date provided. The calendarView will also reload its data.
    /// - Parameter number: The number of rows per month the calendar view should display. This is restricted to 1, 2, 3, & 6. 6 will be chosen as default.
    public func changeNumberOfRowsPerMonthTo(number: Int, withFocusDate date: NSDate?) {
        self.scrollToDatePathOnRowChange = date
        switch number {
        case 1, 2, 3:
            numberOfRowsPerMonth = number
        default:
            numberOfRowsPerMonth = 6
        }
        configureChangeOfRows()
    }

    
    /// Returns the calendar view's current section boundary dates.
    /// - returns:
    ///     - startDate: The start date of the current section
    ///     - endDate: The end date of the current section
    public func currentCalendarSegment() -> (startDate: NSDate, endDate: NSDate)? {
        if monthInfo.count < 1 {
            return nil
        }
        
        let section = currentSectionPage
        let monthData = monthInfo[section]
        let itemLength = monthData[NUMBER_OF_DAYS_INDEX]
        let fdIndex = monthData[FIRST_DAY_INDEX]
        let startIndex = NSIndexPath(forItem: fdIndex, inSection: section)
        let endIndex = NSIndexPath(forItem: fdIndex + itemLength - 1, inSection: section)
        
        if let theStartDate = dateFromPath(startIndex), theEndDate = dateFromPath(endIndex) {
            return (theStartDate, theEndDate)
        }
        return nil
    }
    
    
    /// Let's the calendar know which cell xib to use for the displaying of it's date-cells.
    /// - Parameter name: The name of the xib of your cell design
    @available(*, deprecated=3.0, message="Since 3.0. Use registerCellViewXib") public func registerCellViewXib(fileName name: String) {
        cellViewXibName = name
    }
    
    /// Register header views with the calender. This needs to be done before the view can be displayed
    /// - Parameter fileNames: A dictionary containing [headerViewNames:HeaderviewSizes]
    public func registerHeaderViewXibs(fileNames headerViewXibNames: [String]) {
        if headerViewXibNames.count < 1 {
            headerViewXibs.removeAll()
            return
        }

        for headerViewXibName in headerViewXibNames {
            
            let viewObject = NSBundle.mainBundle().loadNibNamed("SectionHeaderView", owner: self, options: [:])
            assert(viewObject.count > 0, "your nib file name \(headerViewXibName) could not be loaded)")
            
            guard let view = viewObject[0] as? JTAppleHeaderView else {
                assert(false, "xib file class does not conform to the protocol<JTAppleHeaderViewProtocol>")
                return
            }
            
            
            headerViewXibs.append(headerViewXibName)
            
            self.calendarView.registerClass(JTAppleCollectionReusableView.self,
                                            forSupplementaryViewOfKind: UICollectionElementKindSectionHeader,
                                            withReuseIdentifier: headerViewXibName)
        }
        
        
        setupHeaderViews(nil)
    }
    
    /// Reloads the data on the calendar view
    public func reloadData() {
        reloadData(true)
    }
    
    /// Select a date-cell if it is on screen
    /// - Parameter date: The date-cell with this date will be selected
    /// - Parameter triggerDidSelectDelegate: Triggers the delegate function only if the value is set to true. Sometimes it is necessary to setup some dates without triggereing the delegate e.g. For instance, when youre initally setting up data in your viewDidLoad
    public func selectDates(dates: [NSDate], triggerSelectionDelegate: Bool = true) {
        delayRunOnMainThread(0.0) {
            guard let validCachedCalendar = self.calendar else {
                return
            }
            
            var allIndexPathsToReload: [NSIndexPath] = []
            for date in dates {
                let components = validCachedCalendar.components([.Year, .Month, .Day],  fromDate: date)
                let firstDayOfDate = validCachedCalendar.dateFromComponents(components)!
                
                if !(firstDayOfDate >= self.startOfMonthCache && firstDayOfDate <= self.endOfMonthCache) {
                    // If the date is not within valid boundaries, then exit
                    continue
                }
                
                let pathFromDates = self.pathsFromDates([date])
                
                // If the date path youre searching for, doesnt exist, then return
                if pathFromDates.count < 0 {
                    continue
                }
                
                let sectionIndexPath = pathFromDates[0]
                allIndexPathsToReload.append(sectionIndexPath)
                let selectTheDate = {
                    if self.selectedIndexPaths.contains(sectionIndexPath) == false { // Can contain the value already if the user selected the same date twice.
                        self.selectedDates.append(date)
                        self.selectedIndexPaths.append(sectionIndexPath)
                    }
                    self.calendarView.selectItemAtIndexPath(sectionIndexPath, animated: false, scrollPosition: .None)
                    
                    // If triggereing is enabled, then let their delegate handle the reloading of view, else we will reload the data
                    if triggerSelectionDelegate {
                        self.collectionView(self.calendarView, didSelectItemAtIndexPath: sectionIndexPath)
                    }
                }
                
                let deSelectTheDate = { (indexPath: NSIndexPath) -> Void in
                    self.calendarView.deselectItemAtIndexPath(indexPath, animated: false)
                    if
                        self.selectedIndexPaths.contains(indexPath),
                        let index = self.selectedIndexPaths.indexOf(indexPath) {
                        
                        self.selectedIndexPaths.removeAtIndex(index)
                        self.selectedDates.removeAtIndex(index)
                    }
                    if triggerSelectionDelegate {
                        self.collectionView(self.calendarView, didDeselectItemAtIndexPath: indexPath)
                    }
                }
                
                // Remove old selections
                if self.calendarView.allowsMultipleSelection == false { // If single selection is ON
                    for indexPath in self.selectedIndexPaths {
                        if indexPath != sectionIndexPath {
                            deSelectTheDate(indexPath)
                        }
                    }
                    
                    // Add new selections
                    // Must be added here. If added in delegate didSelectItemAtIndexPath
                    selectTheDate()
                } else { // If multiple selection is on. Multiple selection behaves differently to singleselection. It behaves like a toggle.
                    
                    if self.selectedIndexPaths.contains(sectionIndexPath) { // If this cell is already selected, then deselect it
                        deSelectTheDate(sectionIndexPath)
                    } else {
                        // Add new selections
                        // Must be added here. If added in delegate didSelectItemAtIndexPath
                        selectTheDate()
                    }
                }
            }
            
            // If triggering was false, although the selectDelegates weren't called, we do want the cell refreshed. Reload to call itemAtIndexPath
            if triggerSelectionDelegate == false {
                self.calendarView.reloadItemsAtIndexPaths(allIndexPathsToReload)
            }
        }
    }
    
    /// Scrolls the calendar view to the next section view. It will execute a completion handler at the end of scroll animation if provided.
    /// - Paramater animateScroll: Bool indicating if animation should be enabled
    /// - Parameter completionHandler: A completion handler that will be executed at the end of the scroll animation
    public func scrollToNextSegment(animateScroll: Bool = true, completionHandler:(()->Void)? = nil) {
        let page = currentSectionPage
        if page + 1 < monthInfo.count {
            let position: UICollectionViewScrollPosition = self.direction == .Horizontal ? .Left : .Top
            calendarView.scrollToItemAtIndexPath(NSIndexPath(forItem: 0, inSection:page + 1), atScrollPosition: position, animated: animateScroll)
        }
    }
    /// Scrolls the calendar view to the previous section view. It will execute a completion handler at the end of scroll animation if provided.
    /// - Paramater animateScroll: Bool indicating if animation should be enabled
    /// - Parameter completionHandler: A completion handler that will be executed at the end of the scroll animation
    public func scrollToPreviousSegment(animateScroll: Bool = true, completionHandler:(()->Void)? = nil) {
        let page = currentSectionPage
        if page - 1 > -1 {
            let position: UICollectionViewScrollPosition = self.direction == .Horizontal ? .Left : .Top
            calendarView.scrollToItemAtIndexPath(NSIndexPath(forItem: 0, inSection:page - 1), atScrollPosition: position, animated: animateScroll)
        }
    }
    
    /// Scrolls the calendar view to the start of a section view containing a specified date.
    /// - Paramater date: The calendar view will scroll to a date-cell containing this date if it exists
    /// - Paramater animateScroll: Bool indicating if animation should be enabled
    /// - Parameter completionHandler: A completion handler that will be executed at the end of the scroll animation
    public func scrollToDate(date: NSDate, animateScroll: Bool = true, completionHandler:(()->Void)? = nil) {
        guard let validCachedCalendar = calendar else {
            return
        }
        
        let components = validCachedCalendar.components([.Year, .Month, .Day],  fromDate: date)
        let firstDayOfDate = validCachedCalendar.dateFromComponents(components)!
        
        if !(firstDayOfDate >= startOfMonthCache && firstDayOfDate <= endOfMonthCache) {
            return
        }
        
        let retrievedPathsFromDates = pathsFromDates([date])
        
        if retrievedPathsFromDates.count > 0 {
            let sectionIndexPath =  pathsFromDates([date])[0]
            delayedExecutionClosure = completionHandler
//            let segmentToScrollTo = pagingEnabled ? NSIndexPath(forItem: 0, inSection: sectionIndexPath.section) : sectionIndexPath
            
            let position: UICollectionViewScrollPosition = self.direction == .Horizontal ? .Left : .Top
            delayRunOnMainThread(0.0, closure: {
                
                if self.pagingEnabled {
                    if headerViewXibs.count > 0 {
                        // If both paging and header is on, then scroll to the actual date
                        self.scrollToHeaderForDate(date)
                    } else {
                        // If paging is on and header is off, then scroll to the start date in section
                        self.calendarView.scrollToItemAtIndexPath(NSIndexPath(forItem: 0,
                            inSection: sectionIndexPath.section),
                            atScrollPosition: position, animated: animateScroll
                        )
                    }
                } else {
                    // If paging is off, then scroll to the actual date in the section
                    self.calendarView.scrollToItemAtIndexPath(sectionIndexPath,
                        atScrollPosition: position,
                        animated: animateScroll
                    )
                }
                
                if  !animateScroll {
                    self.scrollViewDidEndScrollingAnimation(self.calendarView)
                }
            })
        }
    }
    
    /// Scrolls the calendar view to the start of a section view header. If the calendar has no headers registered, then this function does nothing
    /// - Paramater date: The calendar view will scroll to the header of a this provided date
    public func scrollToHeaderForDate(date: NSDate) {
        // Return if sections are not registered
        if headerViewXibs.count < 1 { return }
        let path = pathsFromDates([date])
        // Return if date was incalid and no path was returned
        if path.count < 1 { return }
        scrollToHeaderInSection(path[0].section)
    }
}