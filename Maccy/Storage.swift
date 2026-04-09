import CoreData
import Foundation

@MainActor
protocol HistoryStore: AnyObject {
  var sizeDescription: String { get }

  func loadItems() throws -> [HistoryItem]
  func insert(_ item: HistoryItem) throws
  func save(_ item: HistoryItem) throws
  func delete(_ item: HistoryItem) throws
  func deleteAll() throws
  func deleteUnpinned() throws
  func fetchCounts() -> (items: Int, contents: Int)
}

@MainActor
final class StorageContext {
  func insert(_ item: HistoryItem) {
    item.prepareForPersistence()
  }

  func save() throws {}
}

@MainActor
final class Storage {
  enum Configuration {
    case automatic
    case inMemory
    case persistent(url: URL)
  }

  static let shared = Storage()

  let store: HistoryStore
  let context: StorageContext

  var size: String { store.sizeDescription }

  init(
    configuration: Configuration = .automatic,
    store: HistoryStore? = nil,
    context: StorageContext? = nil
  ) {
    self.store = store ?? Storage.makeStore(configuration: configuration)
    self.context = context ?? StorageContext()
  }
}

private extension Storage {
  static func makeStore(configuration: Storage.Configuration) -> HistoryStore {
    do {
      switch configuration {
      case .automatic:
        return try CoreDataHistoryStore(
          configuration: isRunningTests ? .inMemory : .persistent(url: nil)
        )
      case .inMemory:
        return try CoreDataHistoryStore(configuration: .inMemory)
      case .persistent(let url):
        return try CoreDataHistoryStore(configuration: .persistent(url: url))
      }
    } catch {
      assertionFailure("Failed to initialize storage: \(error)")
      return InMemoryHistoryStore()
    }
  }

  static var isRunningTests: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
  }
}

@MainActor
private final class CoreDataHistoryStore: HistoryStore {
  enum Configuration {
    case persistent(url: URL?)
    case inMemory
  }

  private let coordinator: NSPersistentStoreCoordinator
  private let context: NSManagedObjectContext
  private let persistentStoreURL: URL?

  var sizeDescription: String {
    guard let persistentStoreURL else {
      return ""
    }

    let fileManager = FileManager.default
    let relatedURLs = [
      persistentStoreURL,
      URL(fileURLWithPath: persistentStoreURL.path + "-shm"),
      URL(fileURLWithPath: persistentStoreURL.path + "-wal")
    ]

    let byteCount = relatedURLs.reduce(into: Int64(0)) { result, url in
      guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? NSNumber else {
        return
      }

      result += size.int64Value
    }

    guard byteCount > 0 else {
      return ""
    }

    return ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
  }

  init(configuration: Configuration) throws {
    let model = Self.makeManagedObjectModel()
    coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    switch configuration {
    case .persistent(let url):
      persistentStoreURL = try Self.makePersistentStoreURL(overrideURL: url)
    case .inMemory:
      persistentStoreURL = nil
    }

    let storeType: String
    let storeURL: URL?
    let options: [AnyHashable: Any] = [
      NSInferMappingModelAutomaticallyOption: true,
      NSMigratePersistentStoresAutomaticallyOption: true
    ]

    switch configuration {
    case .persistent:
      storeType = NSSQLiteStoreType
      storeURL = persistentStoreURL
    case .inMemory:
      storeType = NSInMemoryStoreType
      storeURL = nil
    }

    try coordinator.addPersistentStore(
      ofType: storeType,
      configurationName: nil,
      at: storeURL,
      options: options
    )
  }

  func loadItems() throws -> [HistoryItem] {
    let managedItems = try context.fetch(ManagedHistoryItem.fetchRequestAll())
    return managedItems.map { managedItem in
      Self.makeHistoryItem(from: managedItem)
    }
  }

  func insert(_ item: HistoryItem) throws {
    try save(item)
  }

  func save(_ item: HistoryItem) throws {
    let managedItem = try managedItem(for: item) ?? ManagedHistoryItem(context: context)
    apply(item, to: managedItem)
    try saveContextIfNeeded()
    item.storageURI = managedItem.objectID.uriRepresentation()
  }

  func delete(_ item: HistoryItem) throws {
    guard let managedItem = try managedItem(for: item) else {
      return
    }

    context.delete(managedItem)
    try saveContextIfNeeded()
    item.storageURI = nil
  }

  func deleteAll() throws {
    try context.fetch(ManagedHistoryItem.fetchRequestAll()).forEach(context.delete)
    try saveContextIfNeeded()
  }

  func deleteUnpinned() throws {
    let request = ManagedHistoryItem.fetchRequestAll()
    request.predicate = NSPredicate(format: "pin == nil")
    try context.fetch(request).forEach(context.delete)
    try saveContextIfNeeded()
  }

  func fetchCounts() -> (items: Int, contents: Int) {
    let itemsCount = (try? context.count(for: ManagedHistoryItem.fetchRequestAll())) ?? 0
    let contentsCount = (try? context.count(for: ManagedHistoryItemContent.fetchRequestAll())) ?? 0
    return (itemsCount, contentsCount)
  }

  private func managedItem(for item: HistoryItem) throws -> ManagedHistoryItem? {
    guard let storageURI = item.storageURI,
          let objectID = coordinator.managedObjectID(forURIRepresentation: storageURI) else {
      return nil
    }

    return try context.existingObject(with: objectID) as? ManagedHistoryItem
  }

  private func apply(_ item: HistoryItem, to managedItem: ManagedHistoryItem) {
    managedItem.application = item.application
    managedItem.firstCopiedAt = item.firstCopiedAt
    managedItem.lastCopiedAt = item.lastCopiedAt
    managedItem.numberOfCopies = Int64(item.numberOfCopies)
    managedItem.pin = item.pin
    managedItem.title = item.title

    (managedItem.contents ?? []).forEach(context.delete)
    managedItem.contents = Set(item.contents.map { content in
      let managedContent = ManagedHistoryItemContent(context: context)
      managedContent.type = content.type
      managedContent.value = content.value
      managedContent.item = managedItem
      return managedContent
    })
  }

  private func saveContextIfNeeded() throws {
    guard context.hasChanges else {
      return
    }

    try context.save()
  }

  private static func makePersistentStoreURL(overrideURL: URL?) throws -> URL {
    if let overrideURL {
      let directoryURL = overrideURL.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
      return overrideURL
    }

    let fileManager = FileManager.default
    let directoryURL = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    ).appendingPathComponent("Maccy", isDirectory: true)

    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
    return directoryURL.appendingPathComponent("Storage.sqlite")
  }

  private static func makeHistoryItem(from managedItem: ManagedHistoryItem) -> HistoryItem {
    let contents = (managedItem.contents ?? [])
      .sorted { ($0.type ?? "") < ($1.type ?? "") }
      .map { managedContent in
        makeHistoryItemContent(from: managedContent)
      }

    let item = HistoryItem(contents: contents, firstCopiedAt: managedItem.firstCopiedAt, lastCopiedAt: managedItem.lastCopiedAt)
    item.application = managedItem.application
    item.numberOfCopies = Int(managedItem.numberOfCopies)
    item.pin = managedItem.pin
    item.title = managedItem.title ?? ""
    item.storageURI = managedItem.objectID.uriRepresentation()

    for content in item.contents {
      content.item = item
    }

    return item
  }

  private static func makeHistoryItemContent(from managedContent: ManagedHistoryItemContent) -> HistoryItemContent {
    HistoryItemContent(type: managedContent.type ?? "", value: managedContent.value)
  }

  private static func makeManagedObjectModel() -> NSManagedObjectModel {
    let itemEntity = NSEntityDescription()
    itemEntity.name = "HistoryItem"
    itemEntity.managedObjectClassName = NSStringFromClass(ManagedHistoryItem.self)

    let contentEntity = NSEntityDescription()
    contentEntity.name = "HistoryItemContent"
    contentEntity.managedObjectClassName = NSStringFromClass(ManagedHistoryItemContent.self)

    let applicationAttribute = NSAttributeDescription()
    applicationAttribute.name = "application"
    applicationAttribute.attributeType = .stringAttributeType
    applicationAttribute.isOptional = true

    let firstCopiedAtAttribute = NSAttributeDescription()
    firstCopiedAtAttribute.name = "firstCopiedAt"
    firstCopiedAtAttribute.attributeType = .dateAttributeType
    firstCopiedAtAttribute.isOptional = false

    let lastCopiedAtAttribute = NSAttributeDescription()
    lastCopiedAtAttribute.name = "lastCopiedAt"
    lastCopiedAtAttribute.attributeType = .dateAttributeType
    lastCopiedAtAttribute.isOptional = false

    let numberOfCopiesAttribute = NSAttributeDescription()
    numberOfCopiesAttribute.name = "numberOfCopies"
    numberOfCopiesAttribute.attributeType = .integer64AttributeType
    numberOfCopiesAttribute.defaultValue = 0
    numberOfCopiesAttribute.isOptional = false

    let pinAttribute = NSAttributeDescription()
    pinAttribute.name = "pin"
    pinAttribute.attributeType = .stringAttributeType
    pinAttribute.isOptional = true

    let titleAttribute = NSAttributeDescription()
    titleAttribute.name = "title"
    titleAttribute.attributeType = .stringAttributeType
    titleAttribute.isOptional = true

    let typeAttribute = NSAttributeDescription()
    typeAttribute.name = "type"
    typeAttribute.attributeType = .stringAttributeType
    typeAttribute.isOptional = true

    let valueAttribute = NSAttributeDescription()
    valueAttribute.name = "value"
    valueAttribute.attributeType = .binaryDataAttributeType
    valueAttribute.isOptional = true

    let contentsRelationship = NSRelationshipDescription()
    contentsRelationship.name = "contents"
    contentsRelationship.destinationEntity = contentEntity
    contentsRelationship.minCount = 0
    contentsRelationship.maxCount = 0
    contentsRelationship.deleteRule = .cascadeDeleteRule
    contentsRelationship.isOptional = true
    contentsRelationship.isOrdered = false

    let itemRelationship = NSRelationshipDescription()
    itemRelationship.name = "item"
    itemRelationship.destinationEntity = itemEntity
    itemRelationship.minCount = 0
    itemRelationship.maxCount = 1
    itemRelationship.deleteRule = .nullifyDeleteRule
    itemRelationship.isOptional = true
    itemRelationship.isOrdered = false

    contentsRelationship.inverseRelationship = itemRelationship
    itemRelationship.inverseRelationship = contentsRelationship

    itemEntity.properties = [
      applicationAttribute,
      firstCopiedAtAttribute,
      lastCopiedAtAttribute,
      numberOfCopiesAttribute,
      pinAttribute,
      titleAttribute,
      contentsRelationship
    ]
    contentEntity.properties = [
      typeAttribute,
      valueAttribute,
      itemRelationship
    ]

    let model = NSManagedObjectModel()
    model.entities = [itemEntity, contentEntity]
    return model
  }
}

@objc(ManagedHistoryItem)
private final class ManagedHistoryItem: NSManagedObject {
  @NSManaged var application: String?
  @NSManaged var firstCopiedAt: Date
  @NSManaged var lastCopiedAt: Date
  @NSManaged var numberOfCopies: Int64
  @NSManaged var pin: String?
  @NSManaged var title: String?
  @NSManaged var contents: Set<ManagedHistoryItemContent>?

  @nonobjc
  static func fetchRequestAll() -> NSFetchRequest<ManagedHistoryItem> {
    NSFetchRequest<ManagedHistoryItem>(entityName: "HistoryItem")
  }
}

@objc(ManagedHistoryItemContent)
private final class ManagedHistoryItemContent: NSManagedObject {
  @NSManaged var type: String?
  @NSManaged var value: Data?
  @NSManaged var item: ManagedHistoryItem?

  @nonobjc
  static func fetchRequestAll() -> NSFetchRequest<ManagedHistoryItemContent> {
    NSFetchRequest<ManagedHistoryItemContent>(entityName: "HistoryItemContent")
  }
}

@MainActor
private final class InMemoryHistoryStore: HistoryStore {
  private var items: [HistoryItem] = []

  var sizeDescription: String { "" }

  func loadItems() throws -> [HistoryItem] {
    items
  }

  func insert(_ item: HistoryItem) throws {
    try save(item)
  }

  func save(_ item: HistoryItem) throws {
    if !items.contains(where: { $0 === item }) {
      items.append(item)
    }
  }

  func delete(_ item: HistoryItem) throws {
    items.removeAll { $0 === item }
  }

  func deleteAll() throws {
    items.removeAll()
  }

  func deleteUnpinned() throws {
    items.removeAll { $0.pin == nil }
  }

  func fetchCounts() -> (items: Int, contents: Int) {
    (items.count, items.reduce(into: 0) { $0 += $1.contents.count })
  }
}
