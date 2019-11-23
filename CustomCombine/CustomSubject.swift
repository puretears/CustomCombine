//
//  CustomSubject.swift
//  CustomCombine
//
//  Created by Mars on 2019/11/8.
//  Copyright © 2019 Mars. All rights reserved.
//

import Combine

public class CustomSubject<Output, Failure: Error>: Subject {

  class Behavior: SubscriptionBehavior {
    typealias Input = Output

    var demand: Subscribers.Demand = .none
    var upstream: Subscription? = nil
    let downstream: AnySubscriber<Output, Failure>

    let subject: CustomSubject<Output, Failure>

    init(subject: CustomSubject<Output, Failure>, downstream: AnySubscriber<Output, Failure>) {
      self.subject = subject
      self.downstream = downstream
    }

    func request(_ d: Subscribers.Demand) {
      demand += d
      upstream?.request(d)
    }
    
    func cancel() {
      subject.$subscribers.mutate { $0.removeValue(forKey: self.combineIdentifier) }
    }
  }
  
  typealias SubscriberRecords = Dictionary<CombineIdentifier, CustomSubscription<Behavior>>
//  var subscribers = AtomicBox<SubscriberRecords>([:])
  @Atomic<SubscriberRecords>(content: [:]) var subscribers

  // Subject
  public func send(subscription: Subscription) {
    subscription.request(.unlimited)
  }

  public func send(_ value: Output) {
    for (_, sub) in subscribers {
      _ = sub.receive(value)
    }
  }

  public func send(completion: Subscribers.Completion<Failure>) {
    for (_, sub) in subscribers {
      _ = sub.receive(completion: completion)
    }

    $subscribers.mutate { $0.removeAll() }
  }

  // Publisher
  public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
    let behavior = Behavior(subject: self, downstream: AnySubscriber(subscriber))
    let subscription = CustomSubscription(behavior: behavior)

    $subscribers.mutate { $0[subscription.combineIdentifier] = subscription }
    subscription.receive(subscription: Subscriptions.empty)
  }
}
