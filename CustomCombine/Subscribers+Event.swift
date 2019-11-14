//
//  Subscribers+Event.swift
//  CustomCombine
//
//  Created by Mars on 2019/11/4.
//  Copyright © 2019 Mars. All rights reserved.
//
import Combine

public extension Subscribers {
  enum Event<Value, Failure: Error> {
    case value(Value)
    case complete(Subscribers.Completion<Failure>)
  }
}

extension Subscribers.Event: Equatable where Value: Equatable, Failure: Equatable {}

public extension Sequence {
  
  func asEvents(completion: Subscribers.Completion<Never>? = nil) -> [Subscribers.Event<Element, Never>] {
    return asEvents(failure: Never.self, completion: completion)
  }
  
  
  func asEvents<Failure>(
    failure: Failure.Type,
    completion: Subscribers.Completion<Failure>? = nil) -> [Subscribers.Event<Element, Failure>] {
    let values = map(Subscribers.Event<Element, Failure>.value)
    guard let completion = completion else { return values }
    return values + [Subscribers.Event<Element, Failure>.complete(completion)]
  }
}
