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

import Foundation

final class EditProgramDialogVM: BaseViewModel<EditProgramDialogViewState, EditProgramDialogViewEvent> {
    
    private let initialState: EditProgramDialogViewState
    
    override func defaultViewState() -> EditProgramDialogViewState { initialState }
    
    init(initialState: EditProgramDialogViewState) {
        self.initialState = initialState
    }
    
    func save() {
        if let state = currentState() {
            send(event: .dismiss(program: state.program))
        }
    }
    
    func heatTemperatureChange(_ step: TemperatureChangeStep) {
        updateView { state in
            guard let heatTemperature = state.program.heatTemperature else { return state }
            return changeHeatTemperature(state: state, temperature: heatTemperature + step.rawValue)
        }
    }
    
    func heatTemperatureChange(_ value: String) {
        updateView { state in
            guard let temperature = getTemperature(value) else { return state }
            return changeHeatTemperature(state: state, temperature: temperature)
        }
    }
    
    func coolTemperatureChange(_ step: TemperatureChangeStep) {
        updateView { state in
            guard let coolTemperature = state.program.coolTemperature else { return state }
            return changeCoolTemperature(state: state, temperature: coolTemperature + step.rawValue)
        }
    }
    
    func coolTemperatureChange(_ value: String) {
        updateView { state in
            guard let temperature = getTemperature(value) else { return state }
            return changeCoolTemperature(state: state, temperature: temperature)
        }
    }
    
    func shouldShowCoolTemperature() -> Bool {
        currentState()?.showCoolEdit == true
    }
    
    func shouldShowHeatTemperature() -> Bool {
        currentState()?.showHeatEdit == true
    }
    
    private func changeHeatTemperature(state: EditProgramDialogViewState, temperature: Float) -> EditProgramDialogViewState {
        let (plusActive, minusActive) = checkTemperature(temperature, min: state.configMin, max: state.configMax)
        return state
            .changing(path: \.program, to: state.program.changing(path: \.heatTemperature, to: temperature))
            .changing(path: \.heatTemperatureText, to: temperature.toTemperature())
            .changing(path: \.heatPlusActive, to: plusActive)
            .changing(path: \.heatMinusActive, to: minusActive)
            .changing(path: \.heatCorrect, to: temperatureCorrect(temperature, min: state.configMin, max: state.configMax))
    }
    
    private func changeCoolTemperature(state: EditProgramDialogViewState, temperature: Float) -> EditProgramDialogViewState {
        let (plusActive, minusActive) = checkTemperature(temperature, min: state.configMin, max: state.configMax)
        return state
            .changing(path: \.program, to: state.program.changing(path: \.coolTemperature, to: temperature))
            .changing(path: \.coolTemperatureText, to: temperature.toTemperature())
            .changing(path: \.coolPlusActive, to: plusActive)
            .changing(path: \.coolMinusActive, to: minusActive)
            .changing(path: \.coolCorrect, to: temperatureCorrect(temperature, min: state.configMin, max: state.configMax))
    }
    
    private func getTemperature(_ temperature: String?) -> Float? {
        if let temperature = temperature,
           let temperatureFloat = Float(temperature.replacingOccurrences(of: ",", with: ".")) {
            return temperatureFloat
        }
        
        return nil
    }
    
    private func checkTemperature(_ temperature: Float, min: Float, max: Float) -> (plusActive: Bool, minusActive: Bool) {
        let minusActive = temperature > min
        let plusActive = temperature < max
        
        return (plusActive: plusActive, minusActive: minusActive)
    }
    
    private func temperatureCorrect(_ temperature: Float, min: Float, max: Float) -> Bool {
        return temperature >= min && temperature <= max
    }
}

struct EditProgramDialogViewState: ViewState {
    var program: ScheduleDetailProgram
    var heatTemperatureText: String?
    var coolTemperatureText: String?
    var showHeatEdit: Bool
    var showCoolEdit: Bool
    
    var configMin: Float
    var configMax: Float
    
    var heatPlusActive = true
    var heatMinusActive = true
    var coolPlusActive = true
    var coolMinusActive = true
    
    var heatCorrect: Bool = true
    var coolCorrect: Bool = true
    
    var saveAllowed: Bool {
        get {
            if (showHeatEdit && !heatCorrect) {
                return false
            }
            if (showCoolEdit && !coolCorrect) {
                return false
            }
            
            return true
        }
    }
}

enum EditProgramDialogViewEvent: ViewEvent {
    case dismiss(program: ScheduleDetailProgram)
}
