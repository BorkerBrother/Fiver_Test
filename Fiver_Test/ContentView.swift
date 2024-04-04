//
//  ContentView.swift
//  Fiver_Test
//
//  Created by Borker on 04.04.24.
//
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        VStack {
            MapView(region: $viewModel.region, viewModel: viewModel, circles: viewModel.circles, shouldTrackUserLocation: $viewModel.shouldTrackUserLocation)
            Button("Standortverfolgung umschalten") {
                viewModel.toggleUserTracking()
            }
        }
        .onAppear {
            viewModel.checkIfLocationServicesIsEnabled()
       
        }
    }
}
