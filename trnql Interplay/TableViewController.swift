//
//  TableViewController.swift
//  trnql Interplay
//
//  Created by Jonathan Sahoo on 8/12/15.
//  Copyright (c) 2015 trnql. All rights reserved.
//

import UIKit
import trnql

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
    
    @IBOutlet weak var sunriseSunsetTimeLabel: UILabel!
    
    let trnql = Trnql.sharedInstance
    let googleAPIKey = "INSERT_YOUR_KEY_HERE" // You can register for a free Google API Key here: https://console.developers.google.com
    
    var currentAddress: AddressEntry?
    var currentLocation: LocationEntry?
    var currentActivity: ActivityEntry?
    var currentWeather: WeatherEntry?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        trnql.setAPIKey("INSERT_YOUR_KEY_HERE") // You can register for a trnql API Key here: http://appserver.trnql.com:9090/developer_dashboard/dashboard.jsp
        
        let backItem = UIBarButtonItem(title: "Back", style: UIBarButtonItemStyle.Plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backItem
        
        currentAddressLabel.text = "Updating location..."
        temperatureLabel.text = "Updating weather..."
        sunriseSunsetTimeLabel.text = "Updating weather..."
        
        self.navigationController?.navigationBar.translucent = false
        
        trnql.delegate = self
        trnql.startAllServices() // Starts all services
        
        updateLocationBanner(UIImage(named: "earth")!)
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: Selector("reloadData"), forControlEvents: UIControlEvents.ValueChanged)
        
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
                let calendar = NSCalendar.currentCalendar()
                let nowComponents = calendar.components([NSCalendarUnit.Hour, NSCalendarUnit.Minute], fromDate: NSDate())
                
                if let nowTime = calendar.dateFromComponents(nowComponents) {
                    
                    if let sunriseDate = weatherEntry.getSunriseTime() {
                        
                        let sunriseComponents = calendar.components([NSCalendarUnit.Hour, NSCalendarUnit.Minute], fromDate: sunriseDate)
                        if let sunriseTime = calendar.dateFromComponents(sunriseComponents) {
                            
                            if sunriseTime.compare(nowTime) == NSComparisonResult.OrderedDescending {
                                
                                let timeRemainingComponents = calendar.components([NSCalendarUnit.Hour, NSCalendarUnit.Minute], fromDate: nowTime, toDate: sunriseTime, options: [])
                                let hours = timeRemainingComponents.hour != 1 ? "\(timeRemainingComponents.hour) hours" : "\(timeRemainingComponents.hour) hour"
                                let minutes = timeRemainingComponents.minute != 1 ? "\(timeRemainingComponents.minute) minutes" : "\(timeRemainingComponents.minute) minutes"
                                self.sunriseSunsetTimeLabel.text = "There are \(hours) and \(minutes) until sunrise"
                                return
                            }
                        }
                    }
                    
                    if let sunsetDate = weatherEntry.getSunsetTime() {
                        
                        let sunsetComponents = calendar.components([NSCalendarUnit.Hour, NSCalendarUnit.Minute], fromDate: sunsetDate)
                        if let sunsetTime = calendar.dateFromComponents(sunsetComponents) {
                            
                            if sunsetTime.compare(nowTime) == NSComparisonResult.OrderedDescending {
                                
                                let timeRemainingComponents = calendar.components([NSCalendarUnit.Hour, NSCalendarUnit.Minute], fromDate: nowTime, toDate: sunsetTime, options: [])
                                let hours = timeRemainingComponents.hour != 1 ? "\(timeRemainingComponents.hour) hours" : "\(timeRemainingComponents.hour) hour"
                                let minutes = timeRemainingComponents.minute != 1 ? "\(timeRemainingComponents.minute) minutes" : "\(timeRemainingComponents.minute) minutes"
                                self.sunriseSunsetTimeLabel.text = "There are \(hours) and \(minutes) until sunset"
                                return
                            }
                            
                        }
                    }
                    
                    self.sunriseSunsetTimeLabel.text = "Sunrise/sunset time is unknown"
                }
                
            }
            else {
                self.temperatureLabel.text = "The temperature is unknown"
                self.sunriseSunsetTimeLabel.text = "Sunrise/sunset time is unknown"
            }
            
            
            self.tableView.reloadData()
        })
    }
    
    //MARK: TrnqlDelegate Methods
    
    func smartActivityChange(userActivity: ActivityEntry?, error: NSError?) {
        
        if error == nil {
            
            currentActivity = userActivity
            updateActivityCardUI(userActivity)
        }
        else {
            print(error!)
        }
        
    }
    
    func smartAddressChange(address: AddressEntry?, error: NSError?) {
        
        if error == nil {
            
            currentAddress = address
            updateLocationCardUI(address)
        }
        else {
            print(error!)
        }

    }
    
    func smartLocationChange(location: LocationEntry?, error: NSError?) {
        
        if error == nil {
            currentLocation = location
        }
        else {
            print(error!)
        }
    }
    
    func smartWeatherChange(weather: WeatherEntry?, error: NSError?) {
        
        if error == nil {
            
            updateWeatherCardUIs(weather)
            currentWeather = weather
        }
        else {
            print(error!)
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
    
    @IBAction func dismissSplashScreen(segue:UIStoryboardSegue) {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasDisplayedSplashScreen")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}
