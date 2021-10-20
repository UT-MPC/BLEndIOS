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
//  BlendScanner.swift
//
//  Created by Christine Julien on 8/1/20.
//
import CoreBluetooth

/*protocol DiscoveryEventCallback {
  func call(tuple: (Date?, Int?, Int?))
}*/

// this class contains the native functionality for scanning for PTT bluetooth advertisements
class BeaconScanner: NSObject, CBCentralManagerDelegate{
  
  // window size -- this parameter defines the size of the time interval that constitutes a discovery
  // simply, PTT will report the total number of contacts within each time window
  private let window_size = 5 // five minutes
  
  // each central manager can scan for one service. We have three difference services, so three central managers
  // this central manager will discover other apple devices
  private var centralManager_apple : CBCentralManager!
  // this central manager will discover modern Android device (Android 8.0+)
  private var centralManager_android : CBCentralManager!
  // this central manager will discover older Android devices (and possible, but unlikley, other things too)
  private var centralManager_android_short : CBCentralManager!
  
  // this is a tailored data storage to keep track of the devices discovered in each discovery windwo
  var discoveryEvents: DiscoveryEventQueue!
    
  /*var callback: DiscoveryEventCallback?
  func addDiscoveryEventCallback(callback: DiscoveryEventCallback) {
    self.callback = callback
  }*/

  // these are the String versions of service UUIDs advertised by various PTT apps
  enum Constants: String {
    // this UUID is used by all apple iOS devices
    case SERVICE_UUID_apple = "e0bfe0cf-02ce-4f1d-b2c0-ffb07fadd498"
    // this UUID is used by all android devices
    // when scanning, this will be the service discovered in modern Android versions (8.0+)
    case SERVICE_UUID_android = "000085cf-bea1-419a-8721-b0bb194b8417"
    // this is a 16 bit UUID computed from the longer 128 bit UUID in older Android devices
    case SERVICE_UUID_android_short = "85CF"
  }
  
  // these are the actual UUIDs constructed from the string representations of the PTT service UUIDs
  public struct BLEndService {
    // the apple service UUID
    public static let service_apple = CBUUID(string: Constants.SERVICE_UUID_apple.rawValue)
    // the "modern" android service UUID
    public static let service_android = CBUUID(string: Constants.SERVICE_UUID_android.rawValue)
    // the 16-bit version of the android service UUID
    public static let service_android_short = CBUUID(string: Constants.SERVICE_UUID_android_short.rawValue)
  }
  
  // to initialize the scanner, we just need to set up the three core bluetooth central managers
  override init(){
    super.init()
    centralManager_apple = CBCentralManager(delegate: self, queue: nil)
    centralManager_android = CBCentralManager(delegate: self, queue: nil)
    centralManager_android_short = CBCentralManager(delegate: self, queue: nil)
    discoveryEvents = DiscoveryEventQueue(window_size: window_size)
  }
  
  // this callback's implementation is required by the CBCentralManagerDelegate contract
  // we don't need to do anything special, so this is just some tracing in case of errors
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .unknown:
      print("Central: Bluetooth Device is UNKNOWN")
    case .unsupported:
      print("Central: Bluetooth Device is UNSUPPORTED")
    case .unauthorized:
      print("Central: Bluetooth Device is UNAUTHORIZED")
    case .resetting:
      print("Central: Bluetooth Device is RESETTING")
    case .poweredOff:
      print("Central: Bluetooth Device is POWERED OFF")
    case .poweredOn:
      print("Central: Bluetooth Device is POWERED ON")
    @unknown default:
      print("Central: Unknown State")
    }
  }
  
  // this method will be called by the BlendController when it is time to start scanning
  func startScanning(){
    // start scanning for other apple iOS devices; for each scan, return each device only once
    centralManager_apple?.scanForPeripherals(withServices: [BLEndService.service_apple], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
    // start scanning for Android devices; for each scan, return each device only once
    centralManager_android?.scanForPeripherals(withServices: [BLEndService.service_android], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
    // start scanning for Android devices using the 16 bit UUID; for each scan, return each device only once
    centralManager_android_short?.scanForPeripherals(withServices: [ BLEndService.service_android_short ], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
  }
  
  // this method will be called by the BlendController when it is time to stop scanning
  func stopScanning(){
    self.centralManager_apple?.stopScan()
    self.centralManager_android?.stopScan()
    self.centralManager_android_short?.stopScan()
  }
  
  
  // this callback is invoked when any of the central managers discovers a peripheral while scanning.
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    
    // in the case of the peripheral being another iOS device, this is sufficient
    var discoveredNodeString: String = peripheral.identifier.uuidString
        
    // if the peripheral is an Android device, the uuid string in the advertisement data won't be unique.
    // the android PTT app will insert some random bits in the advertisement data, and we need to grab those
    if(central.isEqual(centralManager_android) || central.isEqual(centralManager_android_short)){
      let array = String(describing: advertisementData["kCBAdvDataServiceData"]).components(separatedBy: "=")
      let secondarray = String(describing: array[array.count-1]).components(separatedBy: "}")
      discoveredNodeString = secondarray[0]
      discoveryEvents.enqueue(getCurrentTimeWindow(), discoveredNode: discoveredNodeString, platform: DiscoveryEventQueue.ANDROID)
    }
    else{
      discoveryEvents.enqueue(getCurrentTimeWindow(), discoveredNode: discoveredNodeString, platform: DiscoveryEventQueue.APPLE)
    }
    
    // when we enqueue an event, we want to convert the current date to the beginning of the current window
    //callback?.call(tuple: discoveryEvents.dequeue())
      print("Discovered someone!!")
  }
  
  // this is just a simple helper function to grab the current time and walk it back to the beginning of the current window
  // this relies on the UNIX epoch values, which is the "timestamp" that is eventually used
  private func getCurrentTimeWindow() -> Date {
    let now: Date = Date()
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: now)
    let minute = calendar.component(.minute, from: now)
    let floorMinute = minute - (minute % window_size)
    return calendar.date(bySettingHour: hour, minute: floorMinute, second: 0, of: now)!
  }
  
  // this function will be called by BlendController when we start scanning in the background
  // right now, this is the same as the "regular" way, but background scanning is somewhat limited, so if we start
  // doing fancier things in the foreground, this likely won't change
  func startBackgroundScanning(){
    //print("Background scanning")
    centralManager_apple?.scanForPeripherals(withServices: [BLEndService.service_apple], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
    centralManager_android?.scanForPeripherals(withServices: [BLEndService.service_android], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
    centralManager_android_short?.scanForPeripherals(withServices: [BLEndService.service_android_short], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
  }
   
}
