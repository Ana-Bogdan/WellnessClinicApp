import Foundation

struct User: Identifiable {
    let id: String
    var name: String
    var email: String
    var phone: String
}

struct Practitioner: Identifiable, Hashable {
    let id: String
    var name: String
    var specialty: String
    var bio: String
    var photoURL: URL?
    var rating: Double
}

enum AppointmentStatus: String, Codable, CaseIterable {
    case booked = "Booked"
    case completed = "Completed"
    case canceled = "Canceled"
}

struct Appointment: Identifiable, Hashable {
    let id: String
    var userID: String
    var practitionerID: String
    var service: String
    var date: Date
    var status: AppointmentStatus
}

struct Service: Identifiable, Hashable {
    let id: String
    var title: String
    var description: String
    var imageURL: URL?
    var iconName: String
}
