//
//  KotobaMigrationPlan.swift
//  DataKit
//
//  Created by Ahmad Zaky W on 22/05/25.
//

import Foundation
import SwiftData

enum KotobaSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [KotobaDataModel.self]
    }
}

enum KotobaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [KotobaSchemaV1.self]
    }
    
    static var stages: [MigrationStage] {
        []
    }
    
    // MARK: migrations stages
    
    
}
