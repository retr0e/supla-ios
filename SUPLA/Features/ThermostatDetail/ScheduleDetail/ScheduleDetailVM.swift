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
import RxRelay

private let REFRESH_DELAY_S: Double = 3

class ScheduleDetailVM: BaseViewModel<ScheduleDetailViewState, ScheduleDetailViewEvent> {
    
    @Singleton<ConfigEventsManager> private var configEventsManager
    @Singleton<GetChannelConfigUseCase> private var getChannelConfigUseCase
    @Singleton<DelayedWeeklyScheduleConfigSubject> private var dealyedWeeklyScheduleConfigSubject
    @Singleton<ReadChannelByRemoteIdUseCase> private var readChannelByRemoteIdUseCase
    @Singleton<DateProvider> private var dateProvider
    
    private let reloadConfigRelay = PublishRelay<Void>()
    
    override func defaultViewState() -> ScheduleDetailViewState { ScheduleDetailViewState() }
    
    func observeConfig(remoteId: Int32) {
        Observable.combineLatest(
            configEventsManager.observeConfig(remoteId: remoteId)
                .filter { $0.config is SuplaChannelWeeklyScheduleConfig},
            configEventsManager.observeConfig(remoteId: remoteId)
                .filter { $0.config is SuplaChannelHvacConfig},
            resultSelector: { ($0.config as! SuplaChannelWeeklyScheduleConfig, $0.result, $1.config as! SuplaChannelHvacConfig, $1.result)}
        )
            .asDriverWithoutError()
            .drive(onNext: { self.onConfigLoaded(configs: $0) })
            .disposed(by: self)
        
        reloadConfigRelay
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .asDriverWithoutError()
            .debounce(.milliseconds(100))
            .drive(onNext: { _ in self.triggerConfigLoad(remoteId: remoteId) })
            .disposed(by: self)
        
        loadConfig()
    }
    
    func loadConfig() {
        reloadConfigRelay.accept(())
    }
    
    func onProgramTap(_ program: SuplaScheduleProgram) {
        updateView {
            $0.changing(path: \.activeProgram, to: $0.activeProgram == program ? nil : program)
        }
    }
    
    func onProgramLongPress(_ program: SuplaScheduleProgram) {
        if let state = currentState(),
           let configMin = state.configMin,
           let configMax = state.configMax,
           let program = state.programs.first(where: { $0.program == program}),
           let channelFunc = state.channelFunction,
           let subfunction = state.thermostatSubfunction {
            let isHeat = channelFunc == SUPLA_CHANNELFNC_HVAC_THERMOSTAT && subfunction == .heat
            let isCool = channelFunc == SUPLA_CHANNELFNC_HVAC_THERMOSTAT && subfunction == .cool
            
            let programState = EditProgramDialogViewState(
                program: program,
                heatTemperatureText: program.heatTemperature?.toTemperature(),
                coolTemperatureText: program.coolTemperature?.toTemperature(),
                showHeatEdit: isHeat || channelFunc == SUPLA_CHANNELFNC_HVAC_DOMESTIC_HOT_WATER,
                showCoolEdit: isCool,
                configMin: configMin,
                configMax: configMax
            )
            send(event: .editProgram(state: programState))
        }
        
    }
    
    func onBoxEvent(_ event: PanningEvent) {
        switch (event) {
        case .panning(let boxKey):
            boxTap(boxKey)
        case .finished:
            if (currentState()?.activeProgram != nil) {
                updateView {
                    $0.changing(path: \.changing, to: false)
                        .changing(path: \.lastInteractionTime, to: dateProvider.currentTimestamp())
                }
            }
        }
    }
    
    func onBoxLongPress(_ key: ScheduleDetailBoxKey) {
        if let currentState = currentState(),
           let programs = currentState.schedule[key] {
            
            let state = EditQuartersDialogViewState(
                key: key,
                activeProgram: currentState.activeProgram,
                availablePrograms: currentState.programs,
                quarterPrograms: programs
            )
            send(event: .editScheduleBox(state: state))
        }
    }
    
    func onQuartersChanged(key: ScheduleDetailBoxKey, value: ScheduleDetailBoxValue, activeProgram: SuplaScheduleProgram?) {
        updateView { state in
            var schedule = state.schedule
            schedule[key] = value
            
            return publishChanges(
                state
                    .changing(path: \.schedule, to: schedule)
                    .changing(path: \.activeProgram, to: activeProgram)
                    .changing(path: \.lastInteractionTime, to: dateProvider.currentTimestamp())
            )
        }
    }
    
    func onProgramChanged(_ program: ScheduleDetailProgram) {
        updateView { state in
            let programs = state.programs.map { $0.program == program.program ? program : $0 }
            return publishChanges(
                state.changing(path: \.programs, to: programs)
                    .changing(path: \.activeProgram, to: program.program)
                    .changing(path: \.lastInteractionTime, to: dateProvider.currentTimestamp())
            )
        }
    }
    
    private func triggerConfigLoad(remoteId: Int32) {
        getChannelConfigUseCase.invoke(remoteId: remoteId, type: .defaultConfig).subscribe().disposed(by: self)
        getChannelConfigUseCase.invoke(remoteId: remoteId, type: .weeklyScheduleConfig).subscribe().disposed(by: self)
    }
    
    private func onConfigLoaded(configs: (SuplaChannelWeeklyScheduleConfig, ChannelConfigResult, SuplaChannelHvacConfig, ChannelConfigResult)) {
        
        NSLog("Schedule detail got data: `\(configs)`")
        let weeklyScheduleConfig = configs.0
        let weeklyScheduleResult = configs.1
        let hvacConfig = configs.2
        let hvacResult = configs.3
        
        if (weeklyScheduleResult != .resultTrue || hvacResult != .resultTrue) {
            NSLog("Got unsuccessfull result (schedule: \(weeklyScheduleResult), hvac: \(hvacResult))")
            return
        }
        guard let configMin = hvacConfig.temperatures.roomMin?.toTemperature(),
              let configMax = hvacConfig.temperatures.roomMax?.toTemperature()
        else { return }
        
        updateView { state in
            if (state.changing) {
                return state // Do not change anything, when user makes manual operations
            }
            if let lastInteractionTime = state.lastInteractionTime,
               lastInteractionTime + REFRESH_DELAY_S >= dateProvider.currentTimestamp() {
                scheduleConfigReload(lastInteractionTime, hvacConfig.remoteId)
                return state // Do not change anything during 3 secs after last user interaction
            }
            
            return state
                .changing(path: \.channelFunction, to: hvacConfig.channelFunc)
                .changing(path: \.thermostatSubfunction, to: hvacConfig.subfunction)
                .changing(path: \.remoteId, to: hvacConfig.remoteId)
                .changing(path: \.programs, to: weeklyScheduleConfig.viewProgramsList())
                .changing(path: \.configMin, to: configMin)
                .changing(path: \.configMax, to: configMax)
                .changing(path: \.schedule, to: weeklyScheduleConfig.viewScheduleBoxes())
        }
        
        if (hvacConfig.subfunction == .notSet) {
            loadSubfunction(hvacConfig.remoteId)
        }
    }
    
    private func boxTap(_ key: ScheduleDetailBoxKey) {
        if let state = currentState(),
           let activeProgram = state.activeProgram {
            
            return updateView { state in
                var schedule = state.schedule
                schedule[key] = ScheduleDetailBoxValue(oneProgram: activeProgram)
                return publishChanges(
                    state.changing(path: \.schedule, to: schedule)
                        .changing(path: \.changing, to: true)
                )
            }
        }
    }
    
    private func publishChanges(_ state: ScheduleDetailViewState) -> ScheduleDetailViewState {
        guard let remoteId = state.remoteId else { return state }
        dealyedWeeklyScheduleConfigSubject.emit(
            data: WeeklyScheduleConfigData(
                remoteId: remoteId,
                programs: state.suplaPrograms(),
                schedule: state.suplaSchedule()
            )
        )
        
        return state
    }
    
    private func scheduleConfigReload(_ lastInteractionTime: TimeInterval, _ remoteId: Int32) {
        let delay = lastInteractionTime + REFRESH_DELAY_S - dateProvider.currentTimestamp()
        if (delay > 0) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: { [weak self] in
                self?.triggerConfigLoad(remoteId: remoteId)
            })
        } else {
            triggerConfigLoad(remoteId: remoteId)
        }
    }
    
    private func loadSubfunction(_ remoteId: Int32) {
        readChannelByRemoteIdUseCase.invoke(remoteId: remoteId)
            .asDriverWithoutError()
            .drive(onNext: { [weak self] channel in
                self?.updateView {
                    $0.changing(
                        path: \.thermostatSubfunction,
                        to: channel.value?.asThermostatValue().subfunction)
                }
            })
            .disposed(by: self)
    }
}

// MARK: - Event & State

enum ScheduleDetailViewEvent: ViewEvent {
    case editProgram(state: EditProgramDialogViewState)
    case editScheduleBox(state: EditQuartersDialogViewState)
}

struct ScheduleDetailViewState: ViewState {
    var channelFunction: Int32? = nil
    var thermostatSubfunction: ThermostatSubfunction? = nil
    var remoteId: Int32? = nil
    var activeProgram: SuplaScheduleProgram? = nil
    var schedule: [ScheduleDetailBoxKey:ScheduleDetailBoxValue] = [:]
    var programs: [ScheduleDetailProgram] = []
    var configMin: Float? = nil
    var configMax: Float? = nil
    
    var lastInteractionTime: TimeInterval? = nil
    var changing: Bool = false
}

struct ScheduleDetailProgram: Equatable, Changeable {
    var program: SuplaScheduleProgram
    var mode: SuplaHvacMode
    var heatTemperature: Float?
    var coolTemperature: Float?
    var icon: UIImage? = nil
    
    var text: String {
        get {
            @Singleton<TemperatureFormatter> var formatter
            
            if (program == .off) {
                return Strings.General.turnOff
            } else if (mode == .heat) {
                return formatter.toString(heatTemperature, withUnit: false)
            } else if (mode == .cool) {
                return formatter.toString(coolTemperature, withUnit: false)
            } else {
                return TEMPERATURE_NO_VALUE
            }
        }
    }
}

struct ScheduleDetailBoxKey: Equatable, Hashable {
    let dayOfWeek: DayOfWeek
    let hour: Int
}

struct ScheduleDetailBoxValue: Equatable {
    
    var firstQuarterProgram: SuplaScheduleProgram
    var secondQuarterProgram: SuplaScheduleProgram
    var thirdQuarterProgram: SuplaScheduleProgram
    var fourthQuarterProgram: SuplaScheduleProgram
    
    var hasSingleProgram: Bool {
        get {
            return firstQuarterProgram == secondQuarterProgram
                    && secondQuarterProgram == thirdQuarterProgram
                    && thirdQuarterProgram == fourthQuarterProgram
        }
    }
    
    init(_ first: SuplaScheduleProgram, _ second: SuplaScheduleProgram, _ third: SuplaScheduleProgram, _ fourth: SuplaScheduleProgram) {
        firstQuarterProgram = first
        secondQuarterProgram = second
        thirdQuarterProgram = third
        fourthQuarterProgram = fourth
    }
    
    init(oneProgram: SuplaScheduleProgram) {
        firstQuarterProgram = oneProgram
        secondQuarterProgram = oneProgram
        thirdQuarterProgram = oneProgram
        fourthQuarterProgram = oneProgram
    }
}

fileprivate extension SuplaChannelWeeklyScheduleConfig {
    func viewProgramsList() -> [ScheduleDetailProgram] {
        var result: [ScheduleDetailProgram] = []
        
        for program in programConfigurations {
            result.append(ScheduleDetailProgram(
                program: program.program,
                mode: program.mode,
                heatTemperature: program.setpointTemperatureHeat?.toTemperature(),
                coolTemperature: program.setpointTemperatureCool?.toTemperature(),
                icon: getProgramIcon(program)
            ))
        }
        
        result.append(ScheduleDetailProgram(
            program: .off,
            mode: .off,
            icon: .iconPowerButton
        ))
        
        return result
    }
    
    func viewScheduleBoxes() -> [ScheduleDetailBoxKey:ScheduleDetailBoxValue] {
        var result: [ScheduleDetailBoxKey:ScheduleDetailBoxValue] = [:]
        
        for entry in schedule {
            let key = ScheduleDetailBoxKey(dayOfWeek: entry.dayOfWeek, hour: Int(entry.hour))
            
            if var value = result[key] {
                switch(entry.quarterOfHour) {
                case .first: value.firstQuarterProgram = entry.program
                case .second: value.secondQuarterProgram = entry.program
                case .third: value.thirdQuarterProgram = entry.program
                case .fourth: value.fourthQuarterProgram = entry.program
                }
                result[key] = value
            } else {
                var value = ScheduleDetailBoxValue(oneProgram: .off)
                switch(entry.quarterOfHour) {
                case .first: value.firstQuarterProgram = entry.program
                case .second: value.secondQuarterProgram = entry.program
                case .third: value.thirdQuarterProgram = entry.program
                case .fourth: value.fourthQuarterProgram = entry.program
                }
                result[key] = value
            }
        }
        
        return result
    }
    
    private func getProgramIcon(_ program: SuplaWeeklyScheduleProgram) -> UIImage? {
        if (channelFunc == SUPLA_CHANNELFNC_HVAC_THERMOSTAT_AUTO && program.mode == .heat) {
            return .iconHeat
        }
        if (channelFunc == SUPLA_CHANNELFNC_HVAC_THERMOSTAT_AUTO && program.mode == .cool) {
            return .iconCool
        }
        
        return nil
    }
}

fileprivate extension ScheduleDetailViewState {
    
    func suplaPrograms() -> [SuplaWeeklyScheduleProgram] {
        var result: [SuplaWeeklyScheduleProgram] = []
        
        programs.forEach { program in
            if (program.program != .off) {
                result.append(
                    SuplaWeeklyScheduleProgram(
                        program: program.program,
                        mode: program.mode,
                        setpointTemperatureHeat: program.heatTemperature?.toSuplaTemperature(),
                        setpointTemperatureCool: program.coolTemperature?.toSuplaTemperature()
                    )
                )
            }
        }
        
        return result
    }
    
    func suplaSchedule() -> [SuplaWeeklyScheduleEntry] {
        var result: [SuplaWeeklyScheduleEntry] = []
        
        schedule.forEach { entry in
            result.append(
                SuplaWeeklyScheduleEntry(
                    dayOfWeek: entry.key.dayOfWeek,
                    hour: UInt8(entry.key.hour),
                    quarterOfHour: .first,
                    program: entry.value.firstQuarterProgram
                )
            )
            result.append(
                SuplaWeeklyScheduleEntry(
                    dayOfWeek: entry.key.dayOfWeek,
                    hour: UInt8(entry.key.hour),
                    quarterOfHour: .second,
                    program: entry.value.secondQuarterProgram
                )
            )
            result.append(
                SuplaWeeklyScheduleEntry(
                    dayOfWeek: entry.key.dayOfWeek,
                    hour: UInt8(entry.key.hour),
                    quarterOfHour: .third,
                    program: entry.value.thirdQuarterProgram
                )
            )
            result.append(
                SuplaWeeklyScheduleEntry(
                    dayOfWeek: entry.key.dayOfWeek,
                    hour: UInt8(entry.key.hour),
                    quarterOfHour: .fourth,
                    program: entry.value.fourthQuarterProgram
                )
            )
        }
        
        return result
    }
}
