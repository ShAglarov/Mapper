//
//  SavedPoint.swift
//  Mapper
//
//  Created by Murad Tataev on 23.05.2025.
//

import UIKit
import MapKit
import RealmSwift

class SavedPoint: Object {
    @objc dynamic var name: String = ""
    @objc dynamic var latitude: Double = 0.0
    @objc dynamic var longitude: Double = 0.0

    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    convenience init(name: String, latitude: Double, longitude: Double) {
        self.init()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}
