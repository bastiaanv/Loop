//
//  QuickStatsViewModel.swift
//  Loop
//
//  Created by Bastiaan Verhaar on 19/09/2024.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

enum DateRangeType: CaseIterable, Hashable {
    static var allCases: [DateRangeType] {
        return [.today, .week, .month, .custom(start: Date.now.startOfWeek, end: Date.now.endOfWeek)]
    }
    
    case today
    case week
    case month
    case custom(start: Date, end: Date)
    
    func getLocalizedName() -> String {
        switch self {
        case .today:
            return NSLocalizedString("Today", comment: "Label for today")
        case .week:
            return NSLocalizedString("Week", comment: "Label for week")
        case .month:
            return NSLocalizedString("Month", comment: "Label for month")
        case .custom:
            return NSLocalizedString("Custom", comment: "Label for custom")
        }
    }
}

public class QuickStatsViewModel: ObservableObject {
    @Published var selectedRange: DateRangeType = .week
    @Published var chartData: [QuickStatsChartDataPoint] = []
    
    private let deviceDataManager: DeviceDataManager
    private let unit: HKUnit
    init(deviceDataManager: DeviceDataManager) {
        self.deviceDataManager = deviceDataManager
        self.unit = deviceDataManager.preferredGlucoseUnit
        
        fetchData()
    }
    
    func fetchData() {
        let (start, end) = getDateRange()
        let (useLimits, lowerLimit, upperLimit) = getLimits()
        
        self.deviceDataManager.glucoseStore.getGlucoseSamples(start: start, end: end) { result in
            switch result {
            case .failure(let error):
                print("Failed to fetch glucose data: \(error)")
                return
            case .success(let samples):
                DispatchQueue.main.async {
                    self.chartData = samples.map { item in
                        let glucose = item.quantity.doubleValue(for: self.unit)
                        
                        return QuickStatsChartDataPoint(
                            id: UUID(),
                            date: item.startDate,
                            glucose: glucose,
                            color: !useLimits ? "Default" : glucose < lowerLimit ? "Low" : glucose > upperLimit ? "High" : "Good"
                        )
                    }
                    return
                }
            }
        }
    }
    
    private func getDateRange() -> (Date, Date) {
        switch selectedRange {
        case .today:
            return (Date.now.startOfDay, Date.now.endOfDay)
        case .week:
            return (Date.now.startOfDay, Date.now.endOfDay)
        case .month:
            return (Date.now.startOfMonth, Date.now.endOfMonth)
        case .custom(let start, let end):
            return (start.startOfDay, end.endOfDay)
        }
    }
    
    private func getLimits() -> (Bool, Double, Double) {
        return (
            true,
            HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 70).doubleValue(for: self.unit),
            HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 180).doubleValue(for: self.unit)
        )
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
