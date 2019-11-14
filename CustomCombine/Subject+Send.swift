//
//  Subject+Send.swift
//  CustomCombine
//
//  Created by Mars on 2019/11/5.
//  Copyright © 2019 Mars. All rights reserved.
//

import Combine

public extension Subject {
  func send<S: Sequence>(
    sequence: S,
    completion: Subscribers.Completion<Self.Failure>? = nil)
    where S.Element == Self.Output {
    for v in sequence {
      send(v)
    }
    
    if completion != nil {
      send(completion: completion!)
    }
  }
}
