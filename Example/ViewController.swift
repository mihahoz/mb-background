//
//  ViewController.swift
//  Example
//
//  Created by Miha Hozjan on 08/11/2022.
//

import UIKit
import Combine
import CoreLocation
import MapboxMaps

public class ViewController: UIViewController {

    let locationProvider = CustomLocationProvider()
    var bag = Set<AnyCancellable>()

    internal var mapView: MapView!
    internal var cameraLocationConsumer: CameraLocationConsumer!
    internal let toggleBearingImageButton: UIButton = UIButton(frame: .zero)
    internal var showsBearingImage: Bool = false {
        didSet {
            syncPuckAndButton()
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        locationProvider.requestAlwaysAuthorization()

        // Set initial camera settings
        let options = MapInitOptions(cameraOptions: CameraOptions(zoom: 15.0))

        mapView = MapView(frame: view.bounds, mapInitOptions: options)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)

        // Setup and create button for toggling show bearing image
        setupToggleShowBearingImageButton()

        cameraLocationConsumer = CameraLocationConsumer(mapView: mapView)

        // Add user position icon to the map with location indicator layer
        mapView.location.options.puckType = .puck2D()

        // Allows the delegate to receive information about map events.
        mapView.mapboxMap.onNext(.mapLoaded) { [unowned self] _ in

            // Set a custom location provider
            self.mapView.location.overrideLocationProvider(with: locationProvider)

            // Register the location consumer with the map
            // Note that the location manager holds weak references to consumers, which should be retained
            self.mapView.location.addLocationConsumer(newConsumer: self.cameraLocationConsumer)

//            self.finish() // Needed for internal testing purposes.
        }

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] _ in
                self.locationProvider.startUpdatingLocation()
            }
            .store(in: &bag)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] _ in
                self.locationProvider.stopUpdatingLocation()
            }
            .store(in: &bag)
    }

    @objc func showHideBearingImage() {
        showsBearingImage.toggle()
    }

    func syncPuckAndButton() {
        // Update puck config
        let configuration = Puck2DConfiguration.makeDefault(showBearing: showsBearingImage)

        mapView.location.options.puckType = .puck2D(configuration)

        // Update button title
        let title: String = showsBearingImage ? "Hide bearing image" : "Show bearing image"
        toggleBearingImageButton.setTitle(title, for: .normal)
    }

    private func setupToggleShowBearingImageButton() {
        // Styling
        toggleBearingImageButton.backgroundColor = .systemBlue
        toggleBearingImageButton.addTarget(self, action: #selector(showHideBearingImage), for: .touchUpInside)
        toggleBearingImageButton.setTitleColor(.white, for: .normal)
        syncPuckAndButton()
        toggleBearingImageButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toggleBearingImageButton)

        // Constraints
        toggleBearingImageButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20.0).isActive = true
        toggleBearingImageButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20.0).isActive = true
        toggleBearingImageButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100.0).isActive = true
    }
}

// Create class which conforms to LocationConsumer, update the camera's centerCoordinate when a locationUpdate is received
public class CameraLocationConsumer: LocationConsumer {
    weak var mapView: MapView?

    init(mapView: MapView) {
        self.mapView = mapView
    }

    public func locationUpdate(newLocation: Location) {
        mapView?.camera.ease(
            to: CameraOptions(center: newLocation.coordinate, zoom: 15),
            duration: 1.3)
    }
}

class CustomLocationProvider: NSObject, LocationProvider {

    private let locationManager: CLLocationManager
    private var _locationProviderOptions: LocationOptions = .init()
    private weak var delegate: LocationProviderDelegate?

    override init() {
        locationManager = CLLocationManager()

        super.init()

        locationManager.delegate = self
    }

    // MARK: - Confirming to `LocationProvider`

    var locationProviderOptions: LocationOptions {
        get { _locationProviderOptions }
        set { _locationProviderOptions = newValue }
    }

    var authorizationStatus: CLAuthorizationStatus {
        get { locationManager.authorizationStatus }
    }

    var accuracyAuthorization: CLAccuracyAuthorization {
        get { locationManager.accuracyAuthorization }
    }

    var heading: CLHeading? {
        get { locationManager.heading }
    }

    var headingOrientation: CLDeviceOrientation {
        get { locationManager.headingOrientation }
        set { locationManager.headingOrientation = newValue }
    }

    func setDelegate(_ delegate: LocationProviderDelegate) {
        self.delegate = delegate
    }

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestTemporaryFullAccuracyAuthorization(withPurposeKey purposeKey: String) {
        locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: purposeKey)
    }

    func startUpdatingLocation() {
        print("-> start updating location")
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        print("-> stop updating location")
        locationManager.stopUpdatingLocation()
    }

    func startUpdatingHeading() {
        print("-> start updating heading")
        locationManager.startUpdatingHeading()
    }

    func stopUpdatingHeading() {
        print("-> stop updating heading")
        locationManager.stopUpdatingHeading()
    }

    func dismissHeadingCalibrationDisplay() {
        locationManager.dismissHeadingCalibrationDisplay()
    }
}

extension CustomLocationProvider: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("-> did update location: \(locations.map(\.coordinate))")
        delegate?.locationProvider(self, didUpdateLocations: locations)
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        delegate?.locationProvider(self, didUpdateHeading: newHeading)
    }
}
