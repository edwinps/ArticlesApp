//
//  RealmConfiguration.swift
//  ArticlesApp
//
//

import Foundation
import RealmSwift

enum RealmConfiguration {
    static let schemaVersion: UInt64 = 1

    static func configure() {
        let config = Realm.Configuration(
            schemaVersion: schemaVersion,
            migrationBlock: { _, oldSchemaVersion in
                if oldSchemaVersion < schemaVersion {
                    // no-op for now
                }
            }
        )
        Realm.Configuration.defaultConfiguration = config
    }
}
