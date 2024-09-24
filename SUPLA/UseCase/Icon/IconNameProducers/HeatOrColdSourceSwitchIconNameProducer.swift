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

final class HeatOrColdSourceSwitchIconNameProducer: IconNameProducer {
    func accepts(function: Int32) -> Bool {
        function == SUPLA_CHANNELFNC_HEATORCOLDSOURCESWITCH
    }

    func produce(iconData: IconData) -> String {
        addStateSufix(name: altIcon(iconData.altIcon), state: iconData.state)
    }

    private func altIcon(_ altIcon: Int32) -> String {
        switch (altIcon) {
        case 1: .Icons.fncHeatOrColdSourceSwitch2
        case 2: .Icons.fncHeatOrColdSourceSwitch3
        case 3: .Icons.fncHeatOrColdSourceSwitch4
        case 4: .Icons.fncHeatOrColdSourceSwitch5
        case 5: .Icons.fncHeatOrColdSourceSwitch6
        default: .Icons.fncHeatOrColdSourceSwitch
        }
    }
}
