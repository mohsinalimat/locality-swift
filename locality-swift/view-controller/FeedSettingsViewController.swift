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
import SDWebImage

class FeedSettingsViewController: LocalityPhotoBaseViewController, CLLocationManagerDelegate, LocationSliderDelegate, ImageUploadViewDelegate, UITableViewDataSource, UITableViewDelegate, UISearchDisplayDelegate, UISearchBarDelegate, UIGestureRecognizerDelegate, UITextFieldDelegate, UIScrollViewDelegate, MGLMapViewDelegate {
    
    @IBOutlet weak var scrollView:UIScrollView!
    @IBOutlet weak var map:MGLMapView!
    @IBOutlet weak var locationName:UITextField!
    @IBOutlet weak var locationNameError:UILabel!
    @IBOutlet weak var slider:LocationSlider!
    @IBOutlet weak var imageUploadView:ImageUploadView!
    @IBOutlet weak var scrollSaveButton:UIButton!
    @IBOutlet weak var scrollDeleteButton:UIButton!
    @IBOutlet weak var scrollDeleteButtonHeight:NSLayoutConstraint!
    @IBOutlet weak var feedOptionsTable:UITableView!
    @IBOutlet weak var feedOptionsHeight:NSLayoutConstraint!
    
    //GeoServices
    var locationManager:CLLocationManager!
    var geocoder:GMSGeocoder!
    var feedOptions:[[String:AnyObject]] = [[String:AnyObject]]()
    
    //Mapbox
    var sliderSteps:[RangeStep] = [RangeStep]()
    var currentRangeIndex:Int!
    var currentLocation:CLLocationCoordinate2D!
    var hasMapped:Bool = false
    
    //AutoComplete
    var searchResults:NSArray! = NSArray()
    var placesClient:GMSPlacesClient!
    var filter:GMSAutocompleteFilter!
    var region:GMSVisibleRegion!
    var bounds:GMSCoordinateBounds!
    
    //UISearchBar
    var shouldBeginEditing:Bool!
    
    //ViewController Mode
    var isEditingFeed:Bool! = false
    var editFeed:FeedLocation?
    var photoHasBeenEdited:Bool = false
    
    //------------------------------------------------------------------------------
    // MARK: - View Lifecycle
    //------------------------------------------------------------------------------
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initViewControllerMode()
        initialSetup()
        
        //populate with feed if editing
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        registerForKeyboardNotifications()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        cancelKeyboardNotifications()
    }
    
    //------------------------------------------------------------------------------
    // MARK: - Initial Setup
    //------------------------------------------------------------------------------
    
    func initViewControllerMode() {
        isEditingFeed = !(editFeed == nil)
    }
    
    func initialSetup() {
        
        initButtons()
        initLocationName()
        initHeaderView()
        initAutoCompleteSearch()
        initFeedOptionsTable()
        initScrollView()
        initRangeSlider()
        initMap()
        initImageUploadView()
    }
    
    func initButtons() {
    
        if isEditingFeed == true {
            scrollSaveButton.setTitle(K.String.Feed.UpdateFeedLabel.localized, for: .normal)
            scrollSaveButton.addTarget(self, action: #selector(updateLocationDidTouch), for: .touchUpInside)
            
            scrollDeleteButton.setTitle(K.String.Feed.DeleteFeedLabel.localized, for: .normal)
            scrollDeleteButton.addTarget(self, action: #selector(deleteLocationDidTouch), for: .touchUpInside)
        }
        
        else {
            scrollSaveButton.setTitle(K.String.Feed.SaveFeedLabel.localized, for: .normal)
            scrollSaveButton.addTarget(self, action: #selector(saveLocationDidTouch), for: .touchUpInside)
            
            scrollDeleteButtonHeight.constant = 0
            scrollSaveButton.setNeedsUpdateConstraints()
        }
    }
    
    func initLocationName() {
        
        if !isEditingFeed {
            locationName.placeholder = K.String.Feed.FeedNameDefault.localized
        } else {
            locationName.text = editFeed?.name
        }
        
        locationName.delegate = self
        locationNameError.text?.removeAll()
    }
    
    func initHeaderView() {
        
        header.initHeaderViewStage()
        header.initAttributes(title: isEditingFeed == true ? K.String.Header.EditLocationHeader.localized : K.String.Header.AddNewLocationHeader.localized,
                              leftType: .back,
                              rightType: .none)
        
        view.addSubview(header)
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

        if isEditingFeed == true {
            scrollView.contentInset = UIEdgeInsetsMake(0, 0, 10, 0)
        } else {
            scrollView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0)
        }
        
        scrollView.delegate = self
    }
    
    func initRangeSlider() {

        sliderSteps = slider.initSlider()
        slider.delegate = self
        
        if isEditingFeed == true {
            let editRange = (editFeed?.range)!
            slider.setStep(range:CGFloat(editRange))
        }
        currentRangeIndex = slider.currentStep
    }
    
    func initMap() {
        
        map.showsUserLocation = false
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let localityStyleURL = K.Mapbox.MapStyle
        map.styleURL = URL(string:localityStyleURL)
        map.delegate = self
        
        if isEditingFeed == true {
            
            currentLocation = CLLocationCoordinate2D(latitude: (editFeed?.lat)!,
                                                     longitude: (editFeed?.lon)!)
            
            if hasMapped == false {
                map.setCenter(currentLocation, animated:false)
                updateMapRange()
                hasMapped = true
            }
            
            sliderValueChanged(step: currentRangeIndex)
        }
        
        else {
            
            //Start polling
            locationManager = CLLocationManager()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestWhenInUseAuthorization()
            
            if CLLocationManager.locationServicesEnabled() {
                locationManager.startUpdatingLocation()
            }
        }
        
        bindMapGestures()
    }
    
    func bindMapGestures() {
        
        let singleTap:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleMapSingleTap))
        singleTap.delegate = self
        map.addGestureRecognizer(singleTap)
    }
    
    func initImageUploadView() {
        if isEditingFeed == true {
            //load image
            if editFeed?.feedImgUrl != K.Image.DefaultFeedHero {
                let iv:UIImageView = UIImageView(frame:CGRect(origin:CGPoint.zero, size:imageUploadView.frame.size))
                iv.sd_setImage(with: URL(string:(editFeed?.feedImgUrl)!), completed: { (img, error, type, url) in
                    
                    if img != nil {
                        self.imageUploadView.setLocationImage(image: img!)
                    }
                })
                
            }
        }
        
        imageUploadView.delegate = self
    }
    
    //------------------------------------------------------------------------------
    // MARK: - Data & API
    //------------------------------------------------------------------------------
    
    func writeLocation(url:String) {
        let thisLocation:FeedLocation = FeedLocation(coord: self.currentLocation,
                                                     name: locationName.text!,
                                                     range: Float(sliderSteps[currentRangeIndex].distance),
                                                     current: false)
        
        thisLocation.feedImgUrl = url
        
        for op in self.feedOptionsTable.visibleCells {
            
            let c = op as! FeedSettingsToggleCell
            
            if c.data["var"] as! String == K.String.Feed.Setting.PushEnabled {
                thisLocation.pushEnabled = c.settingsSwitch.isOn
            }
                
            else if c.data["var"] as! String == K.String.Feed.Setting.PromotionsEnabled {
                thisLocation.promotionsEnabled = c.settingsSwitch.isOn
            }
        }
        
        GoogleMapsManager.reverseGeocode(coord: currentLocation) { (address, error) in
            
            if error != nil {
                thisLocation.location = "Location Unknown"
            }
            
            else
            {
                thisLocation.location = Util.locationLabel(address: address!)
            }
            
            //save to current
            CurrentUser.shared.pinnedLocations.append(thisLocation)
            
            FirebaseManager.write(pinnedLocations:CurrentUser.shared.pinnedLocations, completionHandler: { (error) in
                if error != nil {
                    print("Locations Write Error: \(String(describing: error?.localizedDescription))")
                }
                    
                else {
                    print("Location written")
                    SlideNavigationController.sharedInstance().popViewController(animated: true)
                }
            })
        }
    }
    
    func updateLocation(url:String) {
        
        //Update edit feed
        editFeed?.lat = self.currentLocation.latitude
        editFeed?.lon = self.currentLocation.longitude
        editFeed?.name = locationName.text!
        editFeed?.range = Float(sliderSteps[currentRangeIndex].distance)
        editFeed?.feedImgUrl = url
        
        for op in self.feedOptionsTable.visibleCells {
            
            let c = op as! FeedSettingsToggleCell
            
            if c.data["var"] as! String == K.String.Feed.Setting.PushEnabled {
                editFeed?.pushEnabled = c.settingsSwitch.isOn
            }
                
            else if c.data["var"] as! String == K.String.Feed.Setting.PromotionsEnabled {
                editFeed?.promotionsEnabled = c.settingsSwitch.isOn
            }
        }
        
        //check if the map has been changed
        if Util.pointsEqual(currentLocation, CLLocationCoordinate2D(latitude:(editFeed?.lat)!, longitude:(editFeed?.lon)!)) {
            
            //We do not need to call reverseGeocode
            //save to current
            
            for i in 0...CurrentUser.shared.pinnedLocations.count - 1 {
                if CurrentUser.shared.pinnedLocations[i].locationId == editFeed?.locationId {
                    CurrentUser.shared.pinnedLocations[i] = editFeed!
                }
            }
            
            FirebaseManager.write(pinnedLocations:CurrentUser.shared.pinnedLocations, completionHandler: { (error) in
                if error != nil {
                    print("Locations Write Error: \(String(describing: error?.localizedDescription))")
                }
                    
                else {
                    print("Location written")
                    SlideNavigationController.sharedInstance().popViewController(animated: true)
                }
            })
        }
        
        else {
            GoogleMapsManager.reverseGeocode(coord: currentLocation) { (address, error) in
                
                if error != nil {
                    self.editFeed?.location = "Location Unknown"
                }
                    
                else
                {
                    self.editFeed?.location = Util.locationLabel(address: address!)
                }
                
                //save to current
                for i in 0...CurrentUser.shared.pinnedLocations.count - 1 {
                    if CurrentUser.shared.pinnedLocations[i].locationId == self.editFeed?.locationId {
                        CurrentUser.shared.pinnedLocations[i] = self.editFeed!
                    }
                }
                
                FirebaseManager.write(pinnedLocations:CurrentUser.shared.pinnedLocations, completionHandler: { (error) in
                    if error != nil {
                        print("Locations Update Error: \(String(describing: error?.localizedDescription))")
                    }
                        
                    else {
                        print("Location updated")
                        SlideNavigationController.sharedInstance().popViewController(animated: true)
                    }
                })
            }
        }
    }
    
    func deleteLocation(_ loc:FeedLocation) {
    
        for (i, pinned) in CurrentUser.shared.pinnedLocations.enumerated() {
            if pinned.locationId == loc.locationId {
                CurrentUser.shared.pinnedLocations.remove(at: i)
            }
        }
        
        FirebaseManager.write(pinnedLocations:CurrentUser.shared.pinnedLocations, completionHandler: { (error) in
            if error != nil {
                print("Locations Delete Error: \(String(describing: error?.localizedDescription))")
            }
                
            else {
                print("Location deleted")
                SlideNavigationController.sharedInstance().popViewController(animated: true)
            }
        })
    }
    
    func writePhotoToStorage() {
        PhotoUploadManager.uploadPhoto(image: imageUploadView.getImage(), type: .location, uid: CurrentUser.shared.uid) { (metadata, error) in
            
            if error != nil {
                print("Upload Error: \(String(describing: error?.localizedDescription))")
            }
                
            else {
                let downloadURL = metadata!.downloadURL()!.absoluteString
                
                if self.isEditingFeed == true {
                    self.updateLocation(url: downloadURL)
                } else {
                    self.writeLocation(url:downloadURL)
                }
            }
        }
    }
    
    //------------------------------------------------------------------------------
    // MARK: - CTA Methods
    //------------------------------------------------------------------------------
    
    func saveLocationDidTouch(sender:UIButton) {
        
        if (locationName.text?.isEmpty)! {
            locationNameError.text = K.String.Feed.FeedNameError.localized
            return
        }
        
        if !imageUploadView.hasImage() {
            writeLocation(url: K.Image.DefaultFeedHero)
        }
            
        else {
            writePhotoToStorage()
        }
    }
    
    func updateLocationDidTouch(sender:UIButton) {
        
        if (locationName.text?.isEmpty)! {
            locationNameError.text = K.String.Feed.FeedNameError.localized
            return
        }
        
        if !imageUploadView.hasImage() {
            updateLocation(url: K.Image.DefaultFeedHero)
        }
            
        else {
            if photoHasBeenEdited == true || editFeed?.feedImgUrl == K.Image.DefaultFeedHero {
                writePhotoToStorage()
            }
            
            else {
                updateLocation(url: (editFeed?.feedImgUrl)!)
            }
        }
    }
    
    func deleteLocationDidTouch(sender:UIButton) {
        
        alertDelete()
    }
    
    func handleMapSingleTap(tap:UITapGestureRecognizer) {
        currentLocation = map.convert(tap.location(in: map), toCoordinateFrom: map)
        updateMapRange()
    }
    
    //------------------------------------------------------------------------------
    // MARK: - AlertView Methods
    //------------------------------------------------------------------------------
    
    func alertDelete() {
    
        showAlertView(title: K.String.Alert.Title.DeleteLocation.localized,
                      message: K.String.Alert.Message.DeleteLocation.localized,
                      close: K.String.Alert.Close.No.localized,
                      action: K.String.Alert.Action.Yes.localized)
    }
    
    override func tappedAction() {
    
        deleteLocation(editFeed!)
        alertView.closeAlert()
    }
    
    //------------------------------------------------------------------------------
    // MARK: - CLLocationManagerDelegate Methods
    //------------------------------------------------------------------------------
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    
        if status == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location:CLLocation = locations[0]
        currentLocation = location.coordinate
        
        if hasMapped == false {
            map.setCenter(currentLocation, animated:false)
            updateMapRange()
            hasMapped = true
        }
        
        locationManager.stopUpdatingLocation()
    }
    
    func updateMapRange() {
        
        if let annotations = map.annotations {
            for ann in annotations {
                map.removeAnnotation(ann)
            }
        }
        
        map.centerCoordinate = currentLocation
        let currentRadius:Double = Util.radiusInMeters(range: Float(sliderSteps[currentRangeIndex].distance))
        
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
    
    //------------------------------------------------------------------------------
    // MARK: - ImageUploadViewDelegate Methods
    //------------------------------------------------------------------------------
    
    func takePhotoTapped() {
        takePhoto()
    }
    
    func uploadPhotoTapped() {
        selectPhoto()
    }
    
    func selectedPhotoHasBeenRemoved() {
        
        if isEditingFeed == true {
            photoHasBeenEdited = true
        }
    }
    
    override func imageCropViewController(_ controller: RSKImageCropViewController, didCropImage croppedImage: UIImage, usingCropRect cropRect: CGRect, rotationAngle: CGFloat) {
        
        imageUploadView.setLocationImage(image: croppedImage)
        dismiss(animated: true, completion:nil)
        
    }
    
    //------------------------------------------------------------------------------
    // MARK: - LocationRangeSliderDelegate Methods
    //------------------------------------------------------------------------------
    
    func sliderValueChanged(step: Int) {
    
        currentRangeIndex = step
        updateMapRange()
    }
    
    //------------------------------------------------------------------------------
    // MARK: - GooglePlaces Methods
    //------------------------------------------------------------------------------
    
    func getDetailsWithPlaceID(placeId:String) {
        placesClient.lookUpPlaceID(placeId) { (place, error) in
            if error != nil {
                print("Place Details Error: \(String(describing: error?.localizedDescription))")
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
    
    //------------------------------------------------------------------------------
    // MARK: - UIScrollViewDelegate Methods
    //------------------------------------------------------------------------------s
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        scrollView.bounces = scrollView.contentOffset.y > 20
        
        if searchDisplayController?.searchBar.isFirstResponder == false {
            searchDisplayController?.searchBar.alpha = ((searchDisplayController?.searchBar.frame.size.height)! - scrollView.contentOffset.y)/(searchDisplayController?.searchBar.frame.size.height)!
        }
        
        if searchDisplayController?.searchBar.isFirstResponder == true {
            searchDisplayController?.searchBar.alpha = 1.0
        }
    }
    
    //------------------------------------------------------------------------------
    // MARK: - KeyboardNotifications Methods
    //------------------------------------------------------------------------------
    
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
        
        //We only wish to do this for the locationName
        if !locationName.isFirstResponder {
            return
        }
        
        let info:[String:AnyObject] = notification.userInfo as! [String : AnyObject]
        
        var keyboardFrame:CGRect = (info[UIKeyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        keyboardFrame = self.view.convert(keyboardFrame, from: nil)
        
        let locOrigin:CGPoint = locationName.frame.origin
        let locHeight:CGFloat = locationName.frame.size.height
        
        var visibleRect:CGRect = scrollView.frame
        
        visibleRect.size.height -= (keyboardFrame.size.height)
        
        if visibleRect.contains(locOrigin) == false {
            let scrollPoint:CGPoint = CGPoint(x:0.0, y:keyboardFrame.size.height - locOrigin.y - locHeight)
            
            scrollView.setContentOffset(scrollPoint, animated: true)
        }
        
    }
    
    func keyboardWillHide(notification:Notification) {
        scrollView.setContentOffset(CGPoint.zero, animated: true)
    }
    
    //------------------------------------------------------------------------------
    // MARK: - MGLMapViewDelegate Methods
    //------------------------------------------------------------------------------
    
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

    //------------------------------------------------------------------------------
    // MARK: - UITextFieldDelegate Methods
    //------------------------------------------------------------------------------
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        locationNameError.text?.removeAll()
        
        if locationName.text == K.String.Feed.FeedNameDefault.localized {
            locationName.text?.removeAll()
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        if locationName.text?.isEmpty == true {
            locationName.text = K.String.Feed.FeedNameDefault.localized
        }
    }
    
    //------------------------------------------------------------------------------
    // MARK: - UITableViewDataSource Methods
    //------------------------------------------------------------------------------
    
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
    
    //------------------------------------------------------------------------------
    // MARK: - UITableViewDelegate Methods
    //------------------------------------------------------------------------------
   
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == feedOptionsTable {
            let toggleCell:FeedSettingsToggleCell = tableView.dequeueReusableCell(withIdentifier: K.ReuseID.FeedSettingsToggleCellID, for: indexPath) as! FeedSettingsToggleCell
            
            toggleCell.populate(data: feedOptions[indexPath.row])

            if isEditingFeed == true {
                if toggleCell.data["var"] as! String == K.String.Feed.Setting.PushEnabled {
                    toggleCell.settingsSwitch.setOn((editFeed?.pushEnabled)!, animated: false)
                }
                    
                else if toggleCell.data["var"] as! String == K.String.Feed.Setting.PromotionsEnabled {
                    toggleCell.settingsSwitch.setOn((editFeed?.promotionsEnabled)!, animated: false)
                }
            }
            
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
            getDetailsWithPlaceID(placeId: placeAtIndexPath(indexPath: indexPath).placeID!)
            dismissSearchControllerWhileStayingActive()
            shouldBeginEditing = false
            searchDisplayController?.isActive = false
        }
    }
    
    //------------------------------------------------------------------------------
    // MARK: - GMSPlacesDelegate Methods
    //------------------------------------------------------------------------------
    
    func placeAtIndexPath(indexPath:IndexPath) -> GMSAutocompletePrediction {
        return searchResults.object(at: indexPath.row) as! GMSAutocompletePrediction
    }
    
    //------------------------------------------------------------------------------
    // MARK: - UISearchDisplayDelegate Methods
    //------------------------------------------------------------------------------
    
    func searchDisplayController(_ controller: UISearchDisplayController, shouldReloadTableForSearch searchString: String?) -> Bool {
        placesClient.autocompleteQuery(searchString!, bounds: bounds, filter: filter) { (results, error) in
            
            if error != nil {
                print("Autocomplete error: \(String(describing: error?.localizedDescription))")
                return
            }
            
            self.searchResults = results as NSArray!
            self.searchDisplayController?.searchResultsTableView.reloadData()
        }
        
        return true
    }
    
    func dismissSearchControllerWhileStayingActive() {
        let dur:TimeInterval = 0.3
        
        UIView.animate(withDuration: dur, animations: { 
            self.searchDisplayController?.searchResultsTableView.alpha = 0
        }) { (success) in
            self.searchDisplayController?.searchBar.setShowsCancelButton(false, animated: true)
            self.searchDisplayController?.searchBar.resignFirstResponder()
        }
    }
    
    override func slideNavigationControllerShouldDisplayLeftMenu() -> Bool {
        return false
    }
}
