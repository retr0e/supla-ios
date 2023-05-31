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

class GroupListViewModel: BaseTableViewModel<GroupListViewState, GroupListViewEvent> {
    
    @Singleton<CreateProfileGroupsListUseCase> private var createProfileGroupsListUseCase
    @Singleton<SwapGroupPositionsUseCase> private var swapGroupPositionsUseCase
    @Singleton<ListsEventsManager> private var listsEventsManager
    
    override init() {
        super.init()
        
        listsEventsManager.observeGroupUpdates()
            .subscribe(
                onNext: { self.reloadTable() }
            )
            .disposed(by: self)
    }
    
    override func defaultViewState() -> GroupListViewState { GroupListViewState() }
    
    override func reloadTable() {
        createProfileGroupsListUseCase.invoke()
            .subscribe(onNext: { self.listItems.accept($0) })
            .disposed(by: self)
    }
    
    override func swapItems(firstItem: Int32, secondItem: Int32, locationId: Int32) {
        swapGroupPositionsUseCase
            .invoke(firstRemoteId: firstItem, secondRemoteId: secondItem, locationId: Int(locationId))
            .subscribe(onNext: { self.reloadTable() })
            .disposed(by: self)
    }
    
    override func getCollapsedFlag() -> CollapsedFlag { .group }
}

enum GroupListViewEvent: ViewEvent {
}

struct GroupListViewState: ViewState {}
