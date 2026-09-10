from pathlib import Path

app = Path.cwd()
if app.name != "patient":
    raise SystemExit("Run from apps/patient")

app_delegate = app / "ios/Runner/AppDelegate.swift"
text = app_delegate.read_text(encoding="utf-8")

case_marker = '''          case "healthKit.grantedCategories":
            result(try await self.authorizationReadyCategories())
'''
case_replacement = '''          case "healthKit.grantedCategories":
            result(try await self.authorizationReadyCategories())
          case "healthKit.readAccessScope":
            result(try await self.readAccessScope())
'''
if case_marker not in text:
    raise SystemExit("HealthKit grantedCategories switch marker not found")
text = text.replace(case_marker, case_replacement, 1)

method_marker = '''  private func requestPermissions(_ call: FlutterMethodCall) async throws -> Bool {
'''
methods = r'''  private func readAccessScope() async throws -> [String: Any] {
    guard HKHealthStore.isHealthDataAvailable() else {
      return [
        "availableCategories": [],
        "requestStatusUnnecessaryCategories": [],
        "queryVisibleCategories": [],
        "earliestAuthorizedAtEpochMillis": [:],
      ]
    }

    let available = supportedCategories.keys.sorted()
    var requestStatusUnnecessary: [String] = []
    var queryVisible: [String] = []

    for category in available {
      let types = supportedCategories[category] ?? []
      if try await requestStatus(read: Set(types)) == .unnecessary {
        requestStatusUnnecessary.append(category)
      }

      var visible = false
      for type in types where !visible {
        visible = try await hasVisibleSample(type: type)
      }
      if visible {
        queryVisible.append(category)
      }
    }

    var earliestByCategory: [String: Int64] = [:]
    if #available(iOS 26.0, *) {
      let allTypes = Set(sampleTypes(for: Set(available)).map { $0 as HKObjectType })
      let earliest = try await earliestAuthorizedSampleDates(for: allTypes)
      for category in available {
        let dates = (supportedCategories[category] ?? []).compactMap { earliest[$0] }
        // HealthDataCategory can contain multiple HealthKit sample types. Use the
        // latest boundary so downstream category-wide queries never describe
        // older, partially hidden data as complete.
        if let boundary = dates.max() {
          earliestByCategory[category] = Int64(boundary.timeIntervalSince1970 * 1000)
        }
      }
    }

    return [
      "availableCategories": available,
      "requestStatusUnnecessaryCategories": requestStatusUnnecessary.sorted(),
      "queryVisibleCategories": queryVisible.sorted(),
      "earliestAuthorizedAtEpochMillis": earliestByCategory,
    ]
  }

  private func hasVisibleSample(type: HKSampleType) async throws -> Bool {
    try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: type,
        predicate: nil,
        limit: 1,
        sortDescriptors: nil
      ) { _, samples, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: !(samples ?? []).isEmpty)
        }
      }
      store.execute(query)
    }
  }

  @available(iOS 26.0, *)
  private func earliestAuthorizedSampleDates(
    for types: Set<HKObjectType>
  ) async throws -> [HKObjectType: Date] {
    try await withCheckedThrowingContinuation { continuation in
      store.getEarliestAuthorizedSampleDate(for: types) { dates, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: dates ?? [:])
        }
      }
    }
  }

'''
if method_marker not in text:
    raise SystemExit("HealthKit requestPermissions method marker not found")
text = text.replace(method_marker, methods + method_marker, 1)

app_delegate.write_text(text, encoding="utf-8")
