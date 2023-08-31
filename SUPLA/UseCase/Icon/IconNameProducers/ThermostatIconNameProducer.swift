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

final class ThermostatIconNameProducer: IconNameProducer {
    
    func accepts(function: Int32) -> Bool {
        return function == SUPLA_CHANNELFNC_HVAC_THERMOSTAT || function == SUPLA_CHANNELFNC_HVAC_DOMESTIC_HOT_WATER
    }
    
    func produce(iconData: IconData) -> String {
        if (iconData.function == SUPLA_CHANNELFNC_HVAC_DOMESTIC_HOT_WATER) {
            return "icon_thermostat_dhw"
        }
        
        if let subfunction = iconData.subfunction {
            switch (subfunction) {
            case .heat: return "icon_thermostat_heat"
            case .cool: return "icon_thermostat_cool"
            default: return CHANNEL_UNKNOWN_ICON_NAME
            }
        }
        
        return CHANNEL_UNKNOWN_ICON_NAME
    }
    
    
}
