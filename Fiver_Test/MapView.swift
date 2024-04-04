//
//  MapView.swift
//  Fiver_Test
//
//  Created by Borker on 04.04.24.
//
import MapKit
import SwiftUI


struct MapView: UIViewRepresentable {
    
    @Binding var region: MKCoordinateRegion
    var viewModel: ContentViewModel
    var circles: [MKCircle]
    @Binding var shouldTrackUserLocation: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = shouldTrackUserLocation
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsTraffic = true
        mapView.mapType = .standard
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.showsUserLocation = shouldTrackUserLocation
        // Die Benutzerverfolgung wird nur aktiviert, wenn `shouldTrackUserLocation` wahr ist.
        uiView.userTrackingMode = shouldTrackUserLocation ? .followWithHeading : .none
        // Die Region wird nur gesetzt, wenn die Standortverfolgung deaktiviert ist.
        if !shouldTrackUserLocation {
            uiView.setRegion(region, animated: true)
        }
        // Entfernen aller vorhandenen Overlays und Hinzufügen aktueller Kreise
        uiView.removeOverlays(uiView.overlays)
        uiView.addOverlays(circles)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, viewModel: viewModel)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var viewModel: ContentViewModel

        init(_ parent: MapView, viewModel: ContentViewModel) {
            self.parent = parent
            self.viewModel = viewModel
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circleOverlay = overlay as? MKCircle {
                let circleRenderer = MKCircleRenderer(circle: circleOverlay)
                circleRenderer.fillColor = UIColor.red.withAlphaComponent(0.5)
                circleRenderer.strokeColor = UIColor.red
                circleRenderer.lineWidth = 2 
                return circleRenderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            DispatchQueue.main.async {
                // Suchradius basierend auf der aktuellen Ansicht der Karte aktualisieren
                self.viewModel.updateSearchRadiusBasedOnVisibleRegion(mapView: mapView)
                self.viewModel.fetchOSMDataDebounced()
            }
        }
    }
}
