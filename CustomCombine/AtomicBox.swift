//
//  AtomicBox.swift
//  CustomCombine
//
//  Created by Mars on 2019/11/16.
//  Copyright © 2019 Mars. All rights reserved.
//

import Foundation

@propertyWrapper
public class Atomic<T> {
  var boxed: AtomicBox<T>
  
  init(content: T) { self.boxed = AtomicBox<T>(content) }
  
  public var wrappedValue: T {
    get {
      return boxed.value
    }
  }
  
  public var projectedValue: AtomicBox<T> {
    get {
      return boxed
    }
  }
}

public final class AtomicBox<T> {
  @usableFromInline var mutex = os_unfair_lock()
  @usableFromInline var unboxed: T
  
  public init(_ unboxed: T) {
    self.unboxed = unboxed
  }
  
  @inlinable public var value: T {
    get {
      os_unfair_lock_lock(&mutex)
      defer { os_unfair_lock_unlock(&mutex) }
      
      return unboxed
    }
  }
  
  @discardableResult @inlinable
  public func mutate<U>(_ fn: (inout T) throws -> U) rethrows -> U {
    os_unfair_lock_lock(&mutex)
    defer { os_unfair_lock_unlock(&mutex) }
    
    return try fn(&unboxed)
  }
  
  /// A computed property that has conditional statement should not be
  /// marked as `@inlinable`
  public var isMutating: Bool {
    if os_unfair_lock_trylock(&mutex) {
      os_unfair_lock_unlock(&mutex)
      return false
    }
    
    return true
  }
}
