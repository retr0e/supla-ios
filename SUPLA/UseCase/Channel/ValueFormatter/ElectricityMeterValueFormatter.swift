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

final class ListElectricityMeterValueFormatter: BaseElectricityMeterValueFormatter {
    
    let useNoValue: Bool?
    
    init(useNoValue: Bool? = nil) {
        self.useNoValue = useNoValue
    }
    
    override func format(_ value: Any, withUnit: Bool, precision: ChannelValuePrecision, custom: Any?) -> String {
        let unit = if (withUnit) {
            (custom as? SuplaElectricityMeasurementType)?.unit ?? "kWh"
        } else {
            ""
        }
        let checkNoValue = checkNoValue(custom)
        
        if let value = value as? Double {
            let precision = getPrecision(value, precision: precision)
            return format(value, unit: unit, precision: precision, checkNoValue: checkNoValue)
        }
        
        return format(0.0, unit: unit, precision: 0, checkNoValue: checkNoValue)
    }
    
    private func checkNoValue(_ any: Any?) -> Bool {
        if let useNoValue = useNoValue {
            return useNoValue
        }
        if let type = any as? SuplaElectricityMeasurementType {
            return type == .forwardActiveEnergy
        }
        return false
    }
}
    
class BaseElectricityMeterValueFormatter: ChannelValueFormatter {
    
    private let formatter: NumberFormatter
    
    init() {
        formatter = NumberFormatter()
        formatter.decimalSeparator = Locale.current.decimalSeparator
    }
    
    func handle(function: Int) -> Bool {
        function == SUPLA_CHANNELFNC_ELECTRICITY_METER
    }
    
    func format(_ value: Any, withUnit: Bool, precision: ChannelValuePrecision, custom: Any?) -> String {
        fatalError("format(_:withUnit:precision:) has not been implemented!")
    }
    
    fileprivate func format(_ value: Double, unit: String, precision: Int, checkNoValue: Bool = true) -> String {
        if (value.isNaN) {
            // Nan is possible when user selected other type than default (ex voltage) and currently there is no data
            return NO_VALUE_TEXT
        }
        if (checkNoValue && value == ElectricityMeterValueProviderImpl.UNKNOWN_VALUE) {
            return NO_VALUE_TEXT
        }
        
        formatter.minimumFractionDigits = precision
        formatter.maximumFractionDigits = precision
        
        return formatter.string(from: NSNumber(value: value))! + " " + unit
    }
    
    fileprivate func getPrecision(_ value: Double, precision: ChannelValuePrecision) -> Int {
        switch precision {
        case .defaultPrecision:
            return if (value < 100) {
                2
            } else if (value < 1000) {
                1
            } else {
                0
            }
        case .customPrecision(let precision):
            return precision
        }
    }
}
