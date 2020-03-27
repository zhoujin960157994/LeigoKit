//
//  fnv1.swift
//  NEKit
//
//  Created by wfei on 2020/2/9.
//  Copyright © 2020 Zhuhao Wang. All rights reserved.
//

import Foundation

public struct FVN1AHash {
    static func sum(data: Data) -> UInt32 {
        var hash: UInt32 = 2166136261
        let prime: UInt32 = 16777619
        
        for (_, byte) in data.enumerated() {
            hash = (hash ^ UInt32(byte)) &* prime
        }
        
        return hash
    }
}
