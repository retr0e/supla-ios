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

struct GroupOnlineSummary {
    let onlineCount: Int
    let count: Int
}

protocol GetGroupOnlineSummaryUseCase {
    func invoke(remoteId: Int32) -> Observable<GroupOnlineSummary>
}

final class GetGroupOnlineSummaryUseCaseImpl: GetGroupOnlineSummaryUseCase {
    @Singleton<ProfileRepository> private var profileRepository
    @Singleton<ChannelGroupRelationRepository> private var channelGroupRelationRepository

    func invoke(remoteId: Int32) -> Observable<GroupOnlineSummary> {
        profileRepository.getActiveProfile()
            .flatMapFirst { profile in
                self.channelGroupRelationRepository.getRelations(for: profile, andGroup: remoteId)
            }.map { relations in
                var onlineIds: [Int32] = []
                var allIds: [Int32] = []
                for relation in relations {
                    if (!allIds.contains(relation.channel_id)) {
                        allIds.append(relation.channel_id)
                    }
                    if (relation.value?.online == true && !onlineIds.contains(relation.channel_id)) {
                        onlineIds.append(relation.channel_id)
                    }
                }
                return GroupOnlineSummary(onlineCount: onlineIds.count, count: allIds.count)
            }
    }
}
