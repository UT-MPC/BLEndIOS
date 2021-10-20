/**
 * Copyright 2020, The University of Texas at Austin
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
//
//  BlendController.swift
//
//  Created by Christine Julien on 8/1/20.
//

import CoreBluetooth
import CoreLocation

// this class serves as the mastermind implementing the BLEnd neighbor discovery schedule
@objc(BlendController)
class BlendController: NSObject, ObservableObject{
    
  @objc public static let controller = BlendController()
  
  @objc
  public static func getInstance() -> BlendController {
    return BlendController.controller
  }
  
  // briefly, a BLEnd schedule is divided into epochs, where each epoch starts with a scan window, followed
  // by period beacons for the remainder of the epoch. Normally, the scan window and the advertisement interval
  // would be roughly the same. iOS does not let us adjust the advertisement interval, though we assume it is in
  // the range of 250 ms (but may be longer when the app is backgrounded). For now, we work within that since the
  // optimal settings for BLEnd for our target scenario would have an advertisement interval larger than 250ms.
  // Optimal BLEnd settings, assuming 50 co-located devices, target discovery latency of 1 minute, with 95% probability
  // advertisement interval: 423 ms, epoch: 30032 ms
  
  //private let scanDurationMS = 423.0
  private let scanDurationS = (423.0 / 1000.0) // 1.0
  // private let epochDurationMS = 30032.0
  private let epochDurationS = (30032.0 / 1000.0) // 10.0
      
  // this is the timer that will run the BLEnd schedule
  private var timer = Timer()
  
  // these booleans help us keep the state of the BLEnd schedule
  private var isScanning = false
  private var isAdvertising = false
  private var isScheduleRunning = false
  
  // this is the BeaconScanner instance that will actually implement the Bluetooth peripheral functionality
  private var mBeaconScanner: BeaconScanner!
  // this is the BeaconTransmitter instance that will actually implement the Bluetooth central functionality
  private var mBeaconTransmitter: BeaconTransmitter!
  
  
  //CJ TESTING BLUETOOTH ALWAYS ON
  private var locationManager: CLLocationManager!
  private var beaconRegion: CLBeaconRegion!

  // create the needed instances of the transmitter and the scanner
  // TODO: probably a good idea to make these singletons instead
  private override init() {
    mBeaconTransmitter = BeaconTransmitter()
    mBeaconScanner = BeaconScanner()
    
    // the below is used to keep the bluetooth scanning active in the background
    // note that this will cause an iOS device to more frequently discover nearby PTT users
    // while the iOS app is running in the background, but this only works when the screen is on
    super.init()
    locationManager = CLLocationManager()
    locationManager.requestAlwaysAuthorization()
    // the distance filter needs to be set to "none" to ensure the device gets updates when stationary
    locationManager.distanceFilter = kCLDistanceFilterNone
    locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.allowsBackgroundLocationUpdates = true
    
    beaconRegion = CLBeaconRegion(proximityUUID: UUID(uuidString: "e0bfe0cf-02ce-4f1d-b2c0-ffb07fadd498")!, identifier: "e0bfe0cf-02ce-4f1d-b2c0-ffb07fadd498")
    locationManager.startRangingBeacons(in: beaconRegion)

    locationManager.startUpdatingLocation()
    locationManager.startUpdatingHeading()
    locationManager.startMonitoringSignificantLocationChanges()

  }
  
  // this method will be called by the React bridge when the user switches bluetooth functionality on
  func startBlend(){

    isScheduleRunning = true
    enterScan()
  }
  
  @objc
  func enterScan(){
    // scans happen at the beginning of every epoch
    // if we're starting scanning, the first thing we need to do is stop advertising (if we're advertising)
    stopAdvertise()
    
    // the isScheduleRunning flag will be set to false if the user stops BLEnd from the React interface
    // therefore, at the beginning of each epoch, let's check to see if the user has asked us to stop
    if(!isScheduleRunning){
      return
    }
    
    // first, let's set a timer to fire at the end of the timed scan interval, at which point, we'll process endofscan
    let timeIntervalS = scanDurationS
    DispatchQueue.main.async {
      self.timer.invalidate()
      // sigh, different handlers for different OS versions
      if #available(iOS 10.0, *) {
        self.timer = Timer.scheduledTimer(withTimeInterval: timeIntervalS, repeats: false) {_ in
          self.endOfScan()
        }
      } else {
      self.timer = Timer.scheduledTimer(timeInterval: timeIntervalS, target: self, selector: #selector(self.endOfScan), userInfo: nil, repeats: false)
      }
    }
    
    // once we've launched our timers, we can start scanning
    startScan()
  }
  
  // this method is called when the scan timer fires at the end of the scan. We need to stop scanning and start advertising.
  @objc
  func endOfScan(){
    // first, stop scanning
    stopScan()
    
    // second, if the user has canceled the bluetooth function from the react program while we were scanning, break out of the schedule
    if(!isScheduleRunning){
      return
    }
    // otherwise, let's start advertising
    else{
      
      // before we do that, though, let's set a timer to fire at the end of the epoch
      // we already did the scan part of the epoch, so take that amount of time off
      // and when this timer fires, we'll be at the start of the next epoch, so it will be time to enter scanning again
      let timeIntervalS = epochDurationS - scanDurationS
      DispatchQueue.main.async {
        self.timer.invalidate()
        if #available(iOS 10.0, *) {
          self.timer = Timer.scheduledTimer(withTimeInterval: timeIntervalS, repeats: false) {_ in
            self.enterScan()
          }
        } else {
          self.timer = Timer.scheduledTimer(timeInterval: timeIntervalS, target: self, selector:  #selector(self.enterScan), userInfo: nil, repeats: false)
        }
      }
      
      // now that the timer is dispatched, start advertising!
      startAdvertising()
    }
  }
  
  // this method is called at the end of enterScan; all we do is tell the BeaconScanner to get started
  func startScan(){
    mBeaconScanner.startScanning()
    isScanning = true
  }
  
  // this method is called at the end of exitScan; all we do is tell the BeaconTransmitter to get started
  func startAdvertising(){
    mBeaconTransmitter.startAdvertising()
    isAdvertising = true
  }
  
  // this method is called from the beginning of exitScan; all we do is tell the BeaconScanner to quit for now
  func stopScan(){
    if(isScanning) {
      mBeaconScanner.stopScanning()
      isScanning = false
    }
  }
  
  // this method is called at the beginning of enterScan; all we do is tell the BeaconTransmitter to quit for now
  func stopAdvertise(){
    if(isAdvertising) {
      mBeaconTransmitter.stopAdvertising()
      isAdvertising = false
    }
  }
  
  // this function is called from the React bridge; it is invoked when the user shuts off the bluetooth function from within the app
  func stopBlend(){
    isScheduleRunning = false
  }
  
  // this function is called from the React bridge when the app is sent from the foreground to the background
  // unfortunately because of limitations in iOS, we have to give up on the BlendSchedule and just
  // scan continuously and advertise continuously
  func startBackground(){
    mBeaconScanner.startBackgroundScanning()
    mBeaconTransmitter.startBackgroundAdvertising()
  }
  
  // this function is called from the React bridge when the app comes back into the foreground. We can stop the background
  // scanning and background advertising
  func stopBackground(){
    mBeaconScanner.stopScanning()
    mBeaconTransmitter.stopAdvertising()
  }
  
  // this function is called from the React bridge when the app needs to collect the stored discovery information.
  // this dequeue action is special; except in the case that the window is the current window, the information is destroyed
  // all that persists is the count of discovered devices per time window, but this will be persisted in React Native's redux
  /*func getNextDiscoveryEvent() -> (Date?, Int?, Int?) {
    return mBeaconScanner.discoveryEvents.dequeue()
  }

  func addDiscoveryEventCallback(callback: DiscoveryEventCallback) {
    mBeaconScanner.addDiscoveryEventCallback(callback: callback)
  }*/
   
   
  
}
