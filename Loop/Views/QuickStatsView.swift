//
//  QuickStatsView.swift
//  Loop
//
//  Created by Bastiaan Verhaar on 19/09/2024.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts

struct QuickStatsView: View {
    @Environment(\.dismissAction) var dismiss
    
    @ObservedObject var viewModel: QuickStatsViewModel
    
    var body: some View {
        ScrollView {
            Picker("DateRange", selection: $viewModel.selectedRange) {
                ForEach(DateRangeType.allCases, id:\.self) { range in
                    Text(range.getLocalizedName())
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedRange) { _ in
                viewModel.fetchData()
            }
            .padding(.horizontal)
            
            Chart {
                ForEach(viewModel.chartData) { item in
                    PointMark (x: .value("Date", item.date),
                               y: .value("Glucose level", item.glucose)
                    )
                    .symbolSize(20)
                    .foregroundStyle(by: .value("Color", item.color))
                }
            }
            .frame(height: 250)
            .chartForegroundStyleScale([
                "Good": .green,
                "High": .orange,
                "Low": .red,
                "Default": .blue
            ])
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisValueLabel().foregroundStyle(Color.primary)
                    AxisGridLine(stroke: .init(lineWidth: 0.1, dash: [2, 3]))
                        .foregroundStyle(Color.primary)
                }
            }
            .chartXAxis {
                AxisMarks(position: .automatic, values: .stride(by: .hour)) { _ in
                    AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .narrow)), anchor: .top)
                        .foregroundStyle(Color.primary)
                    AxisGridLine(stroke: .init(lineWidth: 0.1, dash: [2, 3]))
                        .foregroundStyle(Color.primary)
                }
            }
        }
        .navigationBarTitle(NSLocalizedString("Quick stats", comment: "The title of Quick stats"))
        .navigationBarTitleDisplayMode(.large)
    }
}
