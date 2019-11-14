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
      subject.subscribers.removeValue(forKey: combineIdentifier)
    }
  }

  var subscribers: Dictionary<
    CombineIdentifier, CustomSubscription<Behavior>> = [:]

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

    subscribers.removeAll()
  }

  // Publisher
  public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
    let behavior = Behavior(subject: self, downstream: AnySubscriber(subscriber))
    let subscription = CustomSubscription(behavior: behavior)

    subscribers[subscription.combineIdentifier] = subscription
    subscription.receive(subscription: Subscriptions.empty)
  }
}
