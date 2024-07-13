//
//  File.swift
//  PlantRecognition
//
//  Created by wzqd on 2024/7/13.
//

import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    static let Instance = HealthKitManager()

    var healthStore = HKHealthStore()

    
    init() {
        authorizeHealthKit()
    }


    func authorizeHealthKit() {
        let healthKitTypes: Set = [ HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)! ] // We want to access the step count.
        healthStore.requestAuthorization(toShare: healthKitTypes, read: healthKitTypes) { (success, error) in  // We will check the authorization.
            if success {}
            else{
                print("\(String(describing: error))")
            }
        }
    }
    
    public func getDailyStepCount(afterCompletion: @escaping (Int) -> Void){
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {return}

        let now = Date()  //end time
        let startDate = Calendar.current.startOfDay(for: now) //start time
        let predicate = HKQuery.predicateForSamples(
              withStart: startDate,
              end: now,
              options: .strictStartDate) //query predicate

        let query = HKStatisticsQuery(
              quantityType: stepCountType,
              quantitySamplePredicate: predicate,
              options: .cumulativeSum)
        { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                print("failed to read step count: \(error?.localizedDescription ?? "UNKNOWN ERROR")")
                return
            }
            
            
            let steps = Int(sum.doubleValue(for: HKUnit.count()))
            
            afterCompletion(steps)
            
//            DispatchQueue.main.async {
////                self.stepCountToday = steps
//                afterCompletion(steps) // Return the step count.
//            }
        }
        
        healthStore.execute(query)
    }
    
    
    func getWeeklyStepCount(afterCompletion: @escaping ([Int:Int]) -> Void) {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {return}
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find the start date (Monday) of the current week
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
          print("Failed to calculate the start date of the week.")
          return
        }

        // Find the end date (Sunday) of the current week
        guard let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) else {
          print("Failed to calculate the end date of the week.")
          return
        }

        let predicate = HKQuery.predicateForSamples(
          withStart: startOfWeek,
          end: endOfWeek,
          options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(
          quantityType: stepCountType,
          quantitySamplePredicate: predicate,
          options: .cumulativeSum, // fetch the sum of steps for each day
          anchorDate: startOfWeek,
          intervalComponents: DateComponents(day: 1) // interval to make sure the sum is per 1 day
        )

        query.initialResultsHandler = { _, result, error in
          guard let result = result else {
              if let error = error {
                  print("An error occurred while retrieving step count: \(error.localizedDescription)")
            }
            return
        }
        
        var thisWeekSteps: [Int: Int] = [1: 0, 2: 0, 3: 0,
                                    4: 0, 5: 0, 6: 0, 7: 0]

        result.enumerateStatistics(from: startOfWeek, to: endOfWeek) { statistics, _ in
            if let quantity = statistics.sumQuantity() {
              let steps = Int(quantity.doubleValue(for: HKUnit.count()))
              let day = calendar.component(.weekday, from: statistics.startDate)
              thisWeekSteps[day] = steps
            }
          }
            
          afterCompletion(thisWeekSteps)
        }

        healthStore.execute(query)
    }

    
    
}
