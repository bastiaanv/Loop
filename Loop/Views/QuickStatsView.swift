//
//  QuickStatsView.swift
//  Loop
//
//  Created by Bastiaan Verhaar on 19/09/2024.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Charts
import LoopKitUI

struct QuickStatsView: View {
    @Environment(\.dismissAction) var dismiss
    
    @ObservedObject var viewModel: QuickStatsViewModel
    
    var body: some View {
        ScrollView {
            Picker("DateRange", selection: $viewModel.selectedRange) {
                ForEach(viewModel.isHealthKitAuthorized ? DateRangeType.allHealthKitCases : DateRangeType.allNonHealthKitCases, id:\.self) { range in
                    Text(range.getLocalizedName())
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedRange) { _ in
                viewModel.fetchData()
            }
            .padding(.horizontal)
            
            if case .custom = viewModel.selectedRange {
                Section {
                    DatePicker("Start Date",
                               selection: $viewModel.customStart,
                               in: ...viewModel.customEnd,
                               displayedComponents: [.date]
                    )
                    .onChange(of: viewModel.customStart) { _ in
                        viewModel.fetchData()
                    }
                    
                    DatePicker("End Date",
                               selection: $viewModel.customEnd,
                               in: viewModel.customStart...Date(),
                               displayedComponents: [.date]
                    )
                    .onChange(of: viewModel.customEnd) { _ in
                        viewModel.fetchData()
                    }
                }
                .padding(.horizontal)
                .transition(.move(edge: .top))
            }
            
            Chart {
                ForEach(viewModel.chartData) { item in
                    PointMark (x: .value("Date", item.date),
                               y: .value("Glucose level", item.glucose)
                    )
                    .symbolSize(viewModel.sizeOfDataPoints)
                    .foregroundStyle(by: .value("Color", item.color))
                }
            }
            .frame(height: 265)
            .padding(.bottom, 15)
            .chartForegroundStyleScale([
                "InRange": .green,
                "High": .orange,
                "Low": .red
            ])
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(
                    values: [ 0, viewModel.lowerLimit, viewModel.upperLimit, viewModel.maxLimit ]
                )
            }
            
            Chart(viewModel.tir) { tir in
                BarMark(x: .value("TIR", tir.percent))
                .foregroundStyle(by: .value("Group", tir.type))
                .annotation(position: .top, alignment: .center) {
                    Text("\(tir.percent, format: .number.precision(.fractionLength(0))) %")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
            }
            .chartXAxis(.hidden)
            .chartForegroundStyleScale([
                viewModel.lowerLimitLabel: .red,
                viewModel.inRangeLabel: .green,
                viewModel.upperLimitLabel: .orange,
            ])
            .frame(maxHeight: 25)
            
            if !viewModel.loading {
                VStack {
                    Divider()
                    
                    HStack(spacing: 25) {
                        VStack(spacing: 5) {
                            Text("HBA1C").font(.subheadline).foregroundColor(.secondary)
                            Text("\(viewModel.hba1c, format: .number.rounded(increment: 0.1))%")
                        }
                        
                        VStack(spacing: 5) {
                            Text("Average").font(.subheadline).foregroundColor(.secondary)
                            Text("\(viewModel.average, format: .number.rounded(increment: 0.1))\(viewModel.unit.localizedShortUnitString)")
                        }

                        VStack(spacing: 5) {
                            Text("Median").font(.subheadline).foregroundColor(.secondary)
                            Text("\(viewModel.median, format: .number.rounded(increment: 0.1))\(viewModel.unit.localizedShortUnitString)")
                        }

                        VStack(spacing: 5) {
                            Text("Size").font(.subheadline).foregroundColor(.secondary)
                            Text("\(viewModel.size, format: .number.rounded(increment: 0))")
                        }
                    }
                    
                    Divider()
                }
                .padding(.top)
            } else {
                VStack {
                    ActivityIndicator(isAnimating: .constant(true), style: .medium)
                }
                .padding(.top, 30)
            }
        }
        .navigationBarTitle(NSLocalizedString("Quick stats", comment: "The title of Quick stats"))
        .navigationBarTitleDisplayMode(.large)
    }
}
