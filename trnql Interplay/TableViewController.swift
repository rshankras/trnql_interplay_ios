//
//  TableViewController.swift
//  trnql Interplay
//
//  Created by Jonathan Sahoo on 8/12/15.
//  Copyright (c) 2015 trnql. All rights reserved.
//

import UIKit
import trnql
import CoreLocation

extension NSDate {
    func hoursFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(NSCalendarUnit.Hour, fromDate: date, toDate: self, options: []).hour
    }
    func minutesFrom(date:NSDate) -> Int{
        return NSCalendar.currentCalendar().components(NSCalendarUnit.Minute, fromDate: date, toDate: self, options: []).minute
    }
}

class TableViewController: UITableViewController, TrnqlDelegate {

    @IBOutlet weak var locationImageIcon: UIImageView!
    @IBOutlet weak var currentAddressLabel: UILabel!
    @IBOutlet weak var saveLocationPromptLabel: UILabel!
    @IBOutlet weak var savePlaceButtonsContainerView: UIView!
    @IBOutlet weak var resetSavedLocationButton: UIButton!
    
    @IBOutlet weak var keyboardInputTextField: UITextField!
    @IBOutlet weak var textInputTypeImageIcon: UIImageView!
    
    @IBOutlet weak var temperatureImageIcon: UIImageView!
    @IBOutlet weak var temperatureLabel: UILabel!
    
    @IBOutlet weak var restaurantNameLabel: UILabel!
    @IBOutlet weak var restaurantDistanceLabel: UILabel!
    @IBOutlet weak var foodImageLeft: UIImageView!
    @IBOutlet weak var foodImageRight: UIImageView!
    @IBOutlet weak var foodImageCenter: UIImageView!
    @IBOutlet weak var restaurantAddressLabel: UILabel!
    

    @IBOutlet weak var poiNameLabel: UILabel!
    @IBOutlet weak var poiDistanceLabel: UILabel!
    @IBOutlet weak var gasImageLeft: UIImageView!
    @IBOutlet weak var gasImageRight: UIImageView!
    @IBOutlet weak var gasImageCenter: UIImageView!
    @IBOutlet weak var poiAddressLabel: UILabel!
    
    @IBOutlet weak var numberOfPlacesFound: UIButton!
    
    @IBOutlet weak var sunriseSunsetTimeLabel: UILabel!
    
    let trnql = Trnql.sharedInstance
    let googleAPIKey = "INSERT_YOUR_KEY_HERE" // You can register for a free Google API Key here: https://console.developers.google.com
    
    var currentAddress: AddressEntry?
    var currentLocation: LocationEntry?
    var currentActivity: ActivityEntry?
    var currentWeather: WeatherEntry?
    var currentRestaurant: PlaceEntry?
    var currentOtherPOI: PlaceEntry?
    var currentPlaces: [PlaceEntry]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        trnql.setAPIKey("INSERT_YOUR_KEY_HERE") // You can register for a trnql API Key here: http://appserver.trnql.com:9090/developer_dashboard/dashboard.jsp
        
        let backItem = UIBarButtonItem(title: "Back", style: UIBarButtonItemStyle.Plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backItem
        
        currentAddressLabel.text = "Updating location..."
        temperatureLabel.text = "Updating weather..."
        sunriseSunsetTimeLabel.text = "Updating weather..."
        
        let imageCornerRadius:CGFloat = 10
        foodImageLeft.layer.cornerRadius = imageCornerRadius
        foodImageCenter.layer.cornerRadius = imageCornerRadius
        foodImageRight.layer.cornerRadius = imageCornerRadius
        gasImageLeft.layer.cornerRadius = imageCornerRadius
        gasImageCenter.layer.cornerRadius = imageCornerRadius
        gasImageRight.layer.cornerRadius = imageCornerRadius
        
        restaurantNameLabel.text = "Searching for places..."
        restaurantDistanceLabel.text = ""
        foodImageLeft.hidden = true
        foodImageCenter.hidden = true
        foodImageRight.hidden = true
        poiNameLabel.text = "Searching for places..."
        poiDistanceLabel.text = ""
        gasImageLeft.hidden = true
        gasImageCenter.hidden = true
        gasImageRight.hidden = true
        
        navigationController?.navigationBar.translucent = false
        
        trnql.delegate = self
        trnql.setIncludingPlaceImages(true)
        trnql.setPlaceTypeFilters([.RESTAURANT, .GAS_STATION, .ATM, .GROCERY_OR_SUPERMARKET, .PARKING, .PARK])
        trnql.startAllServices() // Starts all services
        
        updateLocationBanner(UIImage(named: "earth")!)
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: Selector("reloadData"), forControlEvents: UIControlEvents.ValueChanged)
        
        updateLocationCardUI(nil)
        updateActivityCardUI(nil)
        updateWeatherCardUIs(nil)
        
    }
    
//    override func viewDidAppear(animated: Bool) {
//        
//        if !NSUserDefaults.standardUserDefaults().boolForKey("hasDisplayedSplashScreen") {
//            
//            if let vc = self.storyboard?.instantiateViewControllerWithIdentifier("SplashScreen") {
//                self.presentViewController(vc, animated: true, completion: nil)
//            }
//        }
//    }
    
    func reloadData() {
        trnql.stopAllServices()
        trnql.startAllServices()
        self.refreshControl?.endRefreshing()
    }
    
    func updateLocationCardUI(address: AddressEntry?) {
        
        dispatch_async(dispatch_get_main_queue(), {
            if let address = address?.getAddress() {
                
                let homeAddress = (NSUserDefaults.standardUserDefaults().objectForKey("homeAddress") as? String) ?? ""
                let workAddress = (NSUserDefaults.standardUserDefaults().objectForKey("workAddress") as? String) ?? ""
                
                if address == homeAddress {
                    self.currentAddressLabel.text = "Home Sweet Home.\n\(address)"
                    self.locationImageIcon.image = UIImage(named: "home")
                    self.promptToSaveAddress(false)
                }
                else if address == workAddress {
                    self.currentAddressLabel.text = "You are at work. Stop slacking off!\n\(address)"
                    self.locationImageIcon.image = UIImage(named: "work")
                    self.promptToSaveAddress(false)
                }
                else {
                    self.currentAddressLabel.text = "You are currently at: \(address)"
                    self.locationImageIcon.image = UIImage(named: "placemark")
                    self.promptToSaveAddress(true)
                }
            }
            else {
                self.currentAddressLabel.text = "Location unknown"
                self.locationImageIcon.image = UIImage(named: "placemark")
                self.promptToSaveAddress(false)
            }
            
            if let lat = address?.getLat(), lon = address?.getLng() {
                
                let numberOfAPICalls = NSUserDefaults.standardUserDefaults().integerForKey("numberOfAPICalls")
                if numberOfAPICalls > 2 { // If there have already been 2 calls, check if sufficient time has passed to allow another API call
                    
                    if let timeOfLastAPICall = NSUserDefaults.standardUserDefaults().objectForKey("timeOfLastAPICall") as? NSDate {
                        
                        if NSDate().timeIntervalSinceDate(timeOfLastAPICall) > 120 {
                            self.updateLocationBanner(lat, lon)
                            NSUserDefaults.standardUserDefaults().setInteger(0, forKey: "numberOfAPICalls")
                            NSUserDefaults.standardUserDefaults().setObject(NSDate(), forKey: "timeOfLastAPICall")
                        }
                    }
                    else {
                        NSUserDefaults.standardUserDefaults().setObject(NSDate(), forKey: "timeOfLastAPICall")
                    }
                }
                else {
                    self.updateLocationBanner(lat, lon)
                    NSUserDefaults.standardUserDefaults().setInteger(numberOfAPICalls + 1, forKey: "numberOfAPICalls")
                    NSUserDefaults.standardUserDefaults().setObject(NSDate(), forKey: "timeOfLastAPICall")
                }

            }
            
            if let locality = address?.getLocality() {
                self.title = "You are in \(locality)"
            }
            
            self.tableView.reloadData()
        })
    }
    
    func updateLocationBanner(lat: String, _ lon: String) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), {
            
            if let image = self.getStreetViewImage(lat, lon) {
                self.updateLocationBanner(image)
            }
            else if let image = self.getPlacesImage(lat, lon) {
                self.updateLocationBanner(image)
            }
        })
    }
    
    func updateLocationBanner(image: UIImage) {
        
        dispatch_async(dispatch_get_main_queue(), {
            
            let width = UIScreen.mainScreen().bounds.width
            let imageHeight = width/1.866666667
            let imageView = UIImageView(frame: CGRectMake(0, 0, width, imageHeight))
            imageView.contentMode = UIViewContentMode.ScaleAspectFill
            imageView.clipsToBounds = true
            imageView.image = image
            self.tableView.tableHeaderView = imageView
            self.tableView.reloadData()
        })
    }
    
    func getStreetViewImage(lat: String, _ lon: String) -> UIImage? {
        
        let streetMapsUrl = "https://maps.googleapis.com/maps/api/streetview?size=400x400&location=\(lat),\(lon)&key=\(googleAPIKey)&fov=90&heading=150&pitch=10"
        if let data = NSData(contentsOfURL: NSURL(string: streetMapsUrl)!) {
            // The Google Street View Image API will return a placeholder image stating "Sorry we have no imagery here" if no images are available. This placeholder image is around 5000 bytes but has fluctuated slightly. Real place images are much larger. To be safe we are making sure that the image received is at least 7500 bytes which would indiciate that it most likely is a real place image.
            if data.length > 7500 {
                return UIImage(data: data)
            }
        }
        return nil
    }
    
    func getPlacesImage(lat: String, _ lon: String) -> UIImage? {
        
        let placesURL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(lat),\(lon)&radius=500&key=\(googleAPIKey)"

        if let data = NSData(contentsOfURL: NSURL(string: placesURL)!) {
            
            let json = JSON(data: data)
            if let places = json["results"].array where places.count > 0 {

                for place in places {

                    if let photos = place["photos"].array where photos.count > 0 {
                        if let reference = photos[0]["photo_reference"].string {
                            
                            let photoURL = "https://maps.googleapis.com/maps/api/place/photo?maxwidth=500&photoreference=\(reference)&key=\(googleAPIKey)"
                            if let imageData = NSData(contentsOfURL: NSURL(string: photoURL)!), image = UIImage(data: imageData) {
                                return image
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
    
    func promptToSaveAddress(b: Bool) {
        
        if b {
            saveLocationPromptLabel.hidden = false
            savePlaceButtonsContainerView.hidden = false
            resetSavedLocationButton.hidden = true
        }
        else {
            saveLocationPromptLabel.hidden = true
            savePlaceButtonsContainerView.hidden = true
            resetSavedLocationButton.hidden = false
        }
    }
    
    func updateActivityCardUI(activityEntry: ActivityEntry?) {
        
        dispatch_async(dispatch_get_main_queue(), {
            if let activityEntry = activityEntry {
                
                if activityEntry.isStill() || activityEntry.isOnFoot() {
                    self.keyboardInputTextField.placeholder = "Keyboard Input Enabled (User is \(activityEntry.getActivityString()))"
                    self.textInputTypeImageIcon.image = UIImage(named: "keyboard")
                    self.keyboardInputTextField.enabled = true
                }
                else {
                    self.keyboardInputTextField.placeholder = "Keyboard Input Disabled (User is \(activityEntry.getActivityString()))"
                    self.textInputTypeImageIcon.image = UIImage(named: "microphone")
                    self.keyboardInputTextField.enabled = false
                }
            }
            else {
                
                self.keyboardInputTextField.placeholder = "Keyboard Input Enabled (User Activity Unknown)"
                self.textInputTypeImageIcon.image = UIImage(named: "keyboard")
                self.keyboardInputTextField.enabled = true
            }
            
            self.tableView.reloadData()
        })
    }
    
    func updateWeatherCardUIs(weatherEntry: WeatherEntry?) {

        dispatch_async(dispatch_get_main_queue(), {
            if let weatherEntry = weatherEntry {
                
                // Temperature Card
                if let temp = weatherEntry.getFeelsLikeTemp() {
                    
                    if temp >= 85 {
                        self.temperatureLabel.text = "It's hot, hot!"
                        self.temperatureImageIcon.image = UIImage(named: "fire")
                    }
                    else if temp >= 75 {
                        self.temperatureLabel.text = "It's nice out!"
                        self.temperatureImageIcon.image = UIImage(named: "sun")
                    }
                    else if temp >= 70 {
                        self.temperatureLabel.text = "It's neither hot nor cold"
                        self.temperatureImageIcon.image = UIImage(named: "thermometer")
                    }
                    else if temp >= 58 {
                        self.temperatureLabel.text = "It's cold enough to wear a sweater"
                        self.temperatureImageIcon.image = UIImage(named: "sweater")
                    }
                    else if temp >= 40 {
                        self.temperatureLabel.text = "It's cold enough to wear a jacket"
                        self.temperatureImageIcon.image = UIImage(named: "jacket")
                    }
                    else if temp > 32 {
                        self.temperatureLabel.text = "Baby it's cold outside!"
                        self.temperatureImageIcon.image = UIImage(named: "snowflake")
                    }
                    else {
                        self.temperatureLabel.text = "It's freezing (literally)!"
                        self.temperatureImageIcon.image = UIImage(named: "snowflake")
                    }
                }
                else {
                    self.temperatureLabel.text = "The temperature is unknown"
                    self.temperatureImageIcon.image = UIImage(named: "thermometer")
                }
                
                // Determine sunrise/sunset time
                if let sunrise = weatherEntry.getSunriseTime(), sunset = weatherEntry.getSunsetTime() {
                    
                    let now = NSDate()
                    let calendar = NSCalendar.currentCalendar()
                    
                    if sunrise.compare(now) == NSComparisonResult.OrderedDescending {
                        let timeRemaining = calendar.components([NSCalendarUnit.Hour, NSCalendarUnit.Minute], fromDate: now, toDate: sunrise, options: [])
                        self.sunriseSunsetTimeLabel.text = "\(timeRemaining.hour) \(timeRemaining.hour != 1 ? "Hours" : "Hour"), \(timeRemaining.minute) \(timeRemaining.minute != 1 ? "Minutes" : "Minute") Until Sunrise"
                    }
                    else if sunrise.compare(now) == NSComparisonResult.OrderedSame{
                        self.sunriseSunsetTimeLabel.text = "The sunrise is now!"
                    }
                    else if sunset.compare(now) == NSComparisonResult.OrderedDescending {
                        let timeRemaining = calendar.components([NSCalendarUnit.Hour, NSCalendarUnit.Minute], fromDate: now, toDate: sunset, options: [])
                        self.sunriseSunsetTimeLabel.text = "\(timeRemaining.hour) \(timeRemaining.hour != 1 ? "Hours" : "Hour"), \(timeRemaining.minute) \(timeRemaining.minute != 1 ? "Minutes" : "Minute") Until Sunset"
                    }
                    else if sunset.compare(now) == NSComparisonResult.OrderedSame{
                        self.sunriseSunsetTimeLabel.text = "The sunset is now!"
                    }
                    else if sunset.compare(now) == NSComparisonResult.OrderedAscending {
                        if let sunsetTime = weatherEntry.getSunsetAsString() {
                            self.sunriseSunsetTimeLabel.text = "The sunset was at \(sunsetTime)."
                        }
                        else {
                            self.sunriseSunsetTimeLabel.text = "The sunset has passed."
                        }
                    }
                }
            }
            else {
                self.temperatureLabel.text = "The temperature is unknown"
                self.sunriseSunsetTimeLabel.text = "Sunrise/sunset time is unknown"
            }
            
            
            self.tableView.reloadData()
        })
    }
    
    func updatePlaceCardUIs(places: [PlaceEntry]) {
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
            
            if places.count > 0 {
                
                self.numberOfPlacesFound.setTitle("Found \(places.count) Places Nearby", forState: .Normal)
                
                
                var restaurants = [PlaceEntry]()
                var otherPOIs = [PlaceEntry]()
                
                for place in places {
                    
                    
                    if let types = place.getTypes() {
                        if types.contains(PlaceType.RESTAURANT) {
                            restaurants.append(place)
                        }
                        else {
                            otherPOIs.append(place)
                        }
                    }
                }
                
                // RESTAURANT
                if restaurants.count > 0 {
                    
                    var restaurant: PlaceEntry?
                    var numOfRestaurantPhotos = 0
                    
                    var numberOfPhotosRequired = 2
                    repeat {
                        
                        if numberOfPhotosRequired > 0 {
                            
                            for theRestaurant in restaurants {
                                
                                let numOfPhotos = theRestaurant.getImages() != nil ? theRestaurant.getImages()!.count : 0
                                if numOfPhotos >= numberOfPhotosRequired {
                                    restaurant = theRestaurant
                                    numOfRestaurantPhotos = numOfPhotos
                                    break
                                }
                            }
                            numberOfPhotosRequired--
                        }
                        else {
                            restaurant = restaurants[Int(arc4random_uniform(UInt32(restaurants.count)))]
                            numOfRestaurantPhotos = 0
                        }
                    } while restaurant == nil
                    
                    if let restaurant = restaurant {
                        
                        self.currentRestaurant = restaurant
                        
                        if numOfRestaurantPhotos > 0 {
                            
                            let photos = restaurant.getImages()!
                            if numOfRestaurantPhotos > 1 {
                                
                                let randomPhotoIndex1 = Int(arc4random_uniform(UInt32(photos.count)))
                                var randomPhotoIndex2: Int
                                repeat {
                                    randomPhotoIndex2 = Int(arc4random_uniform(UInt32(photos.count)))
                                } while randomPhotoIndex1 == randomPhotoIndex2
                                
                                let photo1 = photos[randomPhotoIndex1]
                                let photo2 = photos[randomPhotoIndex2]
                                
                                dispatch_async(dispatch_get_main_queue(), {
                                    self.restaurantNameLabel.text = restaurant.getName() ?? ""
                                    self.restaurantDistanceLabel.text = self.calculateDistance(restaurant) ?? ""
                                    self.restaurantAddressLabel.text = restaurant.getAddress() ?? ""
                                    self.foodImageCenter.hidden = true
                                    self.foodImageLeft.hidden = false
                                    self.foodImageRight.hidden = false
                                    self.foodImageLeft.image = photo1
                                    self.foodImageRight.image = photo2
                                    self.tableView.reloadData()
                                })
                            }
                            else {
                                
                                let randomPhotoIndex1 = Int(arc4random_uniform(UInt32(photos.count)))
                                let photo1 = photos[randomPhotoIndex1]
                                
                                dispatch_async(dispatch_get_main_queue(), {
                                    self.restaurantNameLabel.text = restaurant.getName() ?? ""
                                    self.restaurantDistanceLabel.text = self.calculateDistance(restaurant) ?? ""
                                    self.restaurantAddressLabel.text = restaurant.getAddress() ?? ""
                                    self.foodImageCenter.hidden = false
                                    self.foodImageLeft.hidden = true
                                    self.foodImageRight.hidden = true
                                    self.foodImageCenter.image = photo1
                                    self.tableView.reloadData()
                                })
                            }
                        }
                        else {
                            
                            dispatch_async(dispatch_get_main_queue(), {
                                self.restaurantNameLabel.text = restaurant.getName() ?? ""
                                self.restaurantDistanceLabel.text = self.calculateDistance(restaurant) ?? ""
                                self.restaurantAddressLabel.text = restaurant.getAddress() ?? ""
                                self.foodImageCenter.hidden = false
                                self.foodImageLeft.hidden = true
                                self.foodImageRight.hidden = true
                                self.foodImageCenter.image = nil
                                self.tableView.reloadData()
                            })
                        }
                    }
                }
                else {
                    
                    dispatch_async(dispatch_get_main_queue(), {
                        self.restaurantNameLabel.text = "Searching for places..."
                        self.restaurantDistanceLabel.text = ""
                        self.restaurantAddressLabel.text = ""
                        self.foodImageCenter.hidden = true
                        self.foodImageLeft.hidden = true
                        self.foodImageRight.hidden = true
                        self.tableView.reloadData()
                    })
                }
                
                // GAS STATION
                if otherPOIs.count > 0 {
                    
                    var otherPOI: PlaceEntry?
                    var numOfOtherPOIPhotos = 0
                    
                    var numberOfPhotosRequired = 2
                    repeat {
                        
                        if numberOfPhotosRequired > 0 {
                            
                            for thePOI in otherPOIs {
                                
                                let numOfPhotos = thePOI.getImages() != nil ? thePOI.getImages()!.count : 0
                                if numOfPhotos >= numberOfPhotosRequired {
                                    otherPOI = thePOI
                                    numOfOtherPOIPhotos = numOfPhotos
                                    break
                                }
                            }
                            numberOfPhotosRequired--
                        }
                        else {
                            otherPOI = otherPOIs[Int(arc4random_uniform(UInt32(otherPOIs.count)))]
                            numOfOtherPOIPhotos = 0
                        }
                    } while otherPOI == nil
                    
                    if let poi = otherPOI {
                        
                        self.currentOtherPOI = poi
                        
                        if numOfOtherPOIPhotos > 0 {
                            
                            let photos = poi.getImages()!
                            if numOfOtherPOIPhotos > 1 {
                                
                                let randomPhotoIndex1 = Int(arc4random_uniform(UInt32(photos.count)))
                                var randomPhotoIndex2: Int
                                repeat {
                                    randomPhotoIndex2 = Int(arc4random_uniform(UInt32(photos.count)))
                                } while randomPhotoIndex1 == randomPhotoIndex2
                                
                                let photo1 = photos[randomPhotoIndex1]
                                let photo2 = photos[randomPhotoIndex2]
                                
                                dispatch_async(dispatch_get_main_queue(), {
                                    self.poiNameLabel.text = poi.getName() ?? ""
                                    self.poiDistanceLabel.text = self.calculateDistance(poi) ?? ""
                                    self.poiAddressLabel.text = poi.getAddress() ?? ""
                                    self.gasImageCenter.hidden = true
                                    self.gasImageLeft.hidden = false
                                    self.gasImageRight.hidden = false
                                    self.gasImageLeft.image = photo1
                                    self.gasImageRight.image = photo2
                                    self.tableView.reloadData()
                                })
                            }
                            else {
                                
                                let randomPhotoIndex1 = Int(arc4random_uniform(UInt32(photos.count)))
                                let photo1 = photos[randomPhotoIndex1]
                                
                                dispatch_async(dispatch_get_main_queue(), {
                                    self.poiNameLabel.text = poi.getName() ?? ""
                                    self.poiDistanceLabel.text = self.calculateDistance(poi) ?? ""
                                    self.poiAddressLabel.text = poi.getAddress() ?? ""
                                    self.gasImageCenter.hidden = false
                                    self.gasImageLeft.hidden = true
                                    self.gasImageRight.hidden = true
                                    self.gasImageCenter.image = photo1
                                    self.tableView.reloadData()
                                })
                            }
                        }
                        else {
                            
                            dispatch_async(dispatch_get_main_queue(), {
                                self.poiNameLabel.text = poi.getName() ?? ""
                                self.poiDistanceLabel.text = self.calculateDistance(poi) ?? ""
                                self.poiAddressLabel.text = poi.getAddress() ?? ""
                                self.gasImageCenter.hidden = false
                                self.gasImageLeft.hidden = true
                                self.gasImageRight.hidden = true
                                self.gasImageCenter.image = nil
                                self.tableView.reloadData()
                            })
                        }
                    }
                }
                else {
                    
                    dispatch_async(dispatch_get_main_queue(), {
                        self.poiNameLabel.text = ""
                        self.poiDistanceLabel.text = ""
                        self.poiAddressLabel.text = ""
                        self.gasImageCenter.hidden = true
                        self.gasImageLeft.hidden = true
                        self.gasImageRight.hidden = true
                        self.tableView.reloadData()
                    })
                }
            }
        })

    }
    
    
    func calculateDistance(place: PlaceEntry) -> String? {
        
        if let distance = place.getDistanceFromUser() {
            return "\(Int(distance))m away"
        }
        return nil
    }
    
    
    //MARK: TrnqlDelegate Methods
    
    func smartActivityChange(userActivity: ActivityEntry?, error: NSError?) {
        
        if let userActivity = userActivity {
            currentActivity = userActivity
            updateActivityCardUI(userActivity)
        }
        else if let error = error {
            print(error)
        }
        
    }
    
    func smartAddressChange(address: AddressEntry?, error: NSError?) {
        
        if let address = address {
            currentAddress = address
            updateLocationCardUI(address)
        }
        else if let error = error {
            print(error)
        }

    }
    
    func smartLocationChange(location: LocationEntry?, error: NSError?) {
        
        if let location = location {
            currentLocation = location
        }
        else if let error = error {
            print(error)
        }
    }
    
    func smartPlacesChange(places: [PlaceEntry]?, error: NSError?) {
        
        if let places = places {
            currentPlaces = places
            updatePlaceCardUIs(places)
        }
        else if let error = error {
            print(error)
        }
        
    }

    func smartWeatherChange(weather: WeatherEntry?, error: NSError?) {
        
        if let weather = weather {
            updateWeatherCardUIs(weather)
            currentWeather = weather
        }
        else if let error = error {
            print(error)
        }
    }
    
    //MARK: IBActions
    
    @IBAction func setLocationAsHome(sender: UIButton) {
        
        if let currentAddressString = currentAddress?.getAddress() {
            NSUserDefaults.standardUserDefaults().setObject(currentAddressString, forKey: "homeAddress")
            updateLocationCardUI(currentAddress)
        }
        else {
            updateLocationCardUI(nil)
        }
        
    }
    
    @IBAction func setLocationAsWork(sender: UIButton) {

        if let currentAddressString = currentAddress?.getAddress() {
            NSUserDefaults.standardUserDefaults().setObject(currentAddressString, forKey: "workAddress")
            updateLocationCardUI(currentAddress)
        }
        else {
            updateLocationCardUI(nil)
        }
        
    }

    @IBAction func resetSavedLocation(sender: UIButton) {
        
        NSUserDefaults.standardUserDefaults().setObject(nil, forKey: "homeAddress")
        NSUserDefaults.standardUserDefaults().setObject(nil, forKey: "workAddress")
        if let _ = currentAddress?.getAddress() {
            updateLocationCardUI(currentAddress)
        }
        else {
            updateLocationCardUI(nil)
        }
        
    }
    
    @IBAction func showSmartLocationDataset(sender: UIButton) {
        
        var dataset = [String]()
        
        if let currentLocation = currentLocation {
            
            if let altitude = currentLocation.getAltitude() {
                dataset.append("Altitude: \(altitude)")
            }
            else {
                dataset.append("Altitude: ")
            }
            
            if let bearing = currentLocation.getBearing() {
                dataset.append("Bearing: \(bearing)")
            }
            else {
                dataset.append("Bearing: ")
            }
            
            if let speed = currentLocation.getSpeed() {
                dataset.append("Speed: \(speed)")
            }
            else {
                dataset.append("Speed: ")
            }
            
            if let time = currentLocation.getTime() {
                dataset.append("Time: \(time)")
            }
            else {
                dataset.append("Time: ")
            }
        }
        
        if let currentAddress = currentAddress {

            let lat = currentAddress.getLat() ?? ""
            dataset.append("Latitude: \(lat)")
            
            let long = currentAddress.getLng() ?? ""
            dataset.append("Longitude: \(long)")
            
            let county = currentAddress.getSubAdminArea() ?? ""
            dataset.append("County: \(county)")
            
            let country = currentAddress.getCountryName() ?? ""
            dataset.append("Country: \(country)")
            
            let countryCode = currentAddress.getCountryCode() ?? ""
            dataset.append("Country Code: \(countryCode)")
            
            let name = currentAddress.getFeatureName() ?? ""
            dataset.append("Name: \(name)")
            
            let address = currentAddress.getAddress() ?? ""
            dataset.append("Address: \(address)")
            
            dataset.append("Learn how at trnql.com/guides")
            
            if let vc = self.storyboard?.instantiateViewControllerWithIdentifier("DatasetTableViewController") as? DatasetTableViewController {
                vc.dataset = dataset
                vc.title = "Location Data"
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    @IBAction func showSmartActivityDataset(sender: UIButton) {
        
        if let currentActivity = currentActivity {
            
            var dataset = [String]()
            
            dataset.append("In Vehicle: \(currentActivity.isInVehicle())")
            dataset.append("On Bicycle: \(currentActivity.isOnBicycle())")
            dataset.append("Is Walking: \(currentActivity.isWalking())")
            dataset.append("Is Running: \(currentActivity.isRunning())")
            dataset.append("On Foot: \(currentActivity.isOnFoot())")
            dataset.append("Is Still: \(currentActivity.isStill())")
            
            dataset.append("Learn how at trnql.com/guides")
            
            if let vc = self.storyboard?.instantiateViewControllerWithIdentifier("DatasetTableViewController") as? DatasetTableViewController {
                vc.dataset = dataset
                vc.title = "Activity Data"
                self.navigationController?.pushViewController(vc, animated: true)
            }

        }
    }
    
    @IBAction func showSmartWeatherDataset(sender: UIButton) {
        
        if let currentWeather = currentWeather {
            
            var dataset = [String]()
            
            let currentConditions = currentWeather.getCurrentConditionsDescriptionAsString() ?? ""
            dataset.append("Current Conditions: \(currentConditions)")
            
            let hiLo = currentWeather.getHiLoAsString() ?? ""
            dataset.append("High/Low: \(hiLo)")
            
            let feelsLike = currentWeather.getFeelsLikeTempAsString() ?? ""
            dataset.append("Feels Like: \(feelsLike)")
            
            dataset.append("10 Day Forecast:")
            
            // 10 Day Weather Forecast
            if let weatherForecastArray = currentWeather.getWeatherForecastArray() {
                
                var weatherString = " - "
                for day in weatherForecastArray {
                    if let prediction = day.getDayShortPredicition() {
                        weatherString += "\(prediction) - "
                    }
                    else if let prediction = day.getNightShortPrediction() {
                        weatherString += "\(prediction) - "
                    }
                    
                    if let highTemp = day.getHighTempAsString() {
                        weatherString += "Hi: \(highTemp) "
                    }
                    
                    if let lowTemp = day.getLowTempAsString() {
                        weatherString += "Lo: \(lowTemp)"
                    }
                    dataset.append(weatherString)
                    weatherString = " - "
                }
            }
            
            let rain = currentWeather.getRainAsString() ?? ""
            dataset.append("Rain: \(rain)")
            
            let wind = currentWeather.getWindAsString() ?? ""
            dataset.append("Wind: \(wind)")
            
            let uvIndex = currentWeather.getUVIndexAsString() ?? ""
            dataset.append("UV Index: \(uvIndex)")
            
            let humidity = currentWeather.getHumidityAsString() ?? ""
            dataset.append("Humidity: \(humidity)")
            
            let sunrise = currentWeather.getSunriseAsString() ?? ""
            dataset.append("Sunrise: \(sunrise)")
            
            let sunset = currentWeather.getSunsetAsString() ?? ""
            dataset.append("Sunset: \(sunset)")
            
            dataset.append("Learn how at trnql.com/guides")
            
            if let vc = self.storyboard?.instantiateViewControllerWithIdentifier("DatasetTableViewController") as? DatasetTableViewController {
                vc.dataset = dataset
                vc.title = "Weather Data"
                self.navigationController?.pushViewController(vc, animated: true)
            }
            
            
        }
    }
    
    
    @IBAction func showSmartPlaceRestaurantDataset(sender: UIButton) {

        var dataset = [String]()
        
        dataset.append(currentRestaurant?.getName() ?? "-")
        dataset.append(currentRestaurant?.getAddress() ?? "-")
        dataset.append(currentRestaurant?.getPhoneNumber() ?? "-")
        
        if let lat = currentRestaurant?.getLatitude() {
            dataset.append("\(lat)")
        }
        else {
            dataset.append("-")
        }
        
        if let lon = currentRestaurant?.getLongitude() {
            dataset.append("\(lon)")
        }
        else {
            dataset.append("-")
        }
        
        dataset.append(currentRestaurant?.getIntlPhoneNumber() ?? "-")
        
        if let rating = currentRestaurant?.getRating() {
            dataset.append("\(rating)")
        }
        else {
            dataset.append("-")
        }
        
        if let val = currentRestaurant?.getPriceLevel() {
            dataset.append("\(val)")
        }
        else {
            dataset.append("-")
        }
        
        if let val = currentRestaurant?.getReviews() where val.count > 0 {
            for review in val {
                dataset.append("\(review.getText() ?? "-")")
            }
        }
        else {
            dataset.append("-")
        }
        
        if let tags = currentRestaurant?.getTypes() where tags.count > 0 {
            dataset.append(tags.map { $0.rawValue }.joinWithSeparator(", "))
        }
        else {
            dataset.append("-")
        }
        
        dataset.append(currentRestaurant?.getGoogleMapsURL() ?? "-")
        dataset.append(currentRestaurant?.getVicinity() ?? "-")
        dataset.append(currentRestaurant?.getWebsite() ?? "-")
//        dataset.append(currentRestaurant?.getOpenHoursString())
        
        dataset.append("Learn how at trnql.com/guides")
        
        if let vc = self.storyboard?.instantiateViewControllerWithIdentifier("DatasetTableViewController") as? DatasetTableViewController {
            vc.dataset = dataset
            if let restaurantName = currentRestaurant?.getName() {
                vc.title = "\(restaurantName) Data"
            }
            else {
                vc.title = "Restaurant Data"
            }
            
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @IBAction func showSmartPlaceOtherDataset(sender: UIButton) {
        
        var dataset = [String]()

        dataset.append(currentOtherPOI?.getName() ?? "-")
        dataset.append(currentOtherPOI?.getAddress() ?? "-")
        dataset.append(currentOtherPOI?.getPhoneNumber() ?? "-")
        
        if let lat = currentOtherPOI?.getLatitude() {
            dataset.append("\(lat)")
        }
        else {
            dataset.append("-")
        }
        
        if let lon = currentOtherPOI?.getLongitude() {
            dataset.append("\(lon)")
        }
        else {
            dataset.append("-")
        }
        
        dataset.append(currentOtherPOI?.getIntlPhoneNumber() ?? "-")
        
        if let rating = currentOtherPOI?.getRating() {
            dataset.append("\(rating)")
        }
        else {
            dataset.append("-")
        }
        
        if let val = currentOtherPOI?.getPriceLevel() {
            dataset.append("\(val)")
        }
        else {
            dataset.append("-")
        }
        
        if let val = currentOtherPOI?.getReviews() where val.count > 0 {
            for review in val {
                dataset.append("\(review.getText() ?? "-")")
            }
        }
        else {
            dataset.append("-")
        }
        
        if let tags = currentOtherPOI?.getTypes() where tags.count > 0 {
            dataset.append(tags.map { $0.rawValue }.joinWithSeparator(", "))
        }
        else {
            dataset.append("-")
        }
        
        dataset.append(currentOtherPOI?.getGoogleMapsURL() ?? "-")
        dataset.append(currentOtherPOI?.getVicinity() ?? "-")
        dataset.append(currentOtherPOI?.getWebsite() ?? "-")
//        dataset.append(currentOtherPOI?.getOpenHoursString() ?? "-")
        
        dataset.append("Learn how at trnql.com/guides")
        
        if let vc = self.storyboard?.instantiateViewControllerWithIdentifier("DatasetTableViewController") as? DatasetTableViewController {
            vc.dataset = dataset
            if let poiName = currentOtherPOI?.getName() {
                vc.title = "\(poiName) Data"
            }
            else {
                vc.title = "POI Data"
            }
            
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @IBAction func showSmartPlacesAllPlacesNames(sender: UIButton) {
        
        var dataset = [String]()
        
        if let places = currentPlaces {
            for place in places {
                dataset.append(place.getName() ?? "-")
            }
        }
        
        dataset.append("Learn how at trnql.com/guides")
        
        if let vc = self.storyboard?.instantiateViewControllerWithIdentifier("DatasetTableViewController") as? DatasetTableViewController {
            vc.dataset = dataset
            vc.title = "Places Dataset"
            
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
    }
    
    @IBAction func dismissSplashScreen(segue:UIStoryboardSegue) {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasDisplayedSplashScreen")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}
