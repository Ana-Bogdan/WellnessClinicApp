import CoreData
import Foundation

/// Manages the Core Data stack and provides access to managed object contexts
final class PersistenceController: @unchecked Sendable {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    /// Main context for UI updates (runs on main thread)
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Background context for database operations (runs on background thread)
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    private init() {
        container = NSPersistentContainer(name: "CliniqueHarmonyModel")

        container.loadPersistentStores { description, error in
            if let error = error {
                // Log the error - in production, you might want to send this to a crash reporting service
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }

            // Log database location for debugging
            if let url = description.url {
                print("Core Data Database Location:")
                print("\(url.path)")
            }
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Saves the context if there are changes
    func save(context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}
