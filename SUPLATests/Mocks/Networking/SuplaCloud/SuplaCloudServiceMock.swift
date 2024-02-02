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

@testable import SUPLA
import RxSwift

final class SuplaCloudServiceMock: SuplaCloudService {
    
    var initialMeasurementsParameters: [Int32] = []
    var initialMeasurementsReturns: Observable<(response: HTTPURLResponse, data: Data)> = .empty()
    func getInitialMeasurements(remoteId: Int32) -> Observable<(response: HTTPURLResponse, data: Data)> {
        initialMeasurementsParameters.append(remoteId)
        return initialMeasurementsReturns
    }
    
    var temperatureMeasurementsParameters: [(Int32, TimeInterval)] = []
    var temperatureMeasurementsReturns: [Observable<[SuplaCloudClient.TemperatureMeasurement]>] = []
    private var temperatureMeasurementsCurrent = 0
    func getTemperatureMeasurements(remoteId: Int32, afterTimestamp: TimeInterval) -> Observable<[SuplaCloudClient.TemperatureMeasurement]> {
        temperatureMeasurementsParameters.append((remoteId, afterTimestamp))
        
        let id = temperatureMeasurementsCurrent
        temperatureMeasurementsCurrent += 1
        if (id < temperatureMeasurementsReturns.count) {
            return temperatureMeasurementsReturns[id]
        } else {
            return .empty()
        }
    }
    
    var temperatureAndHumidityMeasurementsParameters: [(Int32, TimeInterval)] = []
    var temperatureAndHumidityMeasurementsReturns: [Observable<[SuplaCloudClient.TemperatureAndHumidityMeasurement]>] = []
    private var temperatureAndHumidityMeasurementsCurrent = 0
    func getTemperatureAndHumidityMeasurements(remoteId: Int32, afterTimestamp: TimeInterval) -> Observable<[SuplaCloudClient.TemperatureAndHumidityMeasurement]> {
        temperatureAndHumidityMeasurementsParameters.append((remoteId, afterTimestamp))
        
        let id = temperatureAndHumidityMeasurementsCurrent
        temperatureAndHumidityMeasurementsCurrent += 1
        if (id < temperatureAndHumidityMeasurementsReturns.count) {
            return temperatureAndHumidityMeasurementsReturns[id]
        } else {
            return .empty()
        }
    }
    
    var generalPurposeMeasurementParameters: [(Int32, TimeInterval)] = []
    var genenralPurposeMeasurementReturns: [Observable<[SuplaCloudClient.GeneralPurposeMeasurement]>] = []
    private var generalPurposeMeasurementCurrent = 0
    func getGeneralPurposeMeasurement(remoteId: Int32, afterTimestamp: TimeInterval) -> Observable<[SuplaCloudClient.GeneralPurposeMeasurement]> {
        generalPurposeMeasurementParameters.append((remoteId, afterTimestamp))
        
        let id = generalPurposeMeasurementCurrent
        generalPurposeMeasurementCurrent += 1
        if (id < genenralPurposeMeasurementReturns.count) {
            return genenralPurposeMeasurementReturns[id]
        } else {
            return .empty()
        }
    }
    
    var generalPurposeMeterParameters: [(Int32, TimeInterval)] = []
    var generalPurposeMeterReturns: [Observable<[SuplaCloudClient.GeneralPurposeMeter]>] = []
    private var generalPurposeMeterCurrent = 0
    func getGeneralPurposeMeter(remoteId: Int32, afterTimestamp: TimeInterval) -> Observable<[SuplaCloudClient.GeneralPurposeMeter]> {
        generalPurposeMeterParameters.append((remoteId, afterTimestamp))
        
        let id = generalPurposeMeterCurrent
        generalPurposeMeterCurrent += 1
        if (id < generalPurposeMeterReturns.count) {
            return generalPurposeMeterReturns[id]
        } else {
            return .empty()
        }
    }
}
