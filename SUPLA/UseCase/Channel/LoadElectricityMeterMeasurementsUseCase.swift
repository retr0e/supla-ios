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

protocol LoadElectricityMeterMeasurementsUseCase {
    func invoke(remoteId: Int32, startDate: Date?, endDate: Date?) -> Observable<ElectricityMeasurements>
}

extension LoadElectricityMeterMeasurementsUseCase {
    func invoke(remoteId: Int32, startDate: Date) -> Observable<ElectricityMeasurements> {
        invoke(remoteId: remoteId, startDate: startDate, endDate: nil)
    }

    func invoke(remoteId: Int32, endDate: Date) -> Observable<ElectricityMeasurements> {
        invoke(remoteId: remoteId, startDate: nil, endDate: endDate)
    }
}

final class LoadElectricityMeterMeasurementsUseCaseImpl: LoadElectricityMeterMeasurementsUseCase {
    @Singleton<ElectricityMeasurementItemRepository> private var electricityMeasurementItemRepository
    @Singleton<ReadChannelByRemoteIdUseCase> private var readChannelByRemoteIdUseCase
    @Singleton<ProfileRepository> private var profileRepository
    @Singleton<UserStateHolder> private var userStateHolder
    @Singleton<DateProvider> private var dateProvider

    func invoke(remoteId: Int32, startDate: Date?, endDate: Date?) -> Observable<ElectricityMeasurements> {
        profileRepository.getActiveProfile()
            .flatMapFirst { profile in
                self.electricityMeasurementItemRepository.findMeasurements(
                    remoteId: remoteId,
                    profile: profile,
                    startDate: startDate ?? Date(timeIntervalSince1970: 0),
                    endDate: endDate ?? self.dateProvider.currentDate()
                )
            }
            .flatMapFirst { measurements in
                self.readChannelByRemoteIdUseCase.invoke(remoteId: remoteId).map { ($0, measurements) }
            }.map { channel, measurements in
                switch (self.userStateHolder.getElectricityMeterSettings(profileId: channel.profile.idString, remoteId: remoteId).balancing) {
                case .hourly: self.hourlyBalance(measurements)
                case .arithmetic: self.arithmeticBalance(measurements)
                default: self.defaultBalance(channel, measurements)
                }
            }
    }

    private func hourlyBalance(_ measurements: [SAElectricityMeasurementItem]) -> ElectricityMeasurements {
        let balanceValue = measurements.balanceHourly()
        return ElectricityMeasurements(
            forwardActiveEnergy: balanceValue.map { $0.forwarded }.sum(),
            reverseActiveEnergy: balanceValue.map { $0.reversed }.sum()
        )
    }

    private func arithmeticBalance(_ measurements: [SAElectricityMeasurementItem]) -> ElectricityMeasurements {
        ElectricityMeasurements(
            forwardActiveEnergy: measurements.map { $0.phase1_fae + $0.phase2_fae + $0.phase3_fae }.sum(),
            reverseActiveEnergy: measurements.map { $0.phase1_rae + $0.phase2_rae + $0.phase3_rae }.sum()
        )
    }

    private func defaultBalance(_ channel: SAChannel, _ measurements: [SAElectricityMeasurementItem]) -> ElectricityMeasurements {
        if (channel.phases.count > 1 && channel.ev?.electricityMeter().suplaElectricityMeterMeasuredTypes.hasBalance == true) {
            ElectricityMeasurements(
                forwardActiveEnergy: measurements.map { $0.fae_balanced }.sum(),
                reverseActiveEnergy: measurements.map { $0.rae_balanced }.sum()
            )
        } else {
            arithmeticBalance(measurements)
        }
    }
}

struct ElectricityMeasurements {
    let forwardActiveEnergy: Double
    let reverseActiveEnergy: Double

    func toForwardEnergy(
        formatter: ListElectricityMeterValueFormatter,
        value: SAElectricityMeterExtendedValue? = nil
    ) -> EnergyData? {
        if let value {
            value.hasForwardEnergy.ifTrue {
                EnergyData(
                    formatter: formatter,
                    energy: forwardActiveEnergy,
                    pricePerUnit: value.pricePerUnit(),
                    currency: value.currency()
                )
            }
        } else {
            EnergyData(energy: formatter.format(forwardActiveEnergy))
        }
    }

    func toReverseEnergy(
        formatter: ListElectricityMeterValueFormatter,
        value: SAElectricityMeterExtendedValue? = nil
    ) -> EnergyData? {
        if let value {
            value.hasReverseEnergy.ifTrue { EnergyData(energy: formatter.format(reverseActiveEnergy)) }
        } else {
            EnergyData(energy: formatter.format(reverseActiveEnergy))
        }
    }
}
