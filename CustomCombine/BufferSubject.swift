//
//  BufferSubject.swift
//  CustomCombine
//
//  Created by Mars on 2019/11/18.
//  Copyright © 2019 Mars. All rights reserved.
//

import Combine
import Foundation

public struct Buffer<Output, Failure: Error> {
  var values: [Output] = []
  var completion: Subscribers.Completion<Failure>? = nil
  let limit: Int
  let strategy: Publishers.BufferingStrategy<Failure>
  
  public var isEmpty: Bool {
    return values.isEmpty && completion == nil
  }
  
  public mutating func push(_ value: Output) {
    guard completion == nil else { return }
    guard values.count < limit else {
      switch strategy {
      case .dropNewest:
        values.removeLast()
        values.append(value)
      case .dropOldest:
        values.removeFirst()
        values.append(value)
      case .customError(let errFn):
        completion = .failure(errFn())
      @unknown default:
        fatalError()
      }
      
      return
    }
    
    values.append(value)
  }
  
  public mutating func push(completion: Subscribers.Completion<Failure>) {
    guard self.completion == nil else { return }
    self.completion = completion
  }
  
  public mutating func fetch() -> Subscribers.Event<Output, Failure>? {
    if values.count > 0 {
      return .value(values.removeFirst())
    }
    else if let completion = self.completion {
      values = []
      self.completion = nil
      return .complete(completion)
    }
    
    return nil
  }
}

public class BufferSubject<Output, Failure: Error>: Subject {
  class Behavior: SubscriptionBehavior {
    typealias Input = Output
    
    var upstream: Subscription? = nil
    let downstream: AnySubscriber<Input, Failure>
    let subject: BufferSubject<Output, Failure>
    var demand = Subscribers.Demand.none
    var buffer: Buffer<Output, Failure>
    
    init(subject: BufferSubject<Output, Failure>,
         downstream: AnySubscriber<Input, Failure>,
         buffer: Buffer<Output, Failure>){
      self.subject = subject
      self.downstream = downstream
      self.buffer = buffer
    }
    
    func request(_ d: Subscribers.Demand) {
      demand += d
      
      while demand > 0, let next = buffer.fetch() {
        demand -= 1
        
        switch next {
        case .value(let value):
          let newDemand = downstream.receive(value)
          demand += newDemand
        case .complete(let completion):
          downstream.receive(completion: completion)
        }
      }
    }
    
    func receive(_ input: Output) -> Subscribers.Demand {
      if demand > 0 && buffer.isEmpty {
        let newDemand = downstream.receive(input)
        demand = newDemand + demand - 1
      }
      else {
        buffer.push(input)
      }
      
      return .unlimited
    }
    
    func receive(completion: Subscribers.Completion<Failure>) {
      if buffer.isEmpty {
        downstream.receive(completion: completion)
      }
      else {
        buffer.push(completion: completion)
      }
    }
    
    func cancel() {
      subject.subscribers.mutate { $0.removeValue(forKey: self.combineIdentifier) }
    }
  }
  
  typealias SubscriberRecords = Dictionary<CombineIdentifier, CustomSubscription<Behavior>>
  let subscribers = AtomicBox<SubscriberRecords>([:])
  let buffer: AtomicBox<Buffer<Output, Failure>>
  
  public init(limit: Int = 1, whenFull strategy: Publishers.BufferingStrategy<Failure> = .dropOldest) {
    precondition(limit >= 0)
    buffer = AtomicBox(Buffer(limit: limit, strategy: strategy))
  }
  
  public func send(subscription: Subscription) {
    subscription.request(.unlimited)
  }
  
  public func send(_ value: Output) {
    buffer.mutate { b in
      b.push(value)
    }
    for (_, sub) in subscribers.value {
      _ = sub.receive(value)
    }
  }
  
  public func send(completion: Subscribers.Completion<Failure>) {
    buffer.mutate { b in
      b.push(completion: completion)
    }

    for (_, sub) in subscribers.value {
      sub.receive(completion: completion)
    }
    
    subscribers.mutate { $0.removeAll() }
  }

  public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
    let behavior = Behavior(subject: self, downstream: AnySubscriber(subscriber), buffer: buffer.value)
    let subscription = CustomSubscription(behavior: behavior)
    subscribers.mutate { $0[subscription.combineIdentifier] = subscription }
    subscription.receive(subscription: Subscriptions.empty)
  }
}
