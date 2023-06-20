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

import XCTest
import RxTest
import RxSwift

@testable import SUPLA

class ChannelListVMTests: ViewModelTest<ChannelListViewState, ChannelListViewEvent> {
    
    private lazy var viewModel: ChannelListViewModel! = { ChannelListViewModel() }()
    
    private lazy var createProfileChannelsListUseCase: CreateProfileChannelsListUseCaseMock! = {
        CreateProfileChannelsListUseCaseMock()
    }()
    private lazy var swapChannelPositionsUseCase: SwapChannelPositionsUseCaseMock! = {
        SwapChannelPositionsUseCaseMock()
    }()
    private lazy var toggleLocationUseCase: ToggleLocationUseCaseMock! = {
        ToggleLocationUseCaseMock()
    }()
    private lazy var provideDetailTypeUseCase: ProvideDetailTypeUseCaseMock! = {
        ProvideDetailTypeUseCaseMock()
    }()
    private lazy var listsEventsManager: ListsEventsManagerMock! = {
        ListsEventsManagerMock()
    }()
    
    override func setUp() {
        DiContainer.shared.register(type: CreateProfileChannelsListUseCase.self, component: createProfileChannelsListUseCase!)
        DiContainer.shared.register(type: SwapChannelPositionsUseCase.self, component: swapChannelPositionsUseCase!)
        DiContainer.shared.register(type: ProvideDetailTypeUseCase.self, component: provideDetailTypeUseCase!)
        DiContainer.shared.register(type: ToggleLocationUseCase.self, component: toggleLocationUseCase!)
        DiContainer.shared.register(type: ListsEventsManager.self, component: listsEventsManager!)
    }
    
    override func tearDown() {
        viewModel = nil
        
        createProfileChannelsListUseCase = nil
        swapChannelPositionsUseCase = nil
        provideDetailTypeUseCase = nil
        toggleLocationUseCase = nil
        listsEventsManager = nil
        
        super.tearDown()
    }
    
    func test_shouldReloadTable_onChannelUpdate() {
        // given
        listsEventsManager.observeChannelUpdatesObservable = Observable.just(())
        
        // when
        observe(viewModel)
        
        // then
        XCTAssertEqual(stateObserver.events.count, 1)
        XCTAssertEqual(eventObserver.events.count, 0)
        
        XCTAssertEqual(createProfileChannelsListUseCase.invokeCounter, 1)
    }
    
    func test_shouldUpdateListItems_onTableReload() {
        // given
        let list: [List] = [.list(items: [])]
        createProfileChannelsListUseCase.observable = Observable.just(list)
        
        let listObserver = scheduler.createObserver([List].self)
        
        // when
        observe(viewModel)
        viewModel.listItems.subscribe(listObserver).disposed(by: disposeBag)
        viewModel.reloadTable()
        
        // then
        XCTAssertEqual(stateObserver.events.count, 1)
        XCTAssertEqual(eventObserver.events.count, 0)
        
        XCTAssertEqual(createProfileChannelsListUseCase.invokeCounter, 1)
        XCTAssertEqual(listObserver.events.count, 2)
    }
    
    func test_shouldSwipeItemsAndReloadTable() {
        // given
        swapChannelPositionsUseCase.observable = Observable.just(())
        let firstItemId: Int32 = 2
        let secondItemId: Int32 = 4
        let locationCaption = "Caption"
        
        // when
        observe(viewModel)
        viewModel.swapItems(firstItem: firstItemId, secondItem: secondItemId, locationCaption: locationCaption)
        
        // then
        XCTAssertEqual(stateObserver.events.count, 1)
        XCTAssertEqual(eventObserver.events.count, 0)
        
        XCTAssertEqual(swapChannelPositionsUseCase.firstRemoteIdArray[0], firstItemId)
        XCTAssertEqual(swapChannelPositionsUseCase.secondRemoteIdArray[0], secondItemId)
        XCTAssertEqual(swapChannelPositionsUseCase.locationCaptionArray[0], locationCaption)
        
        XCTAssertEqual(createProfileChannelsListUseCase.invokeCounter, 1)
    }
    
    func test_shouldOpenLegacyDetail_whenChannelIsOnline() {
        // given
        let channel = SAChannel(testContext: nil)
        channel.value = SAChannelValue(testContext: nil)
        channel.value?.online = true
        
        provideDetailTypeUseCase.detailType = .legacy(type: .temperature)
        
        // when
        observe(viewModel)
        viewModel.onClicked(onItem: channel)
        
        // then
        XCTAssertEqual(stateObserver.events.count, 1)
        XCTAssertEqual(eventObserver.events.count, 1)
        
        XCTAssertEqual(eventObserver.events, [
            .next(0, .navigateToDetail(legacy: .temperature, channelBase: channel))
        ])
    }
    
    func test_shouldOpenLegacyDetail_whenChannelIsOffline() {
        // given
        let channel = SAChannel(testContext: nil)
        channel.func = SUPLA_CHANNELFNC_THERMOMETER
        
        provideDetailTypeUseCase.detailType = .legacy(type: .temperature)
        
        // when
        observe(viewModel)
        viewModel.onClicked(onItem: channel)
        
        // then
        XCTAssertEqual(stateObserver.events.count, 1)
        XCTAssertEqual(eventObserver.events.count, 1)
        
        XCTAssertEqual(eventObserver.events, [
            .next(0, .navigateToDetail(legacy: .temperature, channelBase: channel))
        ])
    }
    
    func test_shouldNotOpenLegacyDetail_whenChannelIsOffline() {
        // given
        let channel = SAChannel(testContext: nil)
        channel.func = SUPLA_CHANNELFNC_STAIRCASETIMER
        
        provideDetailTypeUseCase.detailType = .legacy(type: .temperature)
        
        // when
        observe(viewModel)
        viewModel.onClicked(onItem: channel)
        
        // then
        XCTAssertEqual(stateObserver.events.count, 1)
        XCTAssertEqual(eventObserver.events.count, 0)
    }
    
    func test_shouldNotOpenLegacyDetail_whenNotAssinged() {
        // given
        let channel = SAChannel(testContext: nil)
        channel.value = SAChannelValue(testContext: nil)
        channel.value?.online = true
        channel.func = SUPLA_CHANNELFNC_STAIRCASETIMER
        
        // when
        observe(viewModel)
        viewModel.onClicked(onItem: channel)
        
        // then
        XCTAssertEqual(stateObserver.events.count, 1)
        XCTAssertEqual(eventObserver.events.count, 0)
        
        XCTAssertEqual(provideDetailTypeUseCase.channelBaseArray.count, 1)
    }
    
    func test_shouldOpenLegacyDetail_whenSwitchHasAssignedMeasurementsAndIsOffline() {
        // given
        let channel = SAChannel(testContext: nil)
        channel.func = SUPLA_CHANNELFNC_LIGHTSWITCH
        channel.value = SAChannelValue(testContext: nil)
        channel.value?.sub_value_type = Int16(SUBV_TYPE_IC_MEASUREMENTS)
        
        provideDetailTypeUseCase.detailType = .legacy(type: .ic)
        
        // when
        observe(viewModel)
        viewModel.onClicked(onItem: channel)
        
        // then
        XCTAssertEqual(stateObserver.events.count, 1)
        XCTAssertEqual(eventObserver.events.count, 1)
        
        XCTAssertEqual(provideDetailTypeUseCase.channelBaseArray.count, 1)
        XCTAssertEqual(eventObserver.events, [
            .next(0, .navigateToDetail(legacy: .ic, channelBase: channel))
        ])
    }
    
    func test_shouldReloadTable_whenLocationToggled() {
        // given
        let remoteId = 123
        toggleLocationUseCase.observable = Observable.just(())
        
        // when
        viewModel.toggleLocation(remoteId: remoteId)
        
        // then
        XCTAssertEqual(stateObserver.events.count, 0)
        XCTAssertEqual(eventObserver.events.count, 0)
        
        XCTAssertEqual(toggleLocationUseCase.remoteIdArray[0], remoteId)
        XCTAssertEqual(toggleLocationUseCase.collapsedFlagArray[0], .channel)
        
        XCTAssertEqual(createProfileChannelsListUseCase.invokeCounter, 1)
    }
}
