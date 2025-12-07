import CoreData
import Foundation
import OSLog

/// Seeds initial data into the database on first launch
@MainActor
final class DataSeeder {
    private static let logger = Logger(subsystem: "com.cliniqueharmony", category: "DataSeeder")
    private static let hasSeededKey = "hasSeededInitialData"
    
    /// Seeds initial data if it hasn't been seeded before
    static func seedIfNeeded() async {
        let hasSeeded = UserDefaults.standard.bool(forKey: hasSeededKey)
        
        if hasSeeded {
            logger.info("Data already seeded, skipping")
            return
        }
        
        logger.info("Seeding initial data...")
        
        let context = PersistenceController.shared.newBackgroundContext()
        
        await withCheckedContinuation { continuation in
            context.perform {
                do {
                    // Seed sample appointments if database is empty
                    let fetchRequest = NSFetchRequest<AppointmentEntity>(entityName: "AppointmentEntity")
                    let existingCount = try context.count(for: fetchRequest)
                    
                    if existingCount == 0 {
                        // Create sample appointments
                        let calendar = Calendar.current
                        let now = Date()
                        let upcoming = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 6, to: now) ?? now) ?? now
                        let completed1 = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: now) ?? now) ?? now
                        let completed2 = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -30, to: now) ?? now) ?? now
                        
                        let appointments: [(id: String, userID: String, practitionerID: String, service: String, date: Date, status: AppointmentStatus)] = [
                            ("apt-1", "user-1", "prac-2", "Deep Tissue Massage", upcoming, .booked),
                            ("apt-2", "user-1", "prac-1", "Initial Consultation", completed1, .completed),
                            ("apt-3", "user-1", "prac-3", "Initial Assessment", completed2, .completed)
                        ]
                        
                        for appointmentData in appointments {
                            let entity = AppointmentEntity(context: context)
                            entity.id = appointmentData.id
                            entity.userID = appointmentData.userID
                            entity.practitionerID = appointmentData.practitionerID
                            entity.service = appointmentData.service
                            entity.date = appointmentData.date
                            entity.status = appointmentData.status.rawValue
                        }
                        
                        logger.info("Seeded \(appointments.count) sample appointments")
                    }
                    
                    try PersistenceController.shared.save(context: context)
                    
                    UserDefaults.standard.set(true, forKey: hasSeededKey)
                    logger.info("Initial data seeding completed")
                    
                    Task { @MainActor in
                        continuation.resume()
                    }
                } catch {
                    logger.error("Failed to seed initial data: \(error.localizedDescription)")
                    Task { @MainActor in
                        continuation.resume()
                    }
                }
            }
        }
    }
}
