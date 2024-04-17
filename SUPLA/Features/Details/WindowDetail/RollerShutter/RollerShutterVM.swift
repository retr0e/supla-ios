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

final class RollerShutterVM: BaseWindowVM<RollerShutterViewState> {
    override func defaultViewState() -> RollerShutterViewState { RollerShutterViewState() }

    override func handleChannel(_ channel: SAChannel) {
        guard let value = channel.value?.asRollerShutterValue() else { return }

        updateView {
            if ($0.manualMoving) {
                return $0
            }

            let position = value.hasValidPosition ? value.position : 0
            let positionValue: WindowGroupedValue = .similar(value.online ? CGFloat(position) : 25)
            let windowState = $0.rollerShutterWindowState
                .changing(path: \.position, to: positionValue)
                .changing(path: \.positionTextFormat, to: positionTextFormat)
                .changing(path: \.bottomPosition, to: CGFloat(value.bottomPosition))

            return updateChannel($0, channel, value) {
                $0.changing(path: \.rollerShutterWindowState, to: windowState)
            }
        }
    }

    override func handleGroup(_ group: SAChannelGroup, _ onlineSummary: GroupOnlineSummary) {
        updateView {
            if ($0.manualMoving) {
                return $0
            }

            let positions = group.getRollerShutterPositions()
            let overallPosition = getGroupPercentage(positions, !$0.rollerShutterWindowState.markers.isEmpty)
            let windowState = $0.rollerShutterWindowState
                .changing(path: \.position, to: group.isOnline() ? overallPosition : .similar(25))
                .changing(path: \.positionTextFormat, to: positionTextFormat)
                .changing(path: \.markers, to: overallPosition.isDifferent() ? positions : [])

            return updateGroup($0, group, onlineSummary) {
                $0.changing(path: \.rollerShutterWindowState, to: windowState)
                    .changing(path: \.positionUnknown, to: overallPosition == .invalid)
            }
        }
    }
}

struct RollerShutterViewState: BaseWindowViewState {
    var remoteId: Int32? = nil
    var rollerShutterWindowState: RollerShutterWindowState = .init(position: .similar(0))
    var issues: [ChannelIssueItem] = []
    var offline: Bool = true
    var showClosingPercentage: Bool = false
    var calibrating: Bool = false
    var calibrationPossible: Bool = false
    var positionUnknown: Bool = false
    var touchTime: CGFloat? = nil
    var isGroup: Bool = false
    var onlineStatusString: String? = nil
    var moveStartTime: TimeInterval? = nil
    var manualMoving: Bool = false

    var windowState: any WindowState { rollerShutterWindowState }
}

private extension SAChannelGroup {
    func getRollerShutterPositions() -> [CGFloat] {
        guard let totalValue = total_value as? GroupTotalValue else { return [] }
        return totalValue.values.compactMap { valueToPosition($0) }
    }

    private func valueToPosition(_ baseGroupValue: BaseGroupValue) -> CGFloat? {
        guard let value = baseGroupValue as? RollerShutterGroupValue else { return nil }

        return if (value.position < 100 && value.closedSensorActive) {
            CGFloat(100)
        } else {
            CGFloat(value.position)
        }
    }
}
