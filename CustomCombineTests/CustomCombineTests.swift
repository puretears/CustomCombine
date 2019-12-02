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
  
  func testSharedSubject() {
    let subjectA = PassthroughSubject<Int, Never>()
    let scanB = subjectA.scan(10, +)
    
    var receivedC = [Subscribers.Event<Int, Never>]()
    let sinkC = scanB.sink(event: { receivedC.append($0) })
    subjectA.send(sequence: 1...2, completion: nil)
    
    var receivedD = [Subscribers.Event<Int, Never>]()
    let sinkD = scanB.sink(event: { receivedD.append($0) })
    subjectA.send(sequence: 3...4, completion: .finished)
    
    XCTAssertEqual(receivedC, [11, 13, 16, 20].asEvents(completion: .finished))
    XCTAssertEqual(receivedD, [13, 17].asEvents(completion: .finished))
    
    sinkC.cancel()
    sinkD.cancel()
  }
  
  func testMulticastSubject() {
    let subjectA = PassthroughSubject<Int, Never>()
    let multicastB = subjectA.scan(10, +).multicast { PassthroughSubject() }.autoconnect()
    
    var receivedC = [Subscribers.Event<Int, Never>]()
    let sinkC = multicastB.sink(event: { receivedC.append($0) })
    subjectA.send(sequence: 1...2, completion: nil)
    
    var receivedD = [Subscribers.Event<Int, Never>]()
    let sinkD = multicastB.sink(event: { receivedD.append($0) })
    subjectA.send(sequence: 3...4, completion: .finished)
    
    XCTAssertEqual(receivedC, [11, 13, 16, 20].asEvents(completion: .finished))
    XCTAssertEqual(receivedD, [16, 20].asEvents(completion: .finished))
    
    sinkC.cancel()
    sinkD.cancel()
  }
  
  func testMulticastLatest() {
    let subjectA = PassthroughSubject<Int, Never>()
    let multicastB = subjectA.scan(10, +)
      .multicast { CurrentValueSubject(0) }
      .autoconnect()
    
    var receivedC = [Subscribers.Event<Int, Never>]()
    let sinkC = multicastB.sink(event: { receivedC.append($0) })
    subjectA.send(sequence: 1...2, completion: nil)
    
    var receivedD = [Subscribers.Event<Int, Never>]()
    let sinkD = multicastB.sink(event: { receivedD.append($0) })
    subjectA.send(sequence: 3...4, completion: .finished)
    
    XCTAssertEqual(receivedC, [0, 11, 13, 16, 20].asEvents(completion: .finished))
    XCTAssertEqual(receivedD, [13, 16, 20].asEvents(completion: .finished))
    
    sinkC.cancel()
    sinkD.cancel()
  }
  
  func testMulticastBuffer() {
    let subjectA = PassthroughSubject<Int, Never>()
    let multicastB = subjectA.scan(10, +)
      .multicast { BufferSubject(limit: Int.max) }
      .autoconnect()
    
    var receivedC = [Subscribers.Event<Int, Never>]()
    let sinkC = multicastB.sink(event: { receivedC.append($0) })
    subjectA.send(sequence: 1...2, completion: nil)
    
    var receivedD = [Subscribers.Event<Int, Never>]()
    let sinkD = multicastB.sink(event: { receivedD.append($0) })
    subjectA.send(sequence: 3...4, completion: .finished)
    
    XCTAssertEqual(receivedC, [11, 13, 16, 20].asEvents(completion: .finished))
    XCTAssertEqual(receivedD, [11, 13, 16, 20].asEvents(completion: .finished))
    
    sinkC.cancel()
    sinkD.cancel()
  }
  
  func testAnyCancellable() {
    let subject = PassthroughSubject<Int, Never>()
    var received = [Subscribers.Event<Int, Never>]()
    
    weak var weakCancellable: AnyCancellable?
    
    do {
      let anyCancellable = subject.sink(event: { received.append($0) })
      weakCancellable = anyCancellable
      
      subject.send(1)
    }
    
    XCTAssertNil(weakCancellable)
    
    subject.send(2)
    XCTAssertEqual(received, [1].asEvents(completion: nil))
  }
  
  func testSinkCancellation() {
    let subject = PassthroughSubject<Int, Never>()
    var received = [Subscribers.Event<Int, Never>]()
    
    weak var weakSink: Subscribers.Sink<Int, Never>?
    
    do {
      let sink = Subscribers.Sink<Int, Never>(
        receiveCompletion: { received.append(.complete($0))},
        receiveValue: { received.append(.value($0))})
      
      weakSink = sink
      subject.subscribe(sink)
      
      subject.send(1)
    }
    
    XCTAssertNotNil(weakSink)
    
    subject.send(2)
    weakSink?.cancel()
    subject.send(3)
    
    XCTAssertEqual(received, [1, 2].asEvents(completion: nil))
  }
  
  func testOwnership() {
    var received = [Subscribers.Event<Int, Never>]()
    
    weak var weakSubject: PassthroughSubject<Int, Never>?
    weak var weakSink: Subscribers.Sink<Int, Never>?
    
    do {
      let subject = PassthroughSubject<Int, Never>()
      weakSubject = subject
      
      let sink = Subscribers.Sink<Int, Never>(
        receiveCompletion: { received.append(.complete($0))},
        receiveValue: { received.append(.value($0))})
      weakSink = sink
      
      subject.subscribe(sink)
    }
    
    XCTAssertNotNil(weakSubject)
    XCTAssertNotNil(weakSink)
    
    weakSubject?.send(1)
    weakSubject?.send(completion: .finished)
    
    XCTAssertNil(weakSubject)
    XCTAssertNil(weakSink)
    
    XCTAssertEqual(received, [1].asEvents(completion: .finished))
  }
  
  func testMultipleSubscribe() {
    let subject1 = PassthroughSubject<Int, Never>()
    let subject2 = PassthroughSubject<Int, Never>()
    var received = [Subscribers.Event<Int, Never>]()
    
    let sink = Subscribers.Sink<Int, Never>(receiveCompletion: {
      received.append(.complete($0))
    }, receiveValue: {
      received.append(.value($0))
    })
    
    subject1.subscribe(sink)
    subject2.subscribe(sink)
    
    subject1.send(sequence: 1...2, completion: .finished)
    subject2.send(sequence: 3...4, completion: .finished)
    
    XCTAssertEqual(received, (1...2).asEvents(completion: .finished))
  }
  
  func testMultipleSubjectSubscribe() {
    let subject1 = PassthroughSubject<Int, Never>()
    let subject2 = PassthroughSubject<Int, Never>()
    let multiSubject = PassthroughSubject<Int, Never>()
    
    let cancellable1 = subject1.subscribe(multiSubject)
    let cancellable2 = subject2.subscribe(multiSubject)
    
    var received = [Subscribers.Event<Int, Never>]()
    
    let sink = multiSubject.sink(receiveCompletion: {
      received.append(.complete($0))
    }, receiveValue: {
      received.append(.value($0))
    })
    
    subject1.send(sequence: 1...2, completion: nil)
    subject2.send(sequence: 3...4, completion: .finished)
    
    XCTAssertEqual(received, [1, 2, 3, 4].asEvents(completion: .finished))
    
    cancellable1.cancel()
    cancellable2.cancel()
    sink.cancel()
  }
  
  func testMergeInput() {
    let subject1 = PassthroughSubject<Int, Never>()
    let subject2 = PassthroughSubject<Int, Never>()
    let input = MergeInput<Int>()
    
    subject1.merge(into: input)
    subject2.merge(into: input)
    
    var received = [Subscribers.Event<Int, Never>]()
    
    let sink = input.sink(receiveCompletion: {
      received.append(.complete($0))
    }, receiveValue: {
      received.append(.value($0))
    })
    
    subject1.send(sequence: 1...2, completion: .finished)
    subject2.send(sequence: 3...4, completion: .finished)
    
    XCTAssertEqual(received, [1, 2, 3, 4].asEvents(completion: nil))
    
    sink.cancel()
  }
  
  func testSinkReactivation() {
    var received = [Subscribers.Event<Int, Never>]()
    let sink = Subscribers.Sink<Int, Never>(receiveCompletion: {
      received.append(.complete($0))
    }, receiveValue: {
      received.append(.value($0))
    })
    
    weak var weakSubject: PassthroughSubject<Int, Never>?
    
    do {
      let subject = PassthroughSubject<Int, Never>()
      weakSubject = subject
      subject.subscribe(sink)
      
      subject.send(1)
    }
    
    XCTAssertNotNil(weakSubject)
    
    weakSubject?.send(completion: .finished)
    XCTAssertNil(weakSubject)
    XCTAssertEqual(received, [1].asEvents(completion: .finished))
    
    let subject2 = PassthroughSubject<Int, Never>()
    subject2.subscribe(sink)
    subject2.send(2)
    
    XCTAssertEqual(received, [1].asEvents(completion: .finished))
  }
  
  func testDemand() {
    var received = [Subscribers.Event<Int, Never>]()
    let subject = PassthroughSubject<Int, Never>()
    let sink = CustomDemandSink<Int, Never>(
      demand: 2,
      receiveValue: { received.append(.value($0)) },
      receiveCompletion: { received.append(.complete($0)) }
    )
    
    subject.subscribe(sink)
    
    subject.send(sequence: 1...3, completion: nil)
    sink.increaseDemand(2)
    subject.send(sequence: 4...6, completion: .finished)
    sink.increaseDemand(2)
    
    XCTAssertEqual(received, [1, 2, 4, 5].asEvents(completion: .finished))
  }
  
  func testReceiveOnImmediate() {
    let e = expectation(description: "")
    let subject = PassthroughSubject<Int, Never>()
    var received = [Subscribers.Event<Int, Never>]()
    print(Thread.current)
    let sink = subject.receive(on: ImmediateScheduler.shared)
      .sink(receiveCompletion: {
        print(Thread.current)
        received.append(.complete($0))
        e.fulfill()
      }, receiveValue: {
        received.append(.value($0))
      })
    
    subject.send(1)
    subject.send(completion: .finished)
    
    wait(for: [e], timeout: 5.0)
    
    XCTAssertEqual(received, [1].asEvents(completion: .finished))
    
    sink.cancel()
  }
  
  func testReceiveOnFailure() {
    let queue = DispatchQueue(label: "test")
    let e = expectation(description: "")
    let subject = PassthroughSubject<Int, Never>()
    var received = [Subscribers.Event<Int, Never>]()
    print(Thread.current)
    let sink = subject.receive(on: queue)
      .sink(receiveCompletion: {
        print(Thread.current)
        received.append(.complete($0))
        e.fulfill()
      }, receiveValue: {
        received.append(.value($0))
      })
    
    subject.send(1)
    queue.async { subject.send(completion: .finished) }
    
    wait(for: [e], timeout: 5.0)
    
    XCTAssertEqual(received, [].asEvents(completion: .finished))
    
    sink.cancel()
  }
  
  func testReceiveWithDebug() {
    let subject = PassthroughSubject<Int, Never>()
    var received = [Subscribers.Event<Int, Never>]()
    
    print("Start...")
    let cancellable = subject
      .debug()
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { received.append(.value($0)) })
    
    print("Phase 1...")
    subject.send(1)
    XCTAssertEqual(received, [].asEvents(completion: nil))
    
    print("Phase 2...")
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.001))
    XCTAssertEqual(received, [].asEvents(completion: nil))
    
    print("Phase 3...")
    subject.send(2)
    XCTAssertEqual(received, [].asEvents(completion: nil))
    
    print("Phase 4...")
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.001))
    XCTAssertEqual(received, [2].asEvents(completion: nil))
    
    cancellable.cancel()
  }
  
  func testBufferedReceiveOn() {
    let subject = PassthroughSubject<Int, Never>()
    let e = expectation(description: "")
    var received = [Subscribers.Event<Int, Never>]()
    
    let cancellable = subject
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropNewest)
      .receive(on: DispatchQueue(label: "test"))
      .sink(receiveCompletion: {
        received.append(.complete($0))
        e.fulfill()
      }, receiveValue: {
        received.append(.value($0))
      })
    
    subject.send(1)
    subject.send(completion: .finished)
    
    wait(for: [e], timeout: 5.0)
    XCTAssertEqual(received, [1].asEvents(completion: .finished))
    
    cancellable.cancel()
  }
}
