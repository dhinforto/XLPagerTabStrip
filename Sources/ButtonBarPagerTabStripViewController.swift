//  ButtonBarPagerTabStripViewController.swift
//  XLPagerTabStrip ( https://github.com/xmartlabs/XLPagerTabStrip )
//
//  Copyright (c) 2016 Xmartlabs ( http://xmartlabs.com )
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

public struct ButtonBarPagerTabStripSettings {
    
    public struct Style {
        public var buttonBarBackgroundColor: UIColor?
        public var selectedBarBackgroundColor: UIColor?
        
        public var buttonBarItemFont: UIFont = UIFont.boldSystemFontOfSize(18)
        public var buttonBarItemLeftRightMargin: CGFloat = 8
        
        // only used if button bar is created programaticaly and not using storyboards or nib files
        public var buttonBarLeftContentInset: CGFloat?
        public var buttonBarRightContentInset: CGFloat?
        public var buttonBarHeight: CGFloat?
    }
    
    public var style = Style()
}

public class ButtonBarPagerTabStripViewController: PagerTabStripViewController, PagerTabStripViewControllerDataSource, PagerTabStripViewControllerIsProgressiveDelegate, UICollectionViewDelegate, UICollectionViewDataSource {
    
    public var settings = ButtonBarPagerTabStripSettings()
    
    public var changeCurrentIndex: ((oldCell: ButtonBarViewCell?, newCell: ButtonBarViewCell?, animated: Bool) -> Void)?
    public var changeCurrentIndexProgressive: ((oldCell: ButtonBarViewCell?, newCell: ButtonBarViewCell?, progressPercentage: CGFloat, changeCurrentIndex: Bool, animated: Bool) -> Void)?
    
    @IBOutlet public lazy var buttonBarView: ButtonBarView! = { [unowned self] in
        var flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .Horizontal
        flowLayout.sectionInset = UIEdgeInsetsMake(0, self.settings.style.buttonBarLeftContentInset ?? 35, 0, self.settings.style.buttonBarRightContentInset ?? 35)
        
        let buttonBar: ButtonBarView = ButtonBarView(frame: CGRectMake(0, 0, self.view.frame.size.width, self.settings.style.buttonBarHeight ?? 44), collectionViewLayout: flowLayout)
        buttonBar.backgroundColor = .orangeColor()
        buttonBar.selectedBar.backgroundColor = .blackColor()
        buttonBar.autoresizingMask = .FlexibleWidth
        var bundle = NSBundle(forClass: ButtonBarView.self)
        buttonBar.registerNib(UINib(nibName: "ButtonCell", bundle: bundle), forCellWithReuseIdentifier: "Cell")
        var newContainerViewFrame = self.containerView.frame
        newContainerViewFrame.origin.y = 44
        newContainerViewFrame.size.height = self.containerView.frame.size.height - (44 - self.containerView.frame.origin.y)
        self.containerView.frame = newContainerViewFrame
        return buttonBar
    }()
    
    lazy private var cachedCellWidths: [CGFloat]? = { [unowned self] in
        return self.calculateWidths()
    }()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        delegate = self
        datasource = self
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        delegate = self
        datasource = self
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        if buttonBarView.superview == nil {
            view.addSubview(buttonBarView)
        }
        if buttonBarView.delegate == nil {
            buttonBarView.delegate = self
        }
        if buttonBarView.dataSource == nil {
            buttonBarView.dataSource = self
        }
        buttonBarView.scrollsToTop = false
        let flowLayout = buttonBarView.collectionViewLayout as! UICollectionViewFlowLayout
        flowLayout.scrollDirection = .Horizontal
        buttonBarView.showsHorizontalScrollIndicator = false
        
        buttonBarView.backgroundColor = settings.style.buttonBarBackgroundColor ?? buttonBarView.backgroundColor
        buttonBarView.selectedBar.backgroundColor = settings.style.selectedBarBackgroundColor ?? buttonBarView.selectedBar.backgroundColor
        
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        buttonBarView.layoutIfNeeded()
        isViewAppearing = true
    }
    
    public override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        isViewAppearing = false
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard isViewAppearing || isViewRotating else { return }
        
        // Force the UICollectionViewFlowLayout to get laid out again with the new size if
        // a) The view is appearing.  This ensures that
        //    collectionView:layout:sizeForItemAtIndexPath: is called for a second time
        //    when the view is shown and when the view *frame(s)* are actually set
        //    (we need the view frame's to have been set to work out the size's and on the
        //    first call to collectionView:layout:sizeForItemAtIndexPath: the view frame(s)
        //    aren't set correctly)
        // b) The view is rotating.  This ensures that
        //    collectionView:layout:sizeForItemAtIndexPath: is called again and can use the views
        //    *new* frame so that the buttonBarView cell's actually get resized correctly
        cachedCellWidths = calculateWidths()
        buttonBarView.collectionViewLayout.invalidateLayout()
        // When the view first appears or is rotated we also need to ensure that the barButtonView's
        // selectedBar is resized and its contentOffset/scroll is set correctly (the selected
        // tab/cell may end up either skewed or off screen after a rotation otherwise)
        buttonBarView.moveToIndex(currentIndex, animated: false, swipeDirection: .None, pagerScroll: .ScrollOnlyIfOutOfScreen)
    }
    
    // MARK: - View Rotation
    
    public override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        isViewRotating = true
        coordinator.animateAlongsideTransition(nil) { [weak self] _ in
            self?.isViewRotating = false
        }
    }
    
    // MARK: - Public Methods
    
    public override func reloadPagerTabStripView() {
        super.reloadPagerTabStripView()
        guard isViewLoaded() else { return }
        buttonBarView.reloadData()
        cachedCellWidths = calculateWidths()
        buttonBarView.moveToIndex(currentIndex, animated: false, swipeDirection: .None, pagerScroll: .Yes)
    }
    
    public func calculateStretchedCellWidths(minimumCellWidths: [CGFloat], suggestedStretchedCellWidth: CGFloat, previousNumberOfLargeCells: Int) -> CGFloat {
        var numberOfLargeCells = 0
        var totalWidthOfLargeCells: CGFloat = 0
        
        for minimumCellWidthValue in minimumCellWidths {
            if minimumCellWidthValue > suggestedStretchedCellWidth {
                totalWidthOfLargeCells += minimumCellWidthValue
                numberOfLargeCells++
            }
        }
        
        guard numberOfLargeCells > previousNumberOfLargeCells else { return suggestedStretchedCellWidth }
        
        let flowLayout = buttonBarView.collectionViewLayout as! UICollectionViewFlowLayout
        let collectionViewAvailiableWidth = buttonBarView.frame.size.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right
        let numberOfCells = minimumCellWidths.count
        let cellSpacingTotal = CGFloat(numberOfCells - 1) * flowLayout.minimumInteritemSpacing
        
        let numberOfSmallCells = numberOfCells - numberOfLargeCells
        let newSuggestedStretchedCellWidth = (collectionViewAvailiableWidth - totalWidthOfLargeCells - cellSpacingTotal) / CGFloat(numberOfSmallCells)
        
        return calculateStretchedCellWidths(minimumCellWidths, suggestedStretchedCellWidth: newSuggestedStretchedCellWidth, previousNumberOfLargeCells: numberOfLargeCells)
    }
    
    public func pagerTabStripViewController(pagerTabStripViewController: PagerTabStripViewController, updateIndicatorFromIndex fromIndex: Int, toIndex: Int) throws {
        guard shouldUpdateButtonBarView else { return }
        buttonBarView.moveToIndex(toIndex, animated: true, swipeDirection: toIndex < fromIndex ? .Right : .Left, pagerScroll: .Yes)
        
        if let changeCurrentIndex = changeCurrentIndex {
            let oldCell = buttonBarView.cellForItemAtIndexPath(NSIndexPath(forItem: currentIndex != fromIndex ? fromIndex : toIndex, inSection: 0)) as? ButtonBarViewCell
            let newCell = buttonBarView.cellForItemAtIndexPath(NSIndexPath(forItem: currentIndex, inSection: 0)) as? ButtonBarViewCell
            changeCurrentIndex(oldCell: oldCell, newCell: newCell, animated: true)
        }
    }
    
    public func pagerTabStripViewController(pagerTabStripViewController: PagerTabStripViewController, updateIndicatorFromIndex fromIndex: Int, toIndex: Int, withProgressPercentage progressPercentage: CGFloat, indexWasChanged: Bool) throws {
        guard shouldUpdateButtonBarView else { return }
        buttonBarView.moveFromIndex(fromIndex, toIndex: toIndex, progressPercentage: progressPercentage, pagerScroll: .Yes)
        if let changeCurrentIndexProgressive = changeCurrentIndexProgressive {
            let oldCell = buttonBarView.cellForItemAtIndexPath(NSIndexPath(forItem: currentIndex != fromIndex ? fromIndex : toIndex, inSection: 0)) as? ButtonBarViewCell
            let newCell = buttonBarView.cellForItemAtIndexPath(NSIndexPath(forItem: currentIndex, inSection: 0)) as? ButtonBarViewCell
            changeCurrentIndexProgressive(oldCell: oldCell, newCell: newCell, progressPercentage: progressPercentage, changeCurrentIndex: indexWasChanged, animated: true)
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayut
    
    public func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        guard let cellWidthValue = cachedCellWidths?[indexPath.row] else {
            fatalError("cachedCellWidths for \(indexPath.row) must not be nil")
        }
        return CGSizeMake(cellWidthValue, collectionView.frame.size.height)
    }
    
    public func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        guard indexPath.item != currentIndex else { return }
        
        buttonBarView.moveToIndex(indexPath.item, animated: true, swipeDirection: .None, pagerScroll: .Yes)
        shouldUpdateButtonBarView = false
        
        let oldCell = buttonBarView.cellForItemAtIndexPath(NSIndexPath(forItem: currentIndex, inSection: 0)) as! ButtonBarViewCell
        let newCell = buttonBarView.cellForItemAtIndexPath(NSIndexPath(forItem: indexPath.item, inSection: 0)) as! ButtonBarViewCell
        if pagerOptions.contains(.IsProgressiveIndicator) {
            if let changeCurrentIndexProgressive = changeCurrentIndexProgressive {
                changeCurrentIndexProgressive(oldCell: oldCell, newCell: newCell, progressPercentage: 1, changeCurrentIndex: true, animated: true)
            }
        }
        else {
            if let changeCurrentIndex = changeCurrentIndex {
                changeCurrentIndex(oldCell: oldCell, newCell: newCell, animated: true)
            }
        }
        moveToViewControllerAtIndex(indexPath.item)
    }
    
    // MARK: - UICollectionViewDataSource
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewControllers.count
    }
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath) as? ButtonBarViewCell else {
            fatalError("UICollectionViewCell should be or extend from ButtonBarViewCell")
        }
        let childController = viewControllers[indexPath.item] as! PagerTabStripChildItem
        let childInfo = childController.childHeaderForPagerTabStripViewController(self)
        
        configureCell(cell, childInfo: childInfo)
        
        if pagerOptions.contains(.IsProgressiveIndicator) {
            if let changeCurrentIndexProgressive = changeCurrentIndexProgressive {
                changeCurrentIndexProgressive(oldCell: currentIndex == indexPath.item ? nil : cell, newCell: currentIndex == indexPath.item ? cell : nil, progressPercentage: 1, changeCurrentIndex: true, animated: false)
            }
        }
        else {
            if let changeCurrentIndex = changeCurrentIndex {
                changeCurrentIndex(oldCell: currentIndex == indexPath.item ? nil : cell, newCell: currentIndex == indexPath.item ? cell : nil, animated: false)
            }
        }
        
        return cell
    }
    
    // MARK: - UIScrollViewDelegate
    
    public override func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
        super.scrollViewDidEndScrollingAnimation(scrollView)
        
        guard scrollView == containerView else { return }
        shouldUpdateButtonBarView = true
    }
    
    public func configureCell(cell: ButtonBarViewCell, childInfo: ChildItemInfo){
        cell.label.text = childInfo.title
        if let image = childInfo.image {
            cell.imageView.image = image
        }
        if let highlightedImage = childInfo.highlightedImage {
            cell.imageView.highlightedImage = highlightedImage
        }
    }
    
    private func calculateWidths() -> [CGFloat] {
        let flowLayout = self.buttonBarView.collectionViewLayout as! UICollectionViewFlowLayout
        let numberOfCells = self.viewControllers.count
        
        var minimumCellWidths = [CGFloat]()
        var collectionViewContentWidth: CGFloat = 0
        
        for viewController in self.viewControllers {
            let childController = viewController as! PagerTabStripChildItem
            
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = settings.style.buttonBarItemFont
            label.text = childController.childHeaderForPagerTabStripViewController(self).title
            let labelSize = label.intrinsicContentSize()
            
            let minimumCellWidth = labelSize.width + CGFloat(settings.style.buttonBarItemLeftRightMargin * 2)
            minimumCellWidths.append(minimumCellWidth)
            
            collectionViewContentWidth += minimumCellWidth
        }
        
        let cellSpacingTotal = CGFloat(numberOfCells - 1) * flowLayout.minimumInteritemSpacing
        collectionViewContentWidth += cellSpacingTotal
        
        let collectionViewAvailableVisibleWidth = self.buttonBarView.frame.size.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right
        
        if self.buttonBarView.shouldCellsFillAvailiableWidth || collectionViewAvailableVisibleWidth < collectionViewContentWidth {
            return minimumCellWidths
        }
        else {
            let stretchedCellWidthIfAllEqual = (collectionViewAvailableVisibleWidth - cellSpacingTotal) / CGFloat(numberOfCells)
            let generalMinimumCellWidth = self.calculateStretchedCellWidths(minimumCellWidths, suggestedStretchedCellWidth: stretchedCellWidthIfAllEqual, previousNumberOfLargeCells: 0)
            var stretchedCellWidths = [CGFloat]()
            
            for minimumCellWidthValue in minimumCellWidths {
                let cellWidth = (minimumCellWidthValue > generalMinimumCellWidth) ? minimumCellWidthValue : generalMinimumCellWidth
                stretchedCellWidths.append(cellWidth)
            }
            
            return stretchedCellWidths
        }
    }
    
    private var shouldUpdateButtonBarView = true
    private var isViewAppearing = false
    private var isViewRotating = false
}
