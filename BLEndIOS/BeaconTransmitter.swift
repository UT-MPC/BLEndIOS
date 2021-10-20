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
//  BeaconTransmitter.swift
//
//  Created by Julien on 8/1/20.
//
import CoreBluetooth

// this class contains the native functionality enabling the PTT iOS app to act as a peripheral and be discovered by other devices
class BeaconTransmitter: NSObject, CBPeripheralManagerDelegate{
  
  // the peripheral manager, which will handle our advertising
  private var peripheralManager : CBPeripheralManager!
  
  // the string value of the service UUID that we want to advertise
  enum Constants: String {
    case SERVICE_UUID_apple = "e0bfe0cf-02ce-4f1d-b2c0-ffb07fadd498"
  }
  
  // these is the actual UUID constructed from the string representation of the apple PTT service UUID
  public struct BLEndService {
    // the apple service UUID
    public static let service_apple = CBUUID(string: Constants.SERVICE_UUID_apple.rawValue)
  }

  // initialization is simple: just set up the peripheral manager
  override init(){
    super.init()
    peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
  }
  
  // this callback's implementation is required by the CBPeripheralManagerDelegate contract
  // we don't need to do anything special, so this is just some tracing in case of errors
  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    switch peripheral.state {
    case .unknown:
      print("Peripheral: Bluetooth Device is UNKNOWN")
    case .unsupported:
      print("Peripheral: Bluetooth Device is UNSUPPORTED")
    case .unauthorized:
      print("Peripheral: Bluetooth Device is UNAUTHORIZED")
    case .resetting:
      print("Peripheral: Bluetooth Device is RESETTING")
    case .poweredOff:
      print("Peripheral: Bluetooth Device is POWERED OFF")
    case .poweredOn:
      print("Peripheral: Bluetooth Device is POWERED ON")
    @unknown default:
      print("Peripheral: Unknown State")
    }
  }
  
  // this method will be called by the BlendController when the schedule says it's time to start advertising
  func startAdvertising(){
    // set up the advertising data to include the apple PTT servuce UUID
    let advertisingData: [String : Any] = [CBAdvertisementDataServiceUUIDsKey: [BLEndService.service_apple]]

    // start advertising
    self.peripheralManager?.startAdvertising(advertisingData)
  }
  
  // this method will be called by the BlendController when the schedule says its time to stop advertising
  func stopAdvertising(){
    self.peripheralManager?.stopAdvertising()
  }
  
  // this function will be called by BlendController when we start advertising in the background
  // right now, this is the same as the "regular" way, but background advertising is somewhat limited, so if we start
  // doing fancier things in the foreground, this likely won't change
  func startBackgroundAdvertising(){
    // set up the advertising data to include the apple PTT servuce UUID
    let advertisingData: [String : Any] = [CBAdvertisementDataServiceUUIDsKey: [BLEndService.service_apple]]
    // start advertising
    self.peripheralManager?.startAdvertising(advertisingData)
  }
}
