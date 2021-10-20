import Foundation
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
//  DiscoveryEventQueue.swift
//
//  Created by Christine Julien on 8/2/20.
//
// This file contains some very specialized data structures. They are called events and queues, but their behavior
// is pretty tailored to the expectations of the BLEnd app. Proceed with cautioun.
// This class holds a discovery event, which contains the set of (unique) devices discovered within a discovery window

import CoreBluetooth
import CoreLocation

class DiscoveryEvent {
    // the timestamp associated with the start of the window
    var timestamp: Date
    // string identifiers for the discovered devices
    // TODO: we might want to make this a bit more complicated and keep a count associated with each discovered device and then
    // count a device as "discovered" only if this count reaches a threshold in the window
    var discoveredAppleNodes: Set<String>
    var discoveredAndroidNodes: Set<String>
    // we're going to put these events in a queue, built as a singly linked list, so this is the next event in the queue
    var next: DiscoveryEvent?
    
    // basic initialization
    init(timestamp: Date, next: DiscoveryEvent? = nil){
        self.timestamp = timestamp
        self.discoveredAppleNodes = []
        self.discoveredAndroidNodes = []
        self.next = next
    }
    
    // this adds a newly discovered device to the set stored for this event window
    func addDiscoveredAppleNode(_ discoveredNode: String){
        discoveredAppleNodes.insert(discoveredNode)
    }
    
    // this adds a newly discovered device to the set stored for this event window
    func addDiscoveredAndroidNode(_ discoveredNode: String){
        discoveredAndroidNodes.insert(discoveredNode)
    }
    
}

// This class implements the queue that stores instances of the above discover events
class DiscoveryEventQueue {
    public static let APPLE = 0
    public static let ANDROID = 1
    // the head of the queue. If the queue is empty, this is null. If the queue's size is greater than 1, this is the last event
    // that may not have been sent to the React Native app. If the queue's size is exactly one, this is the event associated with
    // the current window
    var front: DiscoveryEvent?
    // the back of the queue. If the queue is empty, this is null.
    var rear: DiscoveryEvent?
    // how big the discovery windows are. We have to get this from the BlendController
    var window_size : Int
    
    // not much to see here; just store the window size we're handed
    init(window_size: Int){
        self.window_size = window_size
    }
    
    // yup, returns true of the queue is empty; false if there's something in the queue
    var isEmpty: Bool {
        return front == nil
    }
    
    // this is a super specialized "enqueue" method. We're not enqueuing an event, but a discovered device
    // here, what we want to do is to create a new node if none exists with a matching time stamp matching timestamp,
    // it will be the last one, and we just want to add this discovered device to that event's set, assuming it's not already there
    func enqueue(_ timestamp: Date, discoveredNode: String, platform: Int){
        // if the queue is empty make a new event and enqueue it
        if isEmpty {
            front = DiscoveryEvent(timestamp: timestamp)
            if(platform == DiscoveryEventQueue.APPLE){
                front?.addDiscoveredAppleNode(discoveredNode)
            }
            else{
                front?.addDiscoveredAndroidNode(discoveredNode)
            }
            if rear == nil{
                rear = front
            }
        }
        else{
            // if there is an event for the current time window, we just add to it
            if(rear?.timestamp == timestamp){
                // update the list that rear stores
                // first, check to see if the set of discovered nodes already contains this one...
                // if not, add it!
                if(platform == DiscoveryEventQueue.ANDROID){
                    if(!rear!.discoveredAndroidNodes.contains(discoveredNode)){
                        // in this version, discovery of a device a single time within the discovery window constitutes discovery
                        rear!.addDiscoveredAndroidNode(discoveredNode)
                    }
                }
                else{
                    if(!rear!.discoveredAppleNodes.contains(discoveredNode)){
                        // in this version, discovery of a device a single time within the discovery window constitutes discovery
                        rear!.addDiscoveredAppleNode(discoveredNode)
                    }
                }
            }
            else{
                // this is the first discovery event in this window; create a new node for it.
                rear?.next = DiscoveryEvent(timestamp: timestamp)
                if(platform == DiscoveryEventQueue.APPLE){
                    rear?.next?.addDiscoveredAppleNode(discoveredNode)
                }
                else{
                    rear?.next?.addDiscoveredAndroidNode(discoveredNode)
                }
                rear = rear?.next
            }
        }
    }
    
    // dequeueing is a little funny, too...
    // if we're dequeueing the LAST thing, we want to make sure it's not the CURRENT thing
    // that is, if the time value of the front node is within the last five minutes, we DON'T dequeue it (but we do return it)
    func dequeue() -> (Date?, Int?, Int?) {
        defer {
            // this is measured in seconds; we give an extra 3 seconds of grace
            if(!isEmpty){
                if((Int)((front?.timestamp.timeIntervalSinceNow)!) < (0 - window_size*60 - 3)) {
                    front = front?.next
                    if isEmpty {
                        rear = nil
                    }
                }
            }
        }
        // this means, on the react native side, we may get multiple values with the same timestamp
        // but we can overwrite them because they should be strictly increasing
        return (front?.timestamp, front?.discoveredAppleNodes.count, front?.discoveredAndroidNodes.count)
    }
    
    
}
