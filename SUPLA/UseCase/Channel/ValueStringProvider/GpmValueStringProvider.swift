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

class GpmValueStringProvider: ChannelValueStringProvider {
    @Singleton<GpmValueProvider> private var gpmValueProvider
    
    private lazy var formatter: NumberFormatter! = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.decimalSeparator = Locale.current.decimalSeparator
        return formatter
    }()
    
    func handle(function: Int32) -> Bool {
        function == SUPLA_CHANNELFNC_GENERAL_PURPOSE_METER
            || function == SUPLA_CHANNELFNC_GENERAL_PURPOSE_MEASUREMENT
    }
    
    func value(_ channel: SAChannel, valueType: ValueType, withUnit: Bool) -> String {
        guard let value = gpmValueProvider.value(channel, valueType: valueType) as? Double
        else {
            return NO_VALUE_TEXT
        }
        
        if (value.isNaN) {
            return NO_VALUE_TEXT
        }
        
        guard let config = channel.config?.configAsSuplaConfig() as? SuplaChannelGeneralPurposeBaseConfig
        else {
            return String(format: "%.f", value)
        }
        
        let formatter = GpmValueFormatter(config: config)
        return formatter.format(value, withUnit: withUnit)
    }
    
}
