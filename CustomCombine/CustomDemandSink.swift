//
//  CustomDemandSink.swift
//  CustomCombine
//
//  Created by Mars on 2019/11/26.
//  Copyright © 2019 Mars. All rights reserved.
//

import Combine

public struct CustomDemandSink<Input, Failure: Error>: Subscriber, Cancellable {
  public let combineIdentifier: CombineIdentifier = CombineIdentifier()
  let activeSubscription = AtomicBox<(demand: Int, subscription: Subscription?)>((0, nil))
  let value: (Input) -> Void
  let completion: (Subscribers.Completion<Failure>) -> Void
  
  public init(
    demand: Int,
    receiveValue: @escaping ((Input) -> Void),
    receiveCompletion: @escaping ((Subscribers.Completion<Failure>) -> Void)) {
    activeSubscription.mutate { $0.demand = demand }
    self.value = receiveValue
    self.completion = receiveCompletion
  }
  
  public func increaseDemand(_ value: Int) {
    activeSubscription.mutate { $0.subscription?.request(.max(value)) }
  }
  
  public func cancel() {
    activeSubscription.mutate {
      $0.subscription?.cancel()
      $0 = (0, nil)
    }
  }
  
  public func receive(subscription: Subscription) {
    activeSubscription.mutate {
      if $0.subscription == nil {
        $0.subscription = subscription
        
        if $0.demand > 0 {
          $0.demand -= 1
          subscription.request(.max(1))
        }
      }
    }
  }
  
  public func receive(_ input: Input) -> Subscribers.Demand {
    value(input)
    
    var demand = Subscribers.Demand.none
    activeSubscription.mutate {
      if $0.demand > 0 {
        $0.demand -= 1
        demand = .max(1)
      }
    }
    
    return demand
  }
  
  public func receive(completion c: Subscribers.Completion<Failure>) {
    completion(c)
    activeSubscription.mutate {
      $0 = (0, nil)
    }
  }
}
