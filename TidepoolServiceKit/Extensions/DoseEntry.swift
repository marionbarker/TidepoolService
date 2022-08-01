//
//  DoseEntry.swift
//  TidepoolServiceKit
//
//  Created by Darin Krauss on 2/7/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import LoopKit
import TidepoolKit

/*
 DoseEntry

 Properties:
 - type                         DoseType                    .type, .deliveryType, .subType
 - startDate                    Date                        .time, .duration
 - endDate                      Date                        .duration
 - value                        Double                      .dose.total, .normal, .expectedNormal, .rate, .payload["deliveredUnits"]
 - unit                         DoseUnit                    .dose.total, .normal, .expectedNormal, .rate, .payload["deliveredUnits"]
 - deliveredUnits               Double?                     .dose.total, .normal, .expectedNormal, .payload["deliveredUnits"]
 - description                  String?                     (N/A - unused)
 - insulinType                  InsulinType?                .formulation, .insulinFormulation
 - automatic                    Bool?                       .type, .deliveryType, .subType
 - manuallyEntered              Bool                        .type, .subType
 - syncIdentifier               String?                     .id, .origin.id, .payload["syncIdentifier"]
 - scheduledBasalRate           HKQuantity?                 .rate, .supressed.rate
 - isMutable                    Bool                        .normal, .expectedNormal, .duration, .expectedDuration, .annotations
*/

extension DoseEntry: IdentifiableDatum {
    func data(for userId: String) -> [TDatum] {
        guard syncIdentifier != nil else {
            return []
        }

        switch type {
        case .basal:
            return dataForBasal(for: userId)
        case .bolus:
            return dataForBolus(for: userId)
        case .resume:
            return []
        case .suspend:
            return dataForSuspend(for: userId)
        case .tempBasal:
            return dataForTempBasal(for: userId)
        }
    }

    var syncIdentifierAsString: String { syncIdentifier!.md5hash! }  // Actual sync identifier may be human readable and of variable length

    private func dataForBasal(for userId: String) -> [TDatum] {
        guard let datumScheduledBasalRate = datumScheduledBasalRate else {
            return []
        }

        var payload = datumPayload
        payload["deliveredUnits"] = programmedUnits

        var datum = TScheduledBasalDatum(time: datumTime,
                                         duration: datumDuration,
                                         rate: datumScheduledBasalRate,
                                         scheduleName: StoredSettings.activeScheduleNameDefault,
                                         insulinFormulation: datumInsulinFormulation)
        datum = datum.adornWith(id: datumId(for: userId, type: TScheduledBasalDatum.self),
                                annotations: datumAnnotations,
                                payload: payload,
                                origin: datumOrigin(for: TScheduledBasalDatum.self))
        return [datum]
    }

    private func dataForBolus(for userId: String) -> [TDatum] {
        if manuallyEntered {
            return dataForBolusManuallyEntered(for: userId)
        } else if automatic != true {
            return dataForBolusManual(for: userId)
        } else {
            return dataForBolusAutomatic(for: userId)
        }
    }

    private func dataForBolusManuallyEntered(for userId: String) ->[TDatum] {
        var payload = datumPayload
        payload["duration"] = datumDuration.milliseconds

        var datum = TInsulinDatum(time: datumTime,
                                  dose: TInsulinDatum.Dose(total: deliveredUnits ?? programmedUnits),
                                  formulation: datumInsulinFormulation)
        datum = datum.adornWith(id: datumId(for: userId, type: TInsulinDatum.self),
                                annotations: datumAnnotations,
                                payload: payload,
                                origin: datumOrigin(for: TInsulinDatum.self))
        return [datum]
    }

    private func dataForBolusManual(for userId: String) -> [TDatum] {
        var payload = datumPayload
        payload["duration"] = datumDuration.milliseconds

        let programmedUnits = programmedUnits
        let deliveredUnits = deliveredUnits ?? programmedUnits

        var datum = TNormalBolusDatum(time: datumTime,
                                      normal: !isMutable ? deliveredUnits : programmedUnits,
                                      expectedNormal: !isMutable && programmedUnits != deliveredUnits ? programmedUnits : nil,
                                      insulinFormulation: datumInsulinFormulation)
        datum = datum.adornWith(id: datumId(for: userId, type: TNormalBolusDatum.self),
                                annotations: datumAnnotations,
                                payload: payload,
                                origin: datumOrigin(for: TNormalBolusDatum.self))
        return [datum]
    }

    private func dataForBolusAutomatic(for userId: String) -> [TDatum] {
        var payload = datumPayload
        payload["duration"] = datumDuration.milliseconds

        let programmedUnits = programmedUnits
        let deliveredUnits = deliveredUnits ?? programmedUnits

        var datum = TAutomatedBolusDatum(time: datumTime,
                                         normal: !isMutable ? deliveredUnits : programmedUnits,
                                         expectedNormal: !isMutable && programmedUnits != deliveredUnits ? programmedUnits : nil,
                                         insulinFormulation: datumInsulinFormulation)
        datum = datum.adornWith(id: datumId(for: userId, type: TAutomatedBolusDatum.self),
                                annotations: datumAnnotations,
                                payload: payload,
                                origin: datumOrigin(for: TAutomatedBolusDatum.self))
        return [datum]
    }

    private func dataForSuspend(for userId: String) -> [TDatum] {
        var datum = TSuspendedBasalDatum(time: datumTime,
                                         duration: datumDuration)
        datum.suppressed = datumSuppressed
        datum = datum.adornWith(id: datumId(for: userId, type: TSuspendedBasalDatum.self),
                                annotations: datumAnnotations,
                                payload: datumPayload,
                                origin: datumOrigin(for: TSuspendedBasalDatum.self))
        return [datum]
    }

    private func dataForTempBasal(for userId: String) -> [TDatum] {
        if automatic == false {
            return dataForTempBasalManual(for: userId)
        } else {
            return dataForTempBasalAutomatic(for: userId)
        }
    }

    private func dataForTempBasalManual(for userId: String) -> [TDatum] {
        var payload = datumPayload
        payload["deliveredUnits"] = deliveredUnits

        var datum = TTemporaryBasalDatum(time: datumTime,
                                         duration: !isMutable ? datumDuration : 0,
                                         expectedDuration: !isMutable && datumDuration < basalDatumExpectedDuration ? basalDatumExpectedDuration : nil,
                                         rate: datumRate,
                                         insulinFormulation: datumInsulinFormulation)
        datum.suppressed = datumSuppressed
        datum = datum.adornWith(id: datumId(for: userId, type: TTemporaryBasalDatum.self),
                                annotations: datumAnnotations,
                                payload: payload,
                                origin: datumOrigin(for: TTemporaryBasalDatum.self))
        return [datum]
    }

    private func dataForTempBasalAutomatic(for userId: String) -> [TDatum] {
        var payload = datumPayload
        payload["deliveredUnits"] = deliveredUnits

        var datum = TAutomatedBasalDatum(time: datumTime,
                                         duration: !isMutable ? datumDuration : 0,
                                         expectedDuration: !isMutable && datumDuration < basalDatumExpectedDuration ? basalDatumExpectedDuration : nil,
                                         rate: datumRate,
                                         scheduleName: StoredSettings.activeScheduleNameDefault,
                                         insulinFormulation: datumInsulinFormulation)
        datum.suppressed = datumSuppressed
        datum = datum.adornWith(id: datumId(for: userId, type: TAutomatedBasalDatum.self),
                                annotations: datumAnnotations,
                                payload: payload,
                                origin: datumOrigin(for: TAutomatedBasalDatum.self))
        return [datum]
    }

    private var datumTime: Date { startDate }

    private var datumDuration: TimeInterval { startDate.distance(to: endDate) }

    private var datumRate: Double { unitsPerHour }

    private var datumScheduledBasalRate: Double? { scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour) }

    private var datumSuppressed: TScheduledBasalDatum.Suppressed? {
        guard let datumScheduledBasalRate = datumScheduledBasalRate else {
            return nil
        }
        return TScheduledBasalDatum.Suppressed(rate: datumScheduledBasalRate,
                                               scheduleName: StoredSettings.activeScheduleNameDefault)
    }

    private var datumInsulinFormulation: TInsulinDatum.Formulation? { insulinType?.datum }

    private var datumAnnotations: [TDictionary]? {
        guard isMutable else {
            return nil
        }

        switch type {
        case .basal, .suspend, .tempBasal:
            return [TDictionary(["code": "basal/unknown-duration"])]
        case .bolus:
            return [TDictionary(["code": "bolus/mutable"])]
        case .resume:
            return nil
        }
    }

    private var datumPayload: TDictionary {
        var dictionary = TDictionary()
        dictionary["syncIdentifier"] = syncIdentifier
        return dictionary
    }

    private var basalDatumExpectedDuration: TimeInterval { .minutes(30) }
}

extension DoseEntry {
    var selectors: [TDatum.Selector] {
        guard syncIdentifier != nil else {
            return []
        }

        switch type {
        case .basal:
            return [datumSelector(for: TScheduledBasalDatum.self)]
        case .bolus:
            if manuallyEntered {
                return [datumSelector(for: TInsulinDatum.self)]
            } else if automatic != true {
                return [datumSelector(for: TNormalBolusDatum.self)]
            } else {
                return [datumSelector(for: TAutomatedBolusDatum.self)]
            }
        case .resume:
            return []
        case .suspend:
            return [datumSelector(for: TSuspendedBasalDatum.self)]
        case .tempBasal:
            if automatic == false {
                return [datumSelector(for: TTemporaryBasalDatum.self)]
            } else {
                return [datumSelector(for: TAutomatedBasalDatum.self)]
            }
        }
    }
}

extension TAutomatedBasalDatum: TypedDatum {
    static var resolvedType: String { "\(TDatum.DatumType.basal.rawValue)/\(TBasalDatum.DeliveryType.automated.rawValue)" }
}

extension TScheduledBasalDatum: TypedDatum {
    static var resolvedType: String { "\(TDatum.DatumType.basal.rawValue)/\(TBasalDatum.DeliveryType.scheduled.rawValue)" }
}

extension TSuspendedBasalDatum: TypedDatum {
    static var resolvedType: String { "\(TDatum.DatumType.basal.rawValue)/\(TBasalDatum.DeliveryType.suspended.rawValue)" }
}

extension TTemporaryBasalDatum: TypedDatum {
    static var resolvedType: String { "\(TDatum.DatumType.basal.rawValue)/\(TBasalDatum.DeliveryType.temporary.rawValue)" }
}

extension TAutomatedBolusDatum: TypedDatum {
    static var resolvedType: String { "\(TDatum.DatumType.bolus.rawValue)/\(TBolusDatum.SubType.automated.rawValue)" }
}

extension TNormalBolusDatum: TypedDatum {
    static var resolvedType: String { "\(TDatum.DatumType.bolus.rawValue)/\(TBolusDatum.SubType.normal.rawValue)" }
}

extension TInsulinDatum: TypedDatum {
    static var resolvedType: String { TDatum.DatumType.insulin.rawValue }
}