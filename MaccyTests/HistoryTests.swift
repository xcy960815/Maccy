import XCTest
import Defaults
import CoreData
@testable import Maccy

@MainActor
class HistoryTests: XCTestCase {
  private struct LegacyItemSeed {
    var application: String
    var firstCopiedAt: Date
    var lastCopiedAt: Date
    var numberOfCopies: Int64
    var pin: String?
    var title: String
    var contents: [(type: String, value: Data?)]
  }

  let savedSize = Defaults[.size]
  let savedSortBy = Defaults[.sortBy]
  let history = History.shared

  override func setUp() {
    super.setUp()
    history.clearAll()
    Defaults[.size] = 10
    Defaults[.sortBy] = .firstCopiedAt
  }

  override func tearDown() {
    super.tearDown()
    Defaults[.size] = savedSize
    Defaults[.sortBy] = savedSortBy
  }

  func testDefaultIsEmpty() {
    XCTAssertEqual(history.items, [])
  }

  func testAdding() {
    let first = history.add(historyItem("foo"))
    let second = history.add(historyItem("bar"))
    XCTAssertEqual(history.items, [second, first])
  }

  func testAddingSame() {
    let first = historyItem("foo")
    first.title = "xyz"
    first.application = "iTerm.app"
    let firstDecorator = history.add(first)
    first.pin = "f"

    let secondDecorator = history.add(historyItem("bar"))

    let third = historyItem("foo")
    third.application = "Xcode.app"
    history.add(third)

    XCTAssertEqual(history.items, [firstDecorator, secondDecorator])
    XCTAssertTrue(history.items[0].item.lastCopiedAt > history.items[0].item.firstCopiedAt)
    // TODO: This works in reality but fails in tests?!
    // XCTAssertEqual(history.items[0].item.numberOfCopies, 2)
    XCTAssertEqual(history.items[0].item.pin, "f")
    XCTAssertEqual(history.items[0].item.title, "xyz")
    XCTAssertEqual(history.items[0].item.application, "iTerm.app")
  }

  func testAddingItemThatIsSupersededByExisting() {
    let firstContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)!
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.rtf.rawValue,
        value: "two".data(using: .utf8)!
      )
    ]
    let firstItem = HistoryItem()
    Storage.shared.context.insert(firstItem)
    firstItem.application = "Maccy.app"
    firstItem.contents = firstContents
    firstItem.title = firstItem.generateTitle()
    history.add(firstItem)

    let secondContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)!
      )
    ]
    let secondItem = HistoryItem()
    Storage.shared.context.insert(secondItem)
    secondItem.application = "Maccy.app"
    secondItem.contents = secondContents
    secondItem.title = secondItem.generateTitle()
    let second = history.add(secondItem)

    XCTAssertEqual(history.items, [second])
    XCTAssertEqual(Set(history.items[0].item.contents), Set(firstContents))
  }

  func testAddingItemWithDifferentModifiedType() {
    let firstContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)!
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.modified.rawValue,
        value: "1".data(using: .utf8)!
      )
    ]
    let firstItem = HistoryItem()
    Storage.shared.context.insert(firstItem)
    firstItem.contents = firstContents
    history.add(firstItem)

    let secondContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)!
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.modified.rawValue,
        value: "2".data(using: .utf8)!
      )
    ]
    let secondItem = HistoryItem()
    Storage.shared.context.insert(secondItem)
    secondItem.contents = secondContents
    let second = history.add(secondItem)

    XCTAssertEqual(history.items, [second])
    XCTAssertEqual(Set(history.items[0].item.contents), Set(firstContents))
  }

  func testAddingItemFromMaccy() {
    let firstContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)
      )
    ]
    let first = HistoryItem()
    Storage.shared.context.insert(first)
    first.application = "Xcode.app"
    first.contents = firstContents
    history.add(first)

    let secondContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.fromMaccy.rawValue,
        value: "".data(using: .utf8)
      )
    ]
    let second = HistoryItem()
    Storage.shared.context.insert(second)
    second.application = "Maccy.app"
    second.contents = secondContents
    let secondDecorator = history.add(second)

    XCTAssertEqual(history.items, [secondDecorator])
    XCTAssertEqual(history.items[0].item.application, "Xcode.app")
    XCTAssertEqual(Set(history.items[0].item.contents), Set(firstContents))
  }

  func testModifiedAfterCopying() {
    history.add(historyItem("foo"))

    let modifiedItem = historyItem("bar")
    modifiedItem.contents.append(HistoryItemContent(
      type: NSPasteboard.PasteboardType.modified.rawValue,
      value: String(Clipboard.shared.changeCount).data(using: .utf8)
    ))
    let modifiedItemDecorator = history.add(modifiedItem)

    XCTAssertEqual(history.items, [modifiedItemDecorator])
    XCTAssertEqual(history.items[0].text, "bar")
  }

  func testClearingUnpinned() {
    let pinned = history.add(historyItem("foo"))
    pinned.togglePin()
    history.add(historyItem("bar"))
    history.clear()
    XCTAssertEqual(history.items, [pinned])
  }

  func testClearingAll() {
    history.add(historyItem("foo"))
    history.clear()
    XCTAssertEqual(history.items, [])
  }

  func testMaxSize() {
    var items: [HistoryItemDecorator] = []
    for index in 0...10 {
      items.append(history.add(historyItem(String(index))))
    }

    XCTAssertEqual(history.items.count, 10)
    XCTAssertTrue(history.items.contains(items[10]))
    XCTAssertFalse(history.items.contains(items[0]))
  }

  func testMaxSizeIgnoresPinned() {
    var items: [HistoryItemDecorator] = []

    let item = history.add(historyItem("0"))
    items.append(item)
    item.togglePin()

    for index in 1...11 {
      items.append(history.add(historyItem(String(index))))
    }

    XCTAssertEqual(history.items.count, 11)
    XCTAssertTrue(history.items.contains(items[10]))
    XCTAssertTrue(history.items.contains(items[0]))
    XCTAssertFalse(history.items.contains(items[1]))
  }

  func testMaxSizeIsChanged() {
    var items: [HistoryItemDecorator] = []
    for index in 0...10 {
      items.append(history.add(historyItem(String(index))))
    }
    Defaults[.size] = 5
    history.add(historyItem("11"))

    XCTAssertEqual(history.items.count, 5)
    XCTAssertTrue(history.items.contains(items[10]))
    XCTAssertFalse(history.items.contains(items[5]))
  }

  func testRemoving() {
    let foo = history.add(historyItem("foo"))
    let bar = history.add(historyItem("bar"))
    history.delete(foo)
    XCTAssertEqual(history.items, [bar])
  }

  func testPersistentStorageRoundTrip() throws {
    let url = temporaryStoreURL(named: #function)
    let storage = Storage(configuration: .persistent(url: url))

    let item = HistoryItem()
    item.application = "com.apple.TextEdit"
    item.firstCopiedAt = Date(timeIntervalSince1970: 100)
    item.lastCopiedAt = Date(timeIntervalSince1970: 200)
    item.numberOfCopies = 3
    item.pin = "f"
    item.contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "hello".data(using: .utf8)
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.rtf.rawValue,
        value: "rich".data(using: .utf8)
      )
    ]
    item.title = "hello"
    item.prepareForPersistence()

    try storage.store.save(item)

    let reloadedStorage = Storage(configuration: .persistent(url: url))
    let loadedItems = try reloadedStorage.store.loadItems()

    XCTAssertEqual(loadedItems.count, 1)
    XCTAssertEqual(loadedItems[0].application, item.application)
    XCTAssertEqual(loadedItems[0].firstCopiedAt, item.firstCopiedAt)
    XCTAssertEqual(loadedItems[0].lastCopiedAt, item.lastCopiedAt)
    XCTAssertEqual(loadedItems[0].numberOfCopies, item.numberOfCopies)
    XCTAssertEqual(loadedItems[0].pin, item.pin)
    XCTAssertEqual(loadedItems[0].title, item.title)
    XCTAssertEqual(Set(loadedItems[0].contents), Set(item.contents))
  }

  func testPersistentStorageLoadsLegacySchemaSQLite() throws {
    let url = temporaryStoreURL(named: #function)
    try createLegacySQLiteStore(at: url)

    let storage = Storage(configuration: .persistent(url: url))
    let loadedItems = try storage.store.loadItems()

    XCTAssertEqual(loadedItems.count, 1)
    XCTAssertEqual(loadedItems[0].application, "com.apple.Preview")
    XCTAssertEqual(loadedItems[0].pin, "b")
    XCTAssertEqual(loadedItems[0].title, "legacy item")
    XCTAssertEqual(loadedItems[0].numberOfCopies, 4)
    XCTAssertEqual(loadedItems[0].contents.count, 2)
    XCTAssertEqual(Set(loadedItems[0].contents.map(\.type)), Set([
      NSPasteboard.PasteboardType.string.rawValue,
      NSPasteboard.PasteboardType.fileURL.rawValue
    ]))
  }

  func testLegacyLoadedItemCanBeUpdatedAndSaved() throws {
    let url = temporaryStoreURL(named: #function)
    try createLegacySQLiteStore(at: url)

    let storage = Storage(configuration: .persistent(url: url))
    let loadedItem = try XCTUnwrap(storage.store.loadItems().first)
    loadedItem.title = "updated title"
    loadedItem.pin = "k"
    loadedItem.numberOfCopies = 8
    loadedItem.contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "updated".data(using: .utf8)
      )
    ]
    loadedItem.prepareForPersistence()

    try storage.store.save(loadedItem)

    let reloadedStorage = Storage(configuration: .persistent(url: url))
    let reloadedItem = try XCTUnwrap(reloadedStorage.store.loadItems().first)
    XCTAssertEqual(reloadedItem.title, "updated title")
    XCTAssertEqual(reloadedItem.pin, "k")
    XCTAssertEqual(reloadedItem.numberOfCopies, 8)
    XCTAssertEqual(reloadedItem.contents.count, 1)
    XCTAssertEqual(reloadedItem.text, "updated")
  }

  func testLegacyLoadedItemsSupportDeleteUnpinned() throws {
    let url = temporaryStoreURL(named: #function)
    try createLegacySQLiteStore(at: url, items: [
      .init(
        application: "com.apple.Preview",
        firstCopiedAt: Date(timeIntervalSince1970: 10),
        lastCopiedAt: Date(timeIntervalSince1970: 20),
        numberOfCopies: 1,
        pin: nil,
        title: "unpinned",
        contents: [
          (NSPasteboard.PasteboardType.string.rawValue, "unpinned".data(using: .utf8))
        ]
      ),
      .init(
        application: "com.apple.TextEdit",
        firstCopiedAt: Date(timeIntervalSince1970: 30),
        lastCopiedAt: Date(timeIntervalSince1970: 40),
        numberOfCopies: 2,
        pin: "m",
        title: "pinned",
        contents: [
          (NSPasteboard.PasteboardType.string.rawValue, "pinned".data(using: .utf8))
        ]
      )
    ])

    let storage = Storage(configuration: .persistent(url: url))
    try storage.store.deleteUnpinned()

    let reloadedStorage = Storage(configuration: .persistent(url: url))
    let remainingItems = try reloadedStorage.store.loadItems()
    XCTAssertEqual(remainingItems.count, 1)
    XCTAssertEqual(remainingItems[0].title, "pinned")
    XCTAssertEqual(remainingItems[0].pin, "m")
  }

  func testLegacyLoadedItemCanBeDeleted() throws {
    let url = temporaryStoreURL(named: #function)
    try createLegacySQLiteStore(at: url)

    let storage = Storage(configuration: .persistent(url: url))
    let loadedItem = try XCTUnwrap(storage.store.loadItems().first)
    try storage.store.delete(loadedItem)

    let reloadedStorage = Storage(configuration: .persistent(url: url))
    XCTAssertTrue(try reloadedStorage.store.loadItems().isEmpty)
  }

  private func historyItem(_ value: String) -> HistoryItem {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: value.data(using: .utf8)
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.numberOfCopies = 1
    item.title = item.generateTitle()

    return item
  }

  private func temporaryStoreURL(named name: String) -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("maccy-tests", isDirectory: true)
      .appendingPathComponent("\(name)-\(UUID().uuidString).sqlite")
  }

  private func createLegacySQLiteStore(at url: URL, items: [LegacyItemSeed]? = nil) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )

    let model = makeLegacyManagedObjectModel()
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    try coordinator.addPersistentStore(
      ofType: NSSQLiteStoreType,
      configurationName: nil,
      at: url,
      options: [
        NSInferMappingModelAutomaticallyOption: true,
        NSMigratePersistentStoresAutomaticallyOption: true
      ]
    )

    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator

    let itemEntity = model.entitiesByName["HistoryItem"]!
    let contentEntity = model.entitiesByName["HistoryItemContent"]!

    for seed in items ?? [legacySeed()] {
      let item = NSManagedObject(entity: itemEntity, insertInto: context)
      item.setValue(seed.application, forKey: "application")
      item.setValue(seed.firstCopiedAt, forKey: "firstCopiedAt")
      item.setValue(seed.lastCopiedAt, forKey: "lastCopiedAt")
      item.setValue(seed.numberOfCopies, forKey: "numberOfCopies")
      item.setValue(seed.pin, forKey: "pin")
      item.setValue(seed.title, forKey: "title")

      let managedContents = seed.contents.map { content -> NSManagedObject in
        let managedContent = NSManagedObject(entity: contentEntity, insertInto: context)
        managedContent.setValue(content.type, forKey: "type")
        managedContent.setValue(content.value, forKey: "value")
        managedContent.setValue(item, forKey: "item")
        return managedContent
      }

      item.setValue(Set(managedContents), forKey: "contents")
    }

    try context.save()
  }

  private func legacySeed() -> LegacyItemSeed {
    .init(
      application: "com.apple.Preview",
      firstCopiedAt: Date(timeIntervalSince1970: 10),
      lastCopiedAt: Date(timeIntervalSince1970: 20),
      numberOfCopies: 4,
      pin: "b",
      title: "legacy item",
      contents: [
        (
          NSPasteboard.PasteboardType.string.rawValue,
          "legacy".data(using: .utf8)
        ),
        (
          NSPasteboard.PasteboardType.fileURL.rawValue,
          "file:///tmp/legacy.txt".data(using: .utf8)
        )
      ]
    )
  }

  private func makeLegacyManagedObjectModel() -> NSManagedObjectModel {
    let itemEntity = NSEntityDescription()
    itemEntity.name = "HistoryItem"
    itemEntity.managedObjectClassName = "NSManagedObject"

    let contentEntity = NSEntityDescription()
    contentEntity.name = "HistoryItemContent"
    contentEntity.managedObjectClassName = "NSManagedObject"

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

    let itemRelationship = NSRelationshipDescription()
    itemRelationship.name = "item"
    itemRelationship.destinationEntity = itemEntity
    itemRelationship.minCount = 0
    itemRelationship.maxCount = 1
    itemRelationship.deleteRule = .nullifyDeleteRule
    itemRelationship.isOptional = true

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
