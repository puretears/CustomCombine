//
//  CustomCombineTests.swift
//  CustomCombineTests
//
//  Created by Mars on 2019/11/4.
//  Copyright © 2019 Mars. All rights reserved.
//

import XCTest
import Combine
@testable import CustomCombine

class CustomCombineTests: XCTestCase {
  override func setUp() {
  }

  override func tearDown() {
  }
  
  func testSubjectSink() {
    let subject = PassthroughSubject<Int, Never>()
    var received = [Subscribers.Event<Int, Never>]()
    let sink = Subscribers.Sink<Int, Never>(
      receiveCompletion: {
        received.append(.complete($0))
      },
      receiveValue: {
        received.append(.value($0))
      })
    
    subject.subscribe(sink)
    subject.send(sequence: 1...3, completion: .finished)
    
    XCTAssertEqual(received, (1...3).asEvents(completion: .finished))
  }
  
  func testScan() {
    let subjectA = PassthroughSubject<Int, Never>()
    let scanB = Publishers.Scan(upstream: subjectA, initialResult: 10, nextPartialResult: +)
    
    var received = [Subscribers.Event<Int, Never>]()
    let sink = Subscribers.Sink<Int, Never>(
      receiveCompletion: {
        received.append(.complete($0))
      },
      receiveValue: {
        received.append(.value($0))
      })
    
    scanB.subscribe(sink)
    subjectA.send(sequence: 1...3, completion: .finished)
    
    XCTAssertEqual(received, [11, 13, 16].asEvents(completion: .finished))
  }
  
  func testSequenceABCD() {
    let subjectA = PassthroughSubject<Int, Never>()
    let scanB = Publishers.Scan(upstream: subjectA, initialResult: 10, nextPartialResult: {
      $0 + $1
    })
    
    var receivedC = [Subscribers.Event<Int, Never>]()
    let sinkC = Subscribers.Sink<Int, Never>(
      receiveCompletion: {
        receivedC.append(.complete($0))
      },
      receiveValue: {
        receivedC.append(.value($0))
      })
    
    var receivedD = [Subscribers.Event<Int, Never>]()
    let sinkD = Subscribers.Sink<Int, Never>(
      receiveCompletion: {
        receivedD.append(.complete($0))
      },
      receiveValue: {
        receivedD.append(.value($0))
      })
    
    scanB.subscribe(sinkC)
    scanB.subscribe(sinkD)
    subjectA.send(sequence: 1...3, completion: .finished)
    
    XCTAssertEqual(receivedC, [11, 13, 16].asEvents(completion: .finished))
    XCTAssertEqual(receivedD, [11, 13, 16].asEvents(completion: .finished))
  }
  
  func testDeferredSubjects() {
    var subjects = [PassthroughSubject<Int, Never>]()
    let deferred = Deferred { () -> PassthroughSubject<Int, Never> in
      let request = PassthroughSubject<Int, Never>()
      subjects.append(request)
      
      return request
    }
    
    let scanB = Publishers.Scan(upstream: deferred, initialResult: 10, nextPartialResult: {
      $0 + $1
    })
    
    var receivedC = [Subscribers.Event<Int, Never>]()
    let sinkC = Subscribers.Sink<Int, Never>(
      receiveCompletion: {
        receivedC.append(.complete($0))
      },
      receiveValue: {
        receivedC.append(.value($0))
      })
    
    var receivedD = [Subscribers.Event<Int, Never>]()
    let sinkD = Subscribers.Sink<Int, Never>(
      receiveCompletion: {
        receivedD.append(.complete($0))
      },
      receiveValue: {
        receivedD.append(.value($0))
      })
    
    scanB.subscribe(sinkC)
    subjects[0].send(sequence: 1...2, completion: nil)
    
    scanB.subscribe(sinkD) /// `sinkD` does not receive events in `subjects[0]`
    subjects[0].send(sequence: 3...4, completion: .finished)
    subjects[1].send(sequence: 1...4, completion: .finished)
    
    XCTAssertEqual(receivedC, [11, 13, 16, 20].asEvents(completion: .finished))
    XCTAssertEqual(receivedD, [11, 13, 16, 20].asEvents(completion: .finished))
  }
  
  func testCustomSubjects() {
    var subjects = [CustomSubject<Int, Never>]()
    let deferred = Deferred { () -> CustomSubject<Int, Never> in
      let request = CustomSubject<Int, Never>()
      subjects.append(request)
      
      return request
    }
    
    let scanB = CustomScan(upstream: deferred, initialResult: 10, nextPartialResult: {
      $0 + $1
    })
    
    var receivedC = [Subscribers.Event<Int, Never>]()
    let sinkC = Subscribers.Sink<Int, Never>(
      receiveCompletion: {
        receivedC.append(.complete($0))
      },
      receiveValue: {
        receivedC.append(.value($0))
      })
    
    var receivedD = [Subscribers.Event<Int, Never>]()
    let sinkD = Subscribers.Sink<Int, Never>(
      receiveCompletion: {
        receivedD.append(.complete($0))
      },
      receiveValue: {
        receivedD.append(.value($0))
      })
    
    scanB.subscribe(sinkC)
    subjects[0].send(sequence: 1...2, completion: nil)
    
    scanB.subscribe(sinkD) /// `sinkD` does not receive events in `subjects[0]`
    subjects[0].send(sequence: 3...4, completion: .finished)
    subjects[1].send(sequence: 1...4, completion: .finished)
    
    XCTAssertEqual(receivedC, [11, 13, 16, 20].asEvents(completion: .finished))
    XCTAssertEqual(receivedD, [11, 13, 16, 20].asEvents(completion: .finished))
  }
}
