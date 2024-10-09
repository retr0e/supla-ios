/*
 Copyright (C) AC SOFTWARE SP. Z O.O.

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

import RxSwift
    
extension ElectricityMeterHistoryFeature {
    class ViewModel: BaseHistoryDetailVM {
        @Singleton<DownloadEventsManager> private var downloadEventsManager
        @Singleton<ReadChannelByRemoteIdUseCase> private var readChannelByRemoteIdUseCase
        @Singleton<LoadChannelMeasurementsUseCase> private var loadChannelMeasurementsUseCase
        @Singleton<DownloadChannelMeasurementsUseCase> private var downloadChannelMeasurementsUseCase
        @Singleton<LoadChannelMeasurementsDateRangeUseCase> private var loadChannelMeasurementsDateRangeUseCase
        
        override var chartStyle: any ChartStyle {
            ElectricityChartStyle()
        }
        
        override func loadChartState(_ profileId: String, _ remoteId: Int32) -> ChartState {
            userStateHolder.getElectricityChartState(profileId: profileId, remoteId: remoteId)
                .copy(visibleSets: .value(nil))
        }
        
        override func exportChartState(_: BaseHistoryDetailViewState) -> ChartState? {
            guard let state = currentState(),
                  let aggregation = state.aggregations?.selected,
                  let chartRange = state.ranges?.selected,
                  let dateRange = state.range else { return nil }
            
            return ElectricityChartState(
                aggregation: aggregation,
                chartRange: chartRange,
                dateRange: dateRange,
                chartParameters: state.chartParameters?.value,
                visibleSets: state.chartData.visibleSets,
                customFilters: state.chartCustomFilters?.filters as? ElectricityChartFilters
            )
        }
        
        override func triggerDataLoad(remoteId: Int32) {
            Observable.zip(
                readChannelByRemoteIdUseCase.invoke(remoteId: remoteId),
                profileRepository.getActiveProfile().map { [weak self] in self?.loadChartState($0.idString, remoteId) }
            ) { ($0, $1) }
                .asDriverWithoutError()
                .drive(
                    onNext: { [weak self] in self?.handleData(channel: $0.0, chartState: $0.1) }
                )
                .disposed(by: self)
        }
        
        override func measurementsObservable(remoteId: Int32, spec: ChartDataSpec, chartRange: ChartRange) -> Observable<(ChartData, DaysRange?)> {
            Observable.zip(
                loadChannelMeasurementsUseCase.invoke(remoteId: remoteId, spec: spec),
                loadChannelMeasurementsDateRangeUseCase.invoke(remoteId: remoteId)
            ) { (BarChartData(DaysRange(start: spec.startDate, end: spec.endDate), chartRange, spec.aggregation, [$0]), $1) }
        }
        
        override func aggregations(
            _ currentRange: DaysRange,
            _ selectedAggregation: ChartDataAggregation? = .minutes,
            _ customFilters: (any ChartDataSpec.Filters)?
        ) -> SelectableList<ChartDataAggregation> {
            let aggregations = super.aggregations(currentRange, selectedAggregation, customFilters)
            
            guard let filters = customFilters as? ElectricityChartFilters
            else { return aggregations }
            
            return if (filters.type == .balanceHourly && aggregations.items.contains(.minutes)) {
                SelectableList(
                    selected: aggregations.selected == .minutes ? .hours : aggregations.selected,
                    items: aggregations.items.filter { $0 != .minutes }
                )
            } else {
                aggregations
            }
        }
        
        func onDataSelectionChange(type: ElectricityMeterChartType, phases: [Phase]) {
            updateView { state in
                guard let dateRange = state.range,
                      let filters = state.chartCustomFilters?.filters as? ElectricityChartFilters
                else { return state }
                
                let customFilters = filters.copy(type: type, selectedPhases: phases)
                return state
                    .changing(path: \.chartCustomFilters, to: CustomChartFiltersContainer(filters: customFilters))
                    .changing(path: \.loading, to: true)
                    .changing(path: \.initialLoadStarted, to: false)
                    .changing(path: \.aggregations, to: aggregations(dateRange, state.aggregations?.selected, customFilters))
                    .changing(path: \.chartData, to: state.chartData.empty())
            }
            updateUserState()
            if let state = currentState() {
                triggerMeasurementsLoad(state: state)
            }
        }
        
        private func handleData(channel: SAChannel, chartState: ChartState?) {
            updateView {
                $0.changing(path: \.profileId, to: channel.profile.idString)
                    .changing(path: \.channelFunction, to: channel.func)
            }
            
            restoreCustomFilters(flags: channel.flags, value: channel.ev?.electricityMeter(), state: chartState)
            restoreRange(chartState: chartState)
            configureDownloadObserver(channel: channel)
            startInitialDataLoad(channel: channel)
        }
        
        private func configureDownloadObserver(channel: SAChannel) {
            if (currentState()?.downloadConfigured == true) {
                // Needs to be performed only once
                return
            }
            updateView { $0.changing(path: \.downloadConfigured, to: true) }
            
            downloadEventsManager.observeProgress(remoteId: channel.remote_id)
                .distinctUntilChanged()
                .asDriverWithoutError()
                .drive(onNext: { [weak self] in self?.handleDownloadEvents(downloadState: $0) })
                .disposed(by: self)
        }
        
        private func startInitialDataLoad(channel: SAChannel) {
            if (currentState()?.initialLoadStarted == true) {
                return
            }
            updateView { $0.changing(path: \.initialLoadStarted, to: true) }
            downloadChannelMeasurementsUseCase.invoke(remoteId: channel.remote_id, function: channel.func)
        }
        
        private func restoreCustomFilters(flags: Int64, value: SAElectricityMeterExtendedValue?, state: ChartState?) {
            updateView {
                $0.changing(
                    path: \.chartCustomFilters,
                    to: CustomChartFiltersContainer(
                        filters: ElectricityChartFilters.restore(flags: flags, value: value, state: state)
                    )
                )
            }
        }
    }
}
