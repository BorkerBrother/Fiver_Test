//
//  ContentViewModel.swift
//  Fiver_Test
//
//  Created by Borker on 04.04.24.
//

import Foundation
import MapKit



final class ContentViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var region = MKCoordinateRegion()
    @Published var circles: [MKCircle] = []
    @Published var shouldTrackUserLocation = true
    @Published var searchRadius: Double = 1000
    @Published var lastRegion = MKCoordinateRegion()
    @Published var centerMapOnUserLocation = true
    
    func updateSearchRadiusBasedOnVisibleRegion(mapView: MKMapView) {
        let visibleRegion = mapView.region
        let latitudeDelta = visibleRegion.span.latitudeDelta
        let longitudeDelta = visibleRegion.span.longitudeDelta
        
        searchRadius = max(1.0, (latitudeDelta + longitudeDelta) * 20000) // Anpassen nach Bedarf
        // Stellen Sie sicher, dass der neue Suchradius nicht größer als 5000 ist
        searchRadius = min(searchRadius, 3000)
    }

    
    // Hinzufügen einer Variablen für den Debounce-Timer
    var debounceTimer: Timer?
        // Implementieren einer Debounce-Methode
    func fetchOSMDataDebounced() {
            // Timer invalidieren, falls er bereits läuft
            debounceTimer?.invalidate()

            // Einen neuen Timer starten
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                Task {
                    await self?.fetchOSMData()
                }
            }
        }

    private var locationManager: CLLocationManager?

    override init() {
        super.init()
        self.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.requestWhenInUseAuthorization()
    }

    func checkIfLocationServicesIsEnabled() {
         if CLLocationManager.locationServicesEnabled() {
             updateLocationTracking()
         } else {
             print("Show alert - Location services are not enabled")
         }
     }
    
    private func updateLocationTracking() {
        if shouldTrackUserLocation {
            locationManager?.startUpdatingLocation()
        } else {
            locationManager?.stopUpdatingLocation()
        }
    }
    
    func toggleUserTracking() {
        shouldTrackUserLocation.toggle()
        updateLocationTracking()
    
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            // Überprüfung, ob die Zentrierung auf den Benutzer erfolgen soll
            if self.shouldTrackUserLocation && self.centerMapOnUserLocation {
                // Setzen der Region mit dem gewünschten Zoom-Level
                self.region = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
                // Optional: Deaktivieren der automatischen Zentrierung nach dem ersten Update,
                // um freie Navigation zu ermöglichen
                self.centerMapOnUserLocation = false
            }
        }
    }
   

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }

    private func checkLocationAuthorization() {
        switch locationManager?.authorizationStatus {
        case .notDetermined:
            locationManager?.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("Location access is restricted or denied")
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager?.startUpdatingLocation()
        default:
            break
        }
    }
    
    
    func fetchOSMData() async {
        let overpassUrl = "https://overpass-api.de/api/interpreter"
        guard let currentLocation = locationManager?.location?.coordinate,
              let url = URL(string: overpassUrl) else {
            print("Ungültige URL oder Standortdaten nicht verfügbar")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = buildRequestBody(with: currentLocation)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("HTTP Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return
            }
            
        
            let decodedResponse = try JSONDecoder().decode(Response.self, from: data)
            await MainActor.run {
                updateMap(with: decodedResponse.elements)
            }
        } catch {
            print("Fehler bei der Abfrage der Overpass API: \(error)")
        }
    }
    
    


    func buildRequestBody(with location: CLLocationCoordinate2D) -> Data? {
        let radius = searchRadius
        return """
        [out:json][timeout:25];
        (
          nwr(around:\(radius),\(location.latitude),\(location.longitude))["amenity"~"school|kindergarten|childcare"];
          nwr(around:\(radius),\(location.latitude),\(location.longitude))["leisure"~"sports_centre|sports_hall|pitch|golf_course|stadium|playground|water_park"];
          nwr(around:\(radius),\(location.latitude),\(location.longitude))["building"="kindergarten"];
          nwr(around:\(radius),\(location.latitude),\(location.longitude))["community"="youth_centre"];
          nwr(around:\(radius),\(location.latitude),\(location.longitude))["name"~"Jugendherberge"];
          nwr(around:\(radius),\(location.latitude),\(location.longitude))["social_facility:for"~"child|juvenile"];
        );
        out geom;
        """.data(using: .utf8)
    }


    @MainActor
    func updateMap(with elements: [Element]) {
        // Erstelle ein neues Array von MKCircle basierend auf den Elementen
        let newCircles: [MKCircle] = elements.compactMap { element -> MKCircle? in
            if let lat = element.lat, let lon = element.lon {
                return MKCircle(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: 100)
            } else if let bounds = element.bounds {
                let centerLat = (bounds.minlat + bounds.maxlat) / 2
                let centerLon = (bounds.minlon + bounds.maxlon) / 2
                return MKCircle(center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon), radius: 100)
            }
            return nil
        }
        
        // Ersetze die bestehenden Kreise durch die neuen Kreise
        self.circles = newCircles
        
        print("\(self.circles.count) Kreise hinzugefügt.")
    }


    struct Response: Codable {
        var elements: [Element]
    }

    struct Element: Codable {
        var type: String
        var id: Int
        var lat: Double?
        var lon: Double?
        var bounds: Bounds?
        var tags: Tags?
    }

    struct Bounds: Codable {
        var minlat: Double
        var minlon: Double
        var maxlat: Double
        var maxlon: Double
    }

    struct Tags: Codable {
        var amenity: String?
        var name: String?
        var description: String?
    }
    
}

