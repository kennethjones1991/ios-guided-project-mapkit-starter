//
//  EarthquakesViewController.swift
//  Quakes
//
//  Created by Paul Solt on 10/3/19.
//  Copyright © 2019 Lambda, Inc. All rights reserved.
//

import UIKit
import MapKit

enum ReuseIdentifier {
    static let quakeAnnotation = "QuakeAnnotationView"
}

class EarthquakesViewController: UIViewController {
    
    private let quakeFetcher = QuakeFetcher()
    
    @IBOutlet var mapView: MKMapView!
    private var userTrackingButton: MKUserTrackingButton!
    
    private let locationManager = CLLocationManager()
    
    var quakes: [Quake] = [] {
        didSet {
            let oldQuakes = Set(oldValue)
            let newQuakes = Set(quakes)
            
            let addedQuakes = newQuakes.subtracting(oldQuakes)
            let removedQuakes = oldQuakes.subtracting(newQuakes)
            
            mapView.removeAnnotations(Array(removedQuakes))
            mapView.addAnnotations(Array(addedQuakes))
        }
    }
	
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.requestWhenInUseAuthorization()
        
        userTrackingButton = MKUserTrackingButton(mapView: mapView)
        userTrackingButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(userTrackingButton)
        
        NSLayoutConstraint.activate([
            userTrackingButton.leadingAnchor.constraint(equalTo: mapView.leadingAnchor, constant: 20),
            mapView.bottomAnchor.constraint(equalTo: userTrackingButton.bottomAnchor, constant: 20)
        ])
        
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: ReuseIdentifier.quakeAnnotation)
        
        fetchQuakes()
    }
    
    private var isCurrentlyFetchingQuakes = false
    private var shouldRequestQuakesAgain = false
    
    private func fetchQuakes() {
        // If we were already requesting quakes...
        guard !isCurrentlyFetchingQuakes else {
            // ...then we want to "remember" to refresh once the busy request finishes
            shouldRequestQuakesAgain = true
            return
        }
        
        isCurrentlyFetchingQuakes = true
        
        let visibleRegion = mapView.visibleMapRect
        
        quakeFetcher.fetchQuakes(in: visibleRegion) { (quakes, error) in
            self.isCurrentlyFetchingQuakes = false
            
            defer {
                if self.shouldRequestQuakesAgain {
                    self.shouldRequestQuakesAgain = false
                    self.fetchQuakes()
                }
            }
            
            if let error = error {
                NSLog("%@", "Error fetchiing quakes: \(error)")
            }
            
            guard let quakes = quakes else {
                self.quakes = []
                return
            }
            
            let sortedQuakes = quakes.sorted { $0.magnitude > $1.magnitude }
            
            self.quakes = Array(sortedQuakes.prefix(200))
        }
    }
}

extension EarthquakesViewController: MKMapViewDelegate {
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        fetchQuakes()
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let quake = annotation as? Quake else { return nil }
        
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: ReuseIdentifier.quakeAnnotation, for: quake) as! MKMarkerAnnotationView
        
        annotationView.glyphImage = #imageLiteral(resourceName: "QuakeIcon")
        
        annotationView.canShowCallout = true
        let detailView = QuakeDetailView()
        detailView.quake = quake
        annotationView.detailCalloutAccessoryView = detailView
        
        switch quake.magnitude {
        case 0..<3: annotationView.markerTintColor = .systemYellow
        case 3..<5: annotationView.markerTintColor = .systemOrange
        case 5..<7: annotationView.markerTintColor = .systemRed
        case let magnitude where magnitude >= 7: annotationView.markerTintColor = .systemPurple
        default: annotationView.markerTintColor = .systemGray
        }
        
        let lowPriority = MKFeatureDisplayPriority.defaultLow.rawValue
        let highPriority = MKFeatureDisplayPriority.defaultHigh.rawValue
        let normalizeMagnitude = min(max(Float(quake.magnitude), 0), 10)
        
        annotationView.displayPriority = MKFeatureDisplayPriority(lowPriority + (highPriority - lowPriority) * normalizeMagnitude / 10)
        
        return annotationView
    }
}
