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
import RxSwift

protocol ToggleLocationUseCase {
    func invoke(remoteId: Int, collapsedFlag: CollapsedFlag) -> Observable<Void>
}

class ToggleLocationUseCaseImpl: ToggleLocationUseCase {
    
    @Singleton<LocationRepository> var locationRepository
    
    func invoke(remoteId: Int, collapsedFlag: CollapsedFlag) -> Observable<Void> {
        return locationRepository.queryItem(NSPredicate(format: "location_id = %d", remoteId))
            .compactMap { $0 }
            .map { item in
                item.collapsed ^= collapsedFlag.rawValue
                return item
            }
            .flatMap { item in self.locationRepository.save(item) }
    }
}
