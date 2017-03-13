//
//  FeedSettingsViewController.swift
//  locality-swift
//
//  Created by Chelsea Power on 3/12/17.
//  Copyright © 2017 Brian Maci. All rights reserved.
//

import UIKit
import GoogleMaps
import GooglePlaces
import Mapbox

class FeedSettingsViewController: LocalityPhotoBaseViewController, CLLocationManagerDelegate, LocationSliderDelegate, UITableViewDataSource, UITableViewDelegate, UISearchDisplayDelegate, UISearchBarDelegate, UIGestureRecognizerDelegate, UITextFieldDelegate, UIScrollViewDelegate, MGLMapViewDelegate {
    
    @IBOutlet weak var scrollView:UIScrollView!
    @IBOutlet weak var scrollContentHeight:NSLayoutConstraint!
    
    @IBOutlet weak var map:MGLMapView!
    
    @IBOutlet weak var locationName:UITextField!
    @IBOutlet weak var locationNameContainer:UIView!
    
    @IBOutlet weak var slider:LocationSlider!
    
    @IBOutlet weak var imageUploadView:ImageUploadView!
    
    @IBOutlet weak var scrollSaveButton:UIButton!
    @IBOutlet weak var scrollButtonContainer:UIView!
    
    @IBOutlet weak var feedOptionsTable:UITableView!
    @IBOutlet weak var feedOptionsHeight:NSLayoutConstraint!
    
    var locationManager:CLLocationManager!
    var geocoder:GMSGeocoder!
    var feedOptions:[[String:AnyObject]] = [[String:AnyObject]]()
    
    var sliderSteps:[RangeStep]!

    var currentRangeIndex:Int!
    var currentLocation:CLLocationCoordinate2D!
    
    var searchResults:NSArray! = NSArray()
    var placesClient:GMSPlacesClient!
    var filter:GMSAutocompleteFilter!
    var region:GMSVisibleRegion!
    var bounds:GMSCoordinateBounds!
    
    var shouldBeginEditing:Bool!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initText()
        initHeaderView()
        initLocationName()
        initAutoCompleteSearch()
        initFeedOptionsTable()
        initScrollView()
        initMap()
        initRangeSlider()
        initImageUploadView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        registerForKeyboardNotifications()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        cancelKeyboardNotifications()
    }
    
    func initText() {
        locationName.placeholder = K.String.Feed.FeedNameDefault.localized
        scrollSaveButton.setTitle(K.String.Feed.SaveFeedLabel.localized, for: .normal)
        
    }
    
    func initHeaderView() {
        header.initHeaderViewStage()
        header.initAttributes(title: K.String.Header.AddNewLocationHeader.localized,
                              leftType: .back,
                              rightType: .close)
        
        view.addSubview(header)
    }
    
    func initLocationName() {
        locationName.delegate = self
    }
    
    func initAutoCompleteSearch() {
        let font:UIFont = UIFont(name: K.FontName.InterstateLightCondensed, size: 16.0)!
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).font = font
        
        placesClient = GMSPlacesClient()
        
        let mglBounds:MGLCoordinateBounds = map.visibleCoordinateBounds
        bounds = GMSCoordinateBounds(coordinate: mglBounds.ne, coordinate: mglBounds.sw)
        
        filter = GMSAutocompleteFilter()
        filter.type = .geocode
        
    }
    
    func initFeedOptionsTable() {
        feedOptions = Util.getPListArray(name: K.PList.FeedOptions)
        
        feedOptionsTable.register(UINib(nibName: K.NIBName.FeedSettingsToggleCell, bundle: nil), forCellReuseIdentifier: K.ReuseID.FeedSettingsToggleCellID)
        feedOptionsTable.delegate = self
        feedOptionsTable.dataSource = self
        
        feedOptionsHeight.constant = K.NumberConstant.Feed.FeedOptionHeight * CGFloat(feedOptions.count)
        feedOptionsTable.reloadData()
    }
    
    func initScrollView() {
        var contentHeight:CGFloat = 0.0
        
        contentHeight += (searchDisplayController?.searchBar.frame.size.height)!
        contentHeight += map.frame.size.height
        contentHeight += slider.frame.size.height
        contentHeight += locationNameContainer.frame.size.height
        contentHeight += imageUploadView.frame.size.height
        contentHeight += scrollButtonContainer.frame.size.height
        contentHeight += K.NumberConstant.Feed.FeedBottomPadding
        
        scrollContentHeight.constant = contentHeight
        scrollView.contentSize = CGSize(width: K.Screen.Width, height: contentHeight)
        
        scrollView.delegate = self
    }
    
    func initRangeSlider() {
        
        sliderSteps = [RangeStep]()
        
        let stepsArray = Util.getPList(name: K.PList.RangeValuesFeet)["Steps"] as! [AnyObject]
        
        for i in 0...stepsArray.count-1 {
            
            let step:RangeStep = RangeStep(distance: stepsArray[i]["distance"] as! CGFloat,
                                           label:stepsArray[i]["label"] as! String,
                                           unit:stepsArray[i]["unit"] as! String)
            
            sliderSteps.append(step)
        }
        
        slider.initSliderWith(range: sliderSteps)
        slider.delegate = self
        
        //set currentIndex to default of slider
        currentRangeIndex = slider.currentStep
    }
    
    func initMap() {
        
        //Start polling
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
        
        map.showsUserLocation = false
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        //init light style
        let localityStyleURL = K.Mapbox.MapStyle
        map.styleURL = URL(string:localityStyleURL)
        
        map.delegate = self
        
        bindMapGestures()
    }
    
    func bindMapGestures() {
        
        let doubleTap:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: nil)
        doubleTap.numberOfTapsRequired = 2
        map.addGestureRecognizer(doubleTap)
        
        let singleTap:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleMapSingleTap))
        singleTap.require(toFail: doubleTap)
        singleTap.delegate = self
        map.addGestureRecognizer(singleTap)
    }
    
    func initImageUploadView() {
        //imageUploadView.delegate = self
    }
    
    /// MARK : - CLLocationManagerDelegate Methods
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location:CLLocation = locations[0]
        currentLocation = location.coordinate
        
        DispatchQueue.once {
            map.setCenter(currentLocation, animated: false)
            updateMapRange()
        }
        
        locationManager.stopUpdatingLocation()
        
    }
    
    func updateMapRange() {
        
        //remove all annotations first
        if let annotations = map.annotations {
            for ann in annotations {
                map.removeAnnotation(ann)
            }
        }
        
        map.centerCoordinate = currentLocation
        let currentRadius:Double = Double(sliderSteps[currentRangeIndex].distance/2)
        
        let rangePointSW:CLLocationCoordinate2D = MapboxManager.metersToDegrees(coord: map.centerCoordinate, metersLat: -currentRadius, metersLong: -currentRadius)
        
        let rangePointNE:CLLocationCoordinate2D = MapboxManager.metersToDegrees(coord: map.centerCoordinate, metersLat: currentRadius, metersLong: currentRadius)
        
        let bounds = MGLCoordinateBoundsMake(rangePointSW, rangePointNE)
        map.setVisibleCoordinateBounds(bounds, edgePadding: UIEdgeInsets.init(top: 20, left: 20, bottom: 20, right: 20), animated: false)
        
        let rangeCircle = MapboxManager.polygonCircleForCoordinate(coordinate: map.centerCoordinate,
                                                                   meterRadius: currentRadius)
        map.add(rangeCircle)
        
        let rangeMarker = CustomPointAnnotation()
        rangeMarker.coordinate = map.centerCoordinate
        rangeMarker.markerType = K.Mapbox.Marker.Type.Range
        map.addAnnotation(rangeMarker)
    }
    
    /// MARK : - ImageUploadViewDelegate Methods
    
    //These both go through the action sheet flow that checks for camera access
    
//    - (void) takePhotoTapped {
//    [self checkCameraAccess];
//    }
//    
//    - (void) uploadPhotoTapped {
//    [self checkCameraAccess];
//    }
    
    /// MARK : - MGLMapViewDelegate Methods
    
    func handleMapSingleTap(tap:UITapGestureRecognizer) {
        currentLocation = map.convert(tap.location(in: map), toCoordinateFrom: map)
        updateMapRange()
        
        print("map tapped")
    }
    
   /// MARK : - LocationRangeSliderDelegate Methods
    func sliderValueChanged(step: Int) {
        currentRangeIndex = step
        updateMapRange()
    }
    
    /// MARK : - GooglePlaceID Methods
    func getDetailsWithPlaceID(placeId:String) {
        placesClient.lookUpPlaceID(placeId) { (place, error) in
            if error != nil {
                print("Place Details Error: \(error?.localizedDescription)")
            }
            
            if place != nil {
                self.updateMap(place:(place?.coordinate)!)
            }
            
            else {
                print("No places for this placeID")
            }
        }
    }
    
    func updateMap(place:CLLocationCoordinate2D) {
        currentLocation = place
        updateMapRange()
    }
    

    /// MARK : - UIScrollViewDelegate Methods
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollView.bounces = scrollView.contentOffset.y > 20
        
        if searchDisplayController?.searchBar.isFirstResponder == false {
            searchDisplayController?.searchBar.alpha = ((searchDisplayController?.searchBar.frame.size.height)! - scrollView.contentOffset.y)/(searchDisplayController?.searchBar.frame.size.height)!
        }
        
        if searchDisplayController?.searchBar.isFirstResponder == true {
            searchDisplayController?.searchBar.alpha = 1.0
        }
    }
    
    ///MARK : - Keyboard Notification Methods
    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(keyboardWillShow),
                                               name: .UIKeyboardDidShow,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(keyboardWillHide),
                                               name:.UIKeyboardWillHide,
                                               object:nil)
        
    }
    
    func cancelKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self,
                                                  name: .UIKeyboardDidShow,
                                                  object: nil)
        
        NotificationCenter.default.removeObserver(self,
                                                   name:.UIKeyboardWillHide,
                                                   object:nil)
        
    }
   
    func keyboardWillShow(notification:Notification) {
        let info:[String:AnyObject] = notification.userInfo as! [String : AnyObject]
        
        let keyboardSize = info[UIKeyboardFrameBeginUserInfoKey]?.cgSizeValue
        
        let locOrigin:CGPoint = locationName.frame.origin
        let locHeight:CGFloat = locationName.frame.size.height
        
        var visibleRect:CGRect = scrollView.frame
        
        visibleRect.size.height -= (keyboardSize?.height)!
        
        if visibleRect.contains(locOrigin) == false {
            let scrollPoint:CGPoint = CGPoint(x:0.0, y:keyboardSize!.height - locOrigin.y - locHeight)
            
            scrollView.setContentOffset(scrollPoint, animated: true)
        }
        
    }
    
    func keyboardWillHide(notification:Notification) {
        scrollView.setContentOffset(CGPoint.zero, animated: true)
    }
    
    /// MARK: - MGLMapViewDelegate Methods
    func mapView(_ mapView: MGLMapView, alphaForShapeAnnotation annotation: MGLShape) -> CGFloat {
        return 0.2
    }
    
    private func mapView(mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        return UIColor.clear
    }
    
    func mapView(_ mapView: MGLMapView, fillColorForPolygonAnnotation annotation: MGLPolygon) -> UIColor {
        return K.Color.localityMapAccent
    }
    
    private func mapView(mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    
    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
        
        let thisMarker = annotation as! CustomPointAnnotation
        
        switch thisMarker.markerType {
            
        case K.Mapbox.Marker.Type.Range:
            let img = UIImage(named: K.Mapbox.Marker.Image.Range)
            let mglImg = MGLAnnotationImage(image: img!, reuseIdentifier: K.Mapbox.Marker.Type.Range)
            mglImg.accessibilityFrame = CGRect(x:0, y:0, width:(img?.size.width)!, height:(img?.size.height)!)
            return mglImg
            
        default:
            return MGLAnnotationImage(image: UIImage(), reuseIdentifier: "")
        }
    }

    ///MARK : - UITextFieldDelegate Methods
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    ///MARK : - UITableViewDataSource Methods
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if tableView == feedOptionsTable {
            return feedOptions.count
        }
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return K.NumberConstant.Feed.FeedOptionHeight
    }
   
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == feedOptionsTable {
            let toggleCell:FeedSettingsToggleCell = tableView.dequeueReusableCell(withIdentifier: K.ReuseID.FeedSettingsToggleCellID, for: indexPath) as! FeedSettingsToggleCell
            
            toggleCell.populate(data: feedOptions[indexPath.row])
            
            return toggleCell
        }
        
        else {
            var searchCell:UITableViewCell?
            
            searchCell = tableView.dequeueReusableCell(withIdentifier: K.ReuseID.PlacesSearchCellID)
            
            if searchCell == nil {
                searchCell = UITableViewCell(style: .default, reuseIdentifier: K.ReuseID.PlacesSearchCellID)
            }
            
            searchCell?.textLabel?.font = UIFont(name: K.FontName.InterstateLightCondensed, size: 16.0)
            searchCell?.textLabel?.text = placeAtIndexPath(indexPath: indexPath).attributedFullText.string
            return searchCell!
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if tableView != feedOptionsTable {
            print("SELECTED! \(indexPath.row)")
            getDetailsWithPlaceID(placeId: placeAtIndexPath(indexPath: indexPath).placeID!)
            dismissSearchControllerWhileStayingActive()
            shouldBeginEditing = false
            searchDisplayController?.isActive = false
        }
    }
    
    ///MARK : - GMSPlacesDelegate Methods
    
    func placeAtIndexPath(indexPath:IndexPath) -> GMSAutocompletePrediction {
        return searchResults.object(at: indexPath.row) as! GMSAutocompletePrediction
    }
    
    ///MARK : - UISearchDisplayDelegate Methods
    func searchDisplayController(_ controller: UISearchDisplayController, shouldReloadTableForSearch searchString: String?) -> Bool {
        placesClient.autocompleteQuery(searchString!, bounds: bounds, filter: filter) { (results, error) in
            
            if error != nil {
                print("Autocomplete error: \(error?.localizedDescription)")
                return
            }
            
            self.searchResults = results as NSArray!
            self.searchDisplayController?.searchResultsTableView.reloadData()
        }
        
        return true
    }
    
//    searchDisplayController
//    - (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
//    [self handleSearchForSearchString:searchString];
//
//    // Return YES to cause the search result table view to be reloaded.
//    return YES;
//    }
//    
//    #pragma mark -
//    #pragma mark UISearchBar Delegate
//
//    - (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
//    if (![searchBar isFirstResponder]) {
//    // User tapped the 'clear' button.
//    shouldBeginEditing = NO;
//    [self.searchDisplayController setActive:NO];
//    //[self.mapView removeAnnotation:selectedPlaceAnnotation];
//    }
//    }
//    
//    - (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
//    if (shouldBeginEditing) {
//    // Animate in the table view.
//    //        NSTimeInterval animationDuration = 0.3;
//    //        [UIView beginAnimations:nil context:NULL];
//    //        [UIView setAnimationDuration:animationDuration];
//    //        self.searchDisplayController.searchResultsTableView.alpha = 1.0;
//    //        [UIView commitAnimations];
//    //
//    //        [self.searchDisplayController.searchBar setShowsCancelButton:YES animated:YES];
//    
//    }
//    
//    BOOL boolToReturn = shouldBeginEditing;
//    shouldBeginEditing = YES;
//    return boolToReturn;
//    }
//    

    
    func dismissSearchControllerWhileStayingActive() {
        let dur:TimeInterval = 0.3
        
        UIView.animate(withDuration: dur, animations: { 
            self.searchDisplayController?.searchResultsTableView.alpha = 0
        }) { (success) in
            self.searchDisplayController?.searchBar.setShowsCancelButton(false, animated: true)
            self.searchDisplayController?.searchBar.resignFirstResponder()
        }
    }

    
    
//    #pragma mark - Save New Location Feed
//    
//    -(IBAction)saveLocationTapped:(id)sender {
//    
//    //upload photo
//    
//    if( _imageUploadView.selectedPhoto.image ) {
//    [PhotoUploadManager uploadPhoto:_imageUploadView.selectedPhoto.image ofType:LocationFeedPhoto success:^(id response) {
//    NSLog(@"URL: %@", response);
//    [self createFeedModelWithImageUrl:response];
//    
//    } failure:^(NSError *error) {
//    NSLog(@"Picture Upload failure: %@", error);
//    }];
//    }
//    
//    else {
//    //they have no image to upload... use default
//    [self createFeedModelWithImageUrl:DEFAULT_FEED_IMAGE];
//    }
//    }
//    
//    -(void)createFeedModelWithImageUrl:(NSString *)url {
//    
//    FeedLocationModel *newFeed = [[FeedLocationModel alloc] initWithLocation:_currentLocation andName:_locationName.text];
//    
//    newFeed.imgUrl = url;
//    newFeed.range = _currentRange;
//    
//    newFeed.pushEnabled = YES;
//    newFeed.promotionsEnabled = YES;
//    newFeed.importantEnabled = YES;
//    
//    //reverse geolocate to get location
//    [GoogleMapsManager reverseGeocodeCoordinate:CLLocationCoordinate2DMake(newFeed.latitude, newFeed.longitude) success:^(id response) {
//    // we got the address
//    GMSAddress *address = (GMSAddress *)response;
//    //NSLog(@"address? %@", address);
//    
//    newFeed.location = [AppUtilities locationLabelFromAddress:address];
//    
//    [self saveFeedModel:newFeed];
//    
//    } failure:^(NSError *error) {
//    NSLog(@"error retrieving address: %@", error);
//    //do nothing
//    [self saveFeedModel:newFeed];
//    }];
//    }
//    
//    -(void)saveFeedModel:(FeedLocationModel *)newFeed {
//    
//    [ParseManager addNewPinnedLocation:newFeed success:^(id response) {
//    NSLog(@"Pinned Location added!");
//    
//    //go back
//    [self.navigationController popViewControllerAnimated:YES];
//    
//    } failure:^(NSError *error) {
//    NSLog(@"Pinned Location add fail: %@", error);
//    }];
//    }
//    
//    #pragma mark - RSKImageCropper Override
//    
//    -(void)imageCropViewController:(RSKImageCropViewController *)controller didCropImage:(UIImage *)croppedImage usingCropRect:(CGRect)cropRect {
//    [super imageCropViewController:controller didCropImage:croppedImage usingCropRect:cropRect];
//    
//    [_imageUploadView setLocationImage:croppedImage];
//    [self.navigationController popViewControllerAnimated:YES];
//    }

    


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
