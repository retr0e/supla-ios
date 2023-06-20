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

final class CreateProfileScenesListUseCaseTests: UseCaseTest<[List]> {
    
    private lazy var useCase: CreateProfileScenesListUseCase! = { CreateProfileScenesListUseCaseImpl() }()
    
    private lazy var sceneRepository: SceneRepositoryMock! = {
        SceneRepositoryMock()
    }()
    private lazy var profileRepository: ProfileRepositoryMock! = {
        ProfileRepositoryMock()
    }()
    
    override func setUp() {
        DiContainer.shared.register(type: (any SceneRepository).self, component: sceneRepository!)
        DiContainer.shared.register(type: (any ProfileRepository).self, component: profileRepository!)
    }
    
    override func tearDown() {
        useCase = nil
        sceneRepository = nil
        profileRepository = nil
        
        super.tearDown()
    }
    
    func test_shouldProvideItems_whenLocationIsExpanded() {
        // given
        let profile = AuthProfileItem(testContext: nil)
        profileRepository.activeProfileObservable = Observable.just(profile)
        
        let location1 = _SALocation(testContext: nil)
        location1.caption = "Location 1"
        location1.location_id = 1
        let scene1 = SAScene(testContext: nil)
        scene1.location = location1
        
        let location2 = _SALocation(testContext: nil)
        location2.caption = "Location 2"
        location2.location_id = 2
        let scene2 = SAScene(testContext: nil)
        scene2.location = location2
        
        sceneRepository.allVisibleScenesObservable = Observable.just([ scene1, scene2 ])
        
        // when
        useCase.invoke().subscribe(observer).disposed(by: disposeBag)
        
        // then
        XCTAssertEqual(observer.events.count, 2)
        guard let items = observer.events[0].value.element?.first?.items else {
            XCTFail("No items produced")
            return
        }
        
        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items, [
            .location(location: location1),
            .scene(scene: scene1),
            .location(location: location2),
            .scene(scene: scene2)
        ])
    }
    
    func test_shouldNotProvideItems_whenLocationIsCollapsed() {
        // given
        let profile = AuthProfileItem(testContext: nil)
        profileRepository.activeProfileObservable = Observable.just(profile)
        
        let location1 = _SALocation(testContext: nil)
        location1.caption = "Location 1"
        location1.location_id = 1
        location1.collapsed = 0 | CollapsedFlag.scene.rawValue
        
        let scene1 = SAScene(testContext: nil)
        scene1.location = location1
        
        let location2 = _SALocation(testContext: nil)
        location2.caption = "Location 2"
        location2.location_id = 2
        let scene2 = SAScene(testContext: nil)
        scene2.location = location2
        
        sceneRepository.allVisibleScenesObservable = Observable.just([ scene1, scene2 ])
        
        // when
        useCase.invoke().subscribe(observer).disposed(by: disposeBag)
        
        // then
        XCTAssertEqual(observer.events.count, 2)
        guard let items = observer.events[0].value.element?.first?.items else {
            XCTFail("No items produced")
            return
        }
        
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items, [
            .location(location: location1),
            .location(location: location2),
            .scene(scene: scene2)
        ])
    }
    
    func test_shouldMergeLocationWithTheSameNameIntoOne() {
        // given
        let profile = AuthProfileItem(testContext: nil)
        profileRepository.activeProfileObservable = Observable.just(profile)
        
        let location1 = _SALocation(testContext: nil)
        location1.caption = "Location"
        location1.location_id = 1
        
        let scene1 = SAScene(testContext: nil)
        scene1.location = location1
        
        let location2 = _SALocation(testContext: nil)
        location2.caption = "Location"
        location2.location_id = 2
        let scene2 = SAScene(testContext: nil)
        scene2.location = location2
        
        sceneRepository.allVisibleScenesObservable = Observable.just([ scene1, scene2 ])
        
        // when
        useCase.invoke().subscribe(observer).disposed(by: disposeBag)
        
        // then
        XCTAssertEqual(observer.events.count, 2)
        guard let items = observer.events[0].value.element?.first?.items else {
            XCTFail("No items produced")
            return
        }
        
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items, [
            .location(location: location1),
            .scene(scene: scene1),
            .scene(scene: scene2)
        ])
    }
}

