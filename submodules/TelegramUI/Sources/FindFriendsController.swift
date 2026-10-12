import Foundation
import UIKit
import MapKit
import CoreLocation
import Display
import AsyncDisplayKit
import TelegramPresentationData
import AccountContext

/// A single entry in the mock "nearby friends" list. All coordinates and names are made up —
/// nothing here is read from or sent to any server, and no real location is shared.
private struct MockFriend {
    enum Status {
        case online
        case recentlyActive
        case offline
    }
    let name: String
    let initials: String
    let tintHue: CGFloat
    let status: Status
    let distanceMeters: Double
    let lastSeenMinutesAgo: Double?
    let latitudeOffset: Double
    let longitudeOffset: Double
}

/// Offsets are in degrees (roughly metres / 111,000), scattered around the centre so the
/// pins read clearly at a city-block zoom level without overlapping.
private let mockFriends: [MockFriend] = [
    MockFriend(name: "Alicia Brown", initials: "AB", tintHue: 0.58, status: .online, distanceMeters: 240, lastSeenMinutesAgo: nil, latitudeOffset: 0.0021, longitudeOffset: 0.0014),
    MockFriend(name: "Dmytro K.", initials: "DK", tintHue: 0.08, status: .online, distanceMeters: 680, lastSeenMinutesAgo: nil, latitudeOffset: -0.0016, longitudeOffset: 0.0032),
    MockFriend(name: "Rhodora V.", initials: "RV", tintHue: 0.92, status: .recentlyActive, distanceMeters: 1150, lastSeenMinutesAgo: 8, latitudeOffset: 0.0034, longitudeOffset: -0.0025),
    MockFriend(name: "Fauzaan S.", initials: "FS", tintHue: 0.42, status: .online, distanceMeters: 390, lastSeenMinutesAgo: nil, latitudeOffset: -0.0009, longitudeOffset: -0.0021),
    MockFriend(name: "Thilaga V.", initials: "TV", tintHue: 0.75, status: .recentlyActive, distanceMeters: 2050, lastSeenMinutesAgo: 24, latitudeOffset: 0.0048, longitudeOffset: 0.0040),
    MockFriend(name: "Deversh D.", initials: "DD", tintHue: 0.17, status: .offline, distanceMeters: 3400, lastSeenMinutesAgo: 190, latitudeOffset: -0.0041, longitudeOffset: 0.0018),
    MockFriend(name: "Margarette A.", initials: "MA", tintHue: 0.65, status: .offline, distanceMeters: 5200, lastSeenMinutesAgo: 540, latitudeOffset: 0.0012, longitudeOffset: -0.0048),
    MockFriend(name: "Gustavo M.", initials: "GM", tintHue: 0.03, status: .online, distanceMeters: 960, lastSeenMinutesAgo: nil, latitudeOffset: -0.0026, longitudeOffset: -0.0009)
]

/// Toronto downtown — just a pleasant, recognisable default centre for the mock map. Used
/// only when the device declines or has not yet resolved a real location.
private let fallbackCenter = CLLocationCoordinate2D(latitude: 43.6511, longitude: -79.3837)

private func statusColor(_ status: MockFriend.Status) -> UIColor {
    switch status {
    case .online:
        return UIColor(rgb: 0x34c759)
    case .recentlyActive:
        return UIColor(rgb: 0xffa033)
    case .offline:
        return UIColor(rgb: 0x8e8e93)
    }
}

private func distanceString(_ meters: Double) -> String {
    if meters < 1000 {
        return "\(Int(meters)) m away"
    } else {
        return String(format: "%.1f km away", meters / 1000.0)
    }
}

private func lastSeenString(_ friend: MockFriend) -> String {
    switch friend.status {
    case .online:
        return "Online now"
    case .recentlyActive, .offline:
        guard let minutes = friend.lastSeenMinutesAgo else {
            return "Offline"
        }
        if minutes < 60 {
            return "Active \(Int(minutes))m ago"
        } else {
            return "Active \(Int(minutes / 60.0))h ago"
        }
    }
}

/// A custom pin: a soft glass bubble with the friend's initials, a coloured status ring that
/// pulses for online friends, and a small shadow — the same visual language as the profile
/// "dancing bubbles" aurora used elsewhere in the app.
private final class FriendAnnotation: NSObject, MKAnnotation {
    let friend: MockFriend
    let coordinate: CLLocationCoordinate2D

    init(friend: MockFriend, center: CLLocationCoordinate2D) {
        self.friend = friend
        self.coordinate = CLLocationCoordinate2D(latitude: center.latitude + friend.latitudeOffset, longitude: center.longitude + friend.longitudeOffset)
    }
}

private let friendAnnotationReuseIdentifier = "FriendAnnotation"

private final class FriendAnnotationView: MKAnnotationView {
    private let bubble = UIView()
    private let initialsLabel = UILabel()
    private let statusRing = CAShapeLayer()
    private let pulseLayer = CAShapeLayer()

    override var annotation: MKAnnotation? {
        didSet {
            self.configure()
        }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        let side: CGFloat = 46.0
        self.frame = CGRect(x: 0.0, y: 0.0, width: side, height: side)
        self.centerOffset = CGPoint(x: 0.0, y: -side / 2.0)
        self.canShowCallout = true

        self.bubble.frame = self.bounds.insetBy(dx: 4.0, dy: 4.0)
        self.bubble.layer.cornerRadius = self.bubble.bounds.width / 2.0
        self.bubble.layer.borderWidth = 2.0
        self.bubble.layer.borderColor = UIColor.white.cgColor
        self.bubble.layer.shadowColor = UIColor.black.cgColor
        self.bubble.layer.shadowOpacity = 0.25
        self.bubble.layer.shadowRadius = 4.0
        self.bubble.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
        self.bubble.clipsToBounds = false

        self.initialsLabel.font = .systemFont(ofSize: 15.0, weight: .semibold)
        self.initialsLabel.textColor = .white
        self.initialsLabel.textAlignment = .center
        self.initialsLabel.frame = self.bubble.bounds.insetBy(dx: 2.0, dy: 2.0)

        self.bubble.addSubview(self.initialsLabel)
        self.addSubview(self.bubble)

        self.pulseLayer.fillColor = nil
        self.layer.insertSublayer(self.pulseLayer, below: self.bubble.layer)

        self.statusRing.fillColor = UIColor.white.cgColor
        self.statusRing.strokeColor = UIColor.white.cgColor
        self.layer.addSublayer(self.statusRing)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        guard let friendAnnotation = self.annotation as? FriendAnnotation else {
            return
        }
        let friend = friendAnnotation.friend
        let tint = UIColor(hue: friend.tintHue, saturation: 0.55, brightness: 0.95, alpha: 1.0)

        self.bubble.backgroundColor = tint
        self.initialsLabel.text = friend.initials

        let dotSide: CGFloat = 13.0
        let dotFrame = CGRect(x: self.bounds.width - dotSide - 1.0, y: self.bounds.height - dotSide - 5.0, width: dotSide, height: dotSide)
        self.statusRing.path = UIBezierPath(ovalIn: dotFrame.insetBy(dx: 1.5, dy: 1.5)).cgPath
        self.statusRing.fillColor = statusColor(friend.status).cgColor
        self.statusRing.strokeColor = UIColor.white.cgColor
        self.statusRing.lineWidth = 2.0

        self.pulseLayer.removeAllAnimations()
        if friend.status == .online, !UIAccessibility.isReduceMotionEnabled {
            self.pulseLayer.path = UIBezierPath(ovalIn: dotFrame.insetBy(dx: -4.0, dy: -4.0)).cgPath
            self.pulseLayer.fillColor = statusColor(friend.status).withAlphaComponent(0.5).cgColor
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 0.6
            pulse.toValue = 1.6
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.9
            fade.toValue = 0.0
            let group = CAAnimationGroup()
            group.animations = [pulse, fade]
            group.duration = 1.6
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.pulseLayer.add(group, forKey: "statusPulse")
        } else {
            self.pulseLayer.path = nil
        }
    }

    func animateDrop(delay: Double) {
        self.alpha = 0.0
        self.transform = CGAffineTransform(translationX: 0.0, y: -28.0).concatenating(CGAffineTransform(scaleX: 0.5, y: 0.5))
        if UIAccessibility.isReduceMotionEnabled {
            self.alpha = 1.0
            self.transform = .identity
            return
        }
        UIView.animate(withDuration: 0.55, delay: delay, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.4, options: [], animations: {
            self.alpha = 1.0
            self.transform = .identity
        })
    }

    func bounceSelected() {
        if UIAccessibility.isReduceMotionEnabled {
            return
        }
        UIView.animate(withDuration: 0.18, animations: {
            self.transform = CGAffineTransform(scaleX: 1.22, y: 1.22)
        }, completion: { _ in
            UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.6, options: [], animations: {
                self.transform = .identity
            })
        })
    }
}

/// The bottom carousel card for one friend.
private final class FriendCardCell: UICollectionViewCell {
    private let avatarView = UIView()
    private let initialsLabel = UILabel()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let statusDot = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.contentView.backgroundColor = UIColor(rgb: 0x1c1c1e)
        self.contentView.layer.cornerRadius = 18.0
        self.contentView.layer.cornerCurve = .continuous

        self.avatarView.layer.cornerRadius = 20.0
        self.initialsLabel.font = .systemFont(ofSize: 15.0, weight: .semibold)
        self.initialsLabel.textColor = .white
        self.initialsLabel.textAlignment = .center

        self.nameLabel.font = .systemFont(ofSize: 14.0, weight: .semibold)
        self.nameLabel.textColor = .white

        self.detailLabel.font = .systemFont(ofSize: 12.0, weight: .regular)
        self.detailLabel.textColor = UIColor.white.withAlphaComponent(0.6)

        self.statusDot.layer.cornerRadius = 4.0

        self.avatarView.addSubview(self.initialsLabel)
        self.contentView.addSubview(self.avatarView)
        self.contentView.addSubview(self.nameLabel)
        self.contentView.addSubview(self.detailLabel)
        self.contentView.addSubview(self.statusDot)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with friend: MockFriend) {
        self.avatarView.backgroundColor = UIColor(hue: friend.tintHue, saturation: 0.55, brightness: 0.95, alpha: 1.0)
        self.initialsLabel.text = friend.initials
        self.nameLabel.text = friend.name
        self.detailLabel.text = "\(distanceString(friend.distanceMeters)) · \(lastSeenString(friend))"
        self.statusDot.backgroundColor = statusColor(friend.status)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.avatarView.frame = CGRect(x: 12.0, y: 12.0, width: 40.0, height: 40.0)
        self.initialsLabel.frame = self.avatarView.bounds
        self.statusDot.frame = CGRect(x: 44.0, y: 44.0, width: 8.0, height: 8.0)

        let textX: CGFloat = 62.0
        self.nameLabel.frame = CGRect(x: textX, y: 14.0, width: self.contentView.bounds.width - textX - 12.0, height: 18.0)
        self.detailLabel.frame = CGRect(x: textX, y: 34.0, width: self.contentView.bounds.width - textX - 12.0, height: 16.0)
    }
}

/// "Search with friends" tab: a map with mock nearby friends and a bottom carousel to jump
/// between them. Entirely local/mock data — there is no network request, no real location is
/// shared with anyone, and the on-device location (if granted) is used only to pick a pleasant
/// map centre for the fake pins.
public final class FindFriendsController: ViewController, CLLocationManagerDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData

    private var mapView: MKMapView?
    private var carouselView: UICollectionView?
    private let locationManager = CLLocationManager()
    private var mapCenter = fallbackCenter
    private var didPlaceAnnotations = false

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

        self.tabBarItem.title = "Friends"
        self.tabBarItem.image = UIImage(systemName: "person.2.wave.2.fill")
        self.tabBarItem.selectedImage = UIImage(systemName: "person.2.wave.2.fill")
        self.title = "Search with Friends"

        self.locationManager.delegate = self
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func displayNodeDidLoad() {
        super.displayNodeDidLoad()

        self.displayNode.backgroundColor = .black

        let mapView = MKMapView()
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsUserLocation = true
        mapView.delegate = self
        mapView.register(FriendAnnotationView.self, forAnnotationViewWithReuseIdentifier: friendAnnotationReuseIdentifier)
        self.displayNode.view.addSubview(mapView)
        self.mapView = mapView

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 220.0, height: 64.0)
        layout.minimumLineSpacing = 10.0
        layout.sectionInset = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        let carouselView = UICollectionView(frame: CGRect(), collectionViewLayout: layout)
        carouselView.backgroundColor = .clear
        carouselView.showsHorizontalScrollIndicator = false
        carouselView.dataSource = self
        carouselView.delegate = self
        carouselView.register(FriendCardCell.self, forCellWithReuseIdentifier: "FriendCard")
        self.displayNode.view.addSubview(carouselView)
        self.carouselView = carouselView

        self.requestLocationIfPossible()
        self.placeAnnotations(animateIn: true)
    }

    private func requestLocationIfPossible() {
        switch self.locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            self.locationManager.requestLocation()
        case .notDetermined:
            self.locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.requestLocationIfPossible()
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }
        self.mapCenter = location.coordinate
        self.placeAnnotations(animateIn: false)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Mock data still shows around the fallback centre — a denied or unavailable location
        // is not an error state for this screen.
    }

    private func placeAnnotations(animateIn: Bool) {
        guard let mapView = self.mapView else {
            return
        }
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        let annotations = mockFriends.map { FriendAnnotation(friend: $0, center: self.mapCenter) }
        mapView.addAnnotations(annotations)

        let region = MKCoordinateRegion(center: self.mapCenter, latitudinalMeters: 6500.0, longitudinalMeters: 6500.0)
        mapView.setRegion(region, animated: !self.didPlaceAnnotations ? false : true)
        self.didPlaceAnnotations = true
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        guard let mapView = self.mapView, let carouselView = self.carouselView else {
            return
        }
        let navigationHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        let mapFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationHeight))
        transition.updateFrame(view: mapView, frame: mapFrame)

        let carouselHeight: CGFloat = 80.0
        let carouselFrame = CGRect(x: 0.0, y: layout.size.height - carouselHeight - layout.intrinsicInsets.bottom, width: layout.size.width, height: carouselHeight)
        transition.updateFrame(view: carouselView, frame: carouselFrame)
        mapView.layoutMargins = UIEdgeInsets(top: 0.0, left: 0.0, bottom: carouselHeight + layout.intrinsicInsets.bottom, right: 0.0)
    }

    fileprivate func focusOnFriend(_ friend: MockFriend) {
        guard let mapView = self.mapView else {
            return
        }
        let coordinate = CLLocationCoordinate2D(latitude: self.mapCenter.latitude + friend.latitudeOffset, longitude: self.mapCenter.longitude + friend.longitudeOffset)
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 1400.0, longitudinalMeters: 1400.0)
        mapView.setRegion(region, animated: true)

        if let annotation = mapView.annotations.compactMap({ $0 as? FriendAnnotation }).first(where: { $0.friend.name == friend.name }) {
            mapView.selectAnnotation(annotation, animated: true)
            if let view = mapView.view(for: annotation) as? FriendAnnotationView {
                view.bounceSelected()
            }
        }
    }
}

extension FindFriendsController: MKMapViewDelegate {
    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is FriendAnnotation else {
            return nil
        }
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: friendAnnotationReuseIdentifier, for: annotation) as! FriendAnnotationView
        return view
    }

    public func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        for (index, view) in views.enumerated() {
            if let friendView = view as? FriendAnnotationView {
                friendView.animateDrop(delay: Double(index) * 0.06)
            }
        }
    }
}

extension FindFriendsController: UICollectionViewDataSource, UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return mockFriends.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FriendCard", for: indexPath) as! FriendCardCell
        cell.configure(with: mockFriends[indexPath.item])
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        self.focusOnFriend(mockFriends[indexPath.item])
    }
}
