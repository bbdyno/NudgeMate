import SwiftData

enum NudgeMateSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            RecurringEvent.self,
            RhythmOccurrenceRecord.self,
            PatternCandidateRecord.self,
            NudgeInstanceRecord.self,
            EventPrep.self,
            PrepCheckInRecord.self,
            UserSettingsRecord.self,
            SuppressedPatternRecord.self,
            PendingIntentRecord.self
        ]
    }
}

enum NudgeMateMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [NudgeMateSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: NudgeMateSchemaV1.self)
        let configuration = ModelConfiguration(
            "NudgeMate",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: NudgeMateMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
