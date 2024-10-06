//
//  QuickStatsViewModel.swift
//  Loop
//
//  Created by Bastiaan Verhaar on 19/09/2024.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

enum DateRangeType: CaseIterable, Hashable {
    static var allHealthKitCases: [DateRangeType] {
        return [.today, .week, .month, .custom]
    }
    static var allNonHealthKitCases: [DateRangeType] {
        return [.today, .week]
    }
    
    case today
    case week
    case month
    case custom
    
    func getLocalizedName() -> String {
        switch self {
        case .today:
            return NSLocalizedString("Today", comment: "Label for today")
        case .week:
            return NSLocalizedString("This week", comment: "Label for week")
        case .month:
            return NSLocalizedString("This month", comment: "Label for month")
        case .custom:
            return NSLocalizedString("Custom", comment: "Label for custom")
        }
    }
}

struct TirStats : Identifiable {
    var type: String
    var percent: Double
    var id = UUID()
}

public class QuickStatsViewModel: ObservableObject {
    @Published var selectedRange: DateRangeType = .week
    @Published var chartData: [QuickStatsChartDataPoint] = []
    @Published var tir: [TirStats] = []
    @Published var hba1c: Double = 0
    @Published var median: Double = 0
    @Published var average: Double = 0
    @Published var size: Double = 0
    @Published var loading = true
    
    @Published var customStart: Date = Date.now.startOfWeek
    @Published var customEnd: Date = Date.now.endOfWeek
    
    public var lowerLimit: Double {
        HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 70).doubleValue(for: self.unit)
    }
    
    public var lowerLimitLabel: String {
        String(format: NSLocalizedString("Low <= %.0f %@", comment: ""), lowerLimit, self.unit.localizedShortUnitString)
    }
    
    public var inRangeLabel: String {
        NSLocalizedString("In range", comment: "")
    }
    
    public var upperLimit: Double {
        HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 180).doubleValue(for: self.unit)
    }
    
    public var upperLimitLabel: String {
        String(format: NSLocalizedString("High >= %.0f %@", comment: ""), upperLimit, self.unit.localizedShortUnitString)
    }
    
    public var maxLimit: Double {
        HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 270).doubleValue(for: self.unit)
    }
    
    public var sizeOfDataPoints: Double {
        chartData.count < 20 ? 50 : chartData.count < 50 ? 35 : chartData.count > 2000 ? 5 : 15
    }
    
    private let healthStore: HKHealthStore
    private let deviceDataManager: DeviceDataManager
    let unit: HKUnit
    let isHealthKitAuthorized: Bool
    
    init(deviceDataManager: DeviceDataManager) {
        self.healthStore = HKHealthStore()
        self.deviceDataManager = deviceDataManager
        self.unit = deviceDataManager.preferredGlucoseUnit
        
        self.isHealthKitAuthorized = healthStore.authorizationStatus(for: HealthKitSampleStore.glucoseType) == .sharingAuthorized
        
        fetchData()
    }
    
    func fetchData() {
        self.loading = true
        let (start, end) = getDateRange()
        
        if !self.isHealthKitAuthorized {
            print("Not authorized...")
            self.deviceDataManager.glucoseStore.getGlucoseSamples(start: start, end: end) { result in
                switch result {
                case .failure(let error):
                    print("Failed to fetch glucose data: \(error)")
                    self.loading = false
                    return
                case .success(let samples):
                    DispatchQueue.main.async {
                        self.size = Double(samples.count)
                        self.processChart(samples)
                        self.processCounts(samples)
                        self.processHba1c(samples)
                        self.processAverage(samples)
                        self.processMedian(samples)
                        
                        self.loading = false
                    }
                }
            }
            return
        }
        
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sortByDate = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: HealthKitSampleStore.glucoseType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortByDate]) { (query, data, error) in
            
            if let error = error {
                print("HK: Failed to fetch glucose data: \(error)")
                self.loading = false
                return
            }
            
            guard let data = data else {
                print("HK: No samples available")
                self.loading = false
                return
            }
            
            let samples: [StoredGlucoseSample] = data.map { item in StoredGlucoseSample(sample: item as! HKQuantitySample) }
            DispatchQueue.main.async {
                self.size = Double(samples.count)
                self.processChart(samples)
                self.processCounts(samples)
                self.processHba1c(samples)
                self.processAverage(samples)
                self.processMedian(samples)
                
                self.loading = false
            }
        }
        
        self.healthStore.execute(query)
    }
    
    private func processChart(_ samples: [StoredGlucoseSample]) {
        self.chartData = samples.map { item in
            let glucose = item.quantity.doubleValue(for: self.unit)
            
            return QuickStatsChartDataPoint(
                id: UUID(),
                date: item.startDate,
                glucose: glucose,
                color: glucose < self.lowerLimit ? "Low" : glucose > self.upperLimit ? "High" : "InRange"
            )
        }
    }
    
    private func processHba1c(_ samples: [StoredGlucoseSample]) {
        let averageGlucose = samples.reduce(0.0) { (a, b) in a + b.quantity.doubleValue(for: .milligramsPerDeciliter)} / Double(samples.count)
        self.hba1c = (averageGlucose + 46.7) / 28.7
    }
    
    private func processAverage(_ samples: [StoredGlucoseSample]) {
        self.average = samples.reduce(0.0) { (a, b) in a + b.quantity.doubleValue(for: self.unit)} / Double(samples.count)
    }
    
    private func processMedian(_ samples: [StoredGlucoseSample]) {
        let sorted = samples.map{item in item.quantity.doubleValue(for: self.unit)}.sorted()
        if sorted.count % 2 == 0 {
            self.median = Double((sorted[(sorted.count / 2)] + sorted[(sorted.count / 2) - 1])) / 2
        } else {
            self.median = Double(sorted[(sorted.count - 1) / 2])
        }
    }
    
    private func processCounts(_ samples: [StoredGlucoseSample]) {
        let total = Double(samples.count)
        var low: Double = 0, inRange: Double = 0, high: Double = 0
        
        samples.forEach { item in
            let glucose = item.quantity.doubleValue(for: self.unit)
            if glucose < self.lowerLimit {
                low += 1
            } else if glucose > self.upperLimit {
                high += 1
            } else {
                inRange += 1
            }
        }
        
        self.tir = [
            .init(type: lowerLimitLabel, percent: low / total * 100),
            .init(type: inRangeLabel, percent: inRange / total * 100),
            .init(type: upperLimitLabel, percent: high / total * 100)
        ]
    }
    
    private func getDateRange() -> (Date, Date) {
        switch selectedRange {
        case .today:
            return (Date.now.startOfDay, Date.now.endOfDay)
        case .week:
            return (Date.now.startOfWeek, Date.now.endOfWeek)
        case .month:
            return (Date.now.startOfMonth, Date.now.endOfMonth)
        case .custom:
            return (customStart, customEnd)
        }
    }
}

extension Date {
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }
    
    var startOfWeek: Date {
        Calendar.current.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: self).date!
    }
    
    var endOfWeek: Date {
        var components = DateComponents()
        components.weekOfYear = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfWeek)!
    }
    
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: startOfDay)
        return Calendar.current.date(from: components)!
    }

    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth)!
    }
}

struct QuickStatsChartDataPoint: Identifiable {
    let id: UUID
    let date: Date
    let glucose: Double
    let color: String
}
