//
//  MergeSink.swift
//  CustomCombine
//
//  Created by Mars on 2019/11/21.
//  Copyright © 2019 Mars. All rights reserved.
//

import Combine

public class MergeInput<I>: Publisher, Cancellable {
  public typealias Output = I
  public typealias Failure = Never
  
  private let subscriptions = AtomicBox(Dictionary<CombineIdentifier, Subscribers.Sink<I, Never>>())
  private let subject = PassthroughSubject<I, Never>()
  
  public init() {}
  
  deinit { cancel() }
  
  public func receive<S>(subscriber: S) where S: Subscriber, S.Input == I, S.Failure == Never {
    subject.receive(subscriber: subscriber)
  }
  
  public func cancel() {
    subscriptions.mutate {
      $0.values.forEach { $0.cancel() }
      $0.removeAll()
    }
  }
  
  public func subscribe<P>(_ publisher: P) where P: Publisher, P.Output == I, P.Failure == Never {
    var identifier: CombineIdentifier?
    
    let sink = Subscribers.Sink<I, P.Failure>(
      receiveCompletion: { _ in
        self.subscriptions.mutate {
          _ = $0.removeValue(forKey: identifier!)
        }
      }, receiveValue: {
        self.subject.send($0)
      })
    
    identifier = sink.combineIdentifier
    subscriptions.mutate { $0[sink.combineIdentifier] = sink }
    
    publisher.subscribe(sink)
  }
}

public extension Publisher where Failure == Never {
  func merge(into mergeInput: MergeInput<Output>) {
    mergeInput.subscribe(self)
  }
}
