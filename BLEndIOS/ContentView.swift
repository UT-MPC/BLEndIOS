//
//  ContentView.swift
//  BLEndIOS
//
//  Created by Christine Julien on 10/20/21.
//

import SwiftUI

struct ContentView: View {
    
    // We keep a hold of an instance of the BlendController
    @ObservedObject var blendController = BlendController.getInstance()
    // we also keep a single piece of state to tell us whether the users has turned on Bluetooth in the app or not
    @State private var beaconing = false
    
    var body: some View {
        Button(action: {
            print("Starting BLEnd...")
            beaconing = true
            blendController.startBlend()
        }) {
            Text("Start BLEnd")
                .fontWeight(.bold)
                .font(.title)
                .padding()
                .background(Color.blue)
                .cornerRadius(40)
                .foregroundColor(.white)
                .padding(10)
                .overlay(RoundedRectangle(cornerRadius: 40).stroke(Color.blue, lineWidth: 5))
        }
        .disabled(beaconing == true)
        .padding()
        Button(action: {
            print("Stopping BLEnd...")
            beaconing = false
            blendController.stopBlend()
        }) {
            Text("Stop BLEnd")
                .fontWeight(.bold)
                .font(.title)
                .padding()
                .background(Color.blue)
                .cornerRadius(40)
                .foregroundColor(.white)
                .padding(10)
                .overlay(RoundedRectangle(cornerRadius: 40).stroke(Color.blue, lineWidth: 5))
        }
        .disabled(beaconing == false)

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
