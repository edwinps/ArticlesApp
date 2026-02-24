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
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < schemaVersion {
                    // Example to migration
//                    migration.enumerateObjects(ofType: RealmArticle.className()) { oldObject, newObject in
                        // newObject?["updatedAt"] = Date()
//                    }
                }
            }
        )
        Realm.Configuration.defaultConfiguration = config
    }
}
