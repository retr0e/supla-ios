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

class DeviceCatalogVM: WebContentVM<DeviceCatalogViewState, DeviceCatalogViewEvent> {
    private let url = "https://www.supla.org/pl/"

    override func provideUrl() -> URL {
        URL(string: url)!
    }

    override func updateLoading(_ loading: Bool) {
        updateView { $0.changing(path: \.loading, to: loading) }
    }

    override func shouldHandle(url: String?) -> Bool {
        if (url == self.url) {
            return true
        }
        if let urlString = url,
           let url = URL(string: urlString)
        {
            send(event: .openUrl(url: url))
        }
        return false
    }

    override func defaultViewState() -> DeviceCatalogViewState { DeviceCatalogViewState() }
}

enum DeviceCatalogViewEvent: ViewEvent {
    case openUrl(url: URL)
}

struct DeviceCatalogViewState: WebContentViewState {
    var loading: Bool = true
}
