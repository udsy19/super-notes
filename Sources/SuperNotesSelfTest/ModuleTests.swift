// Each module owns Sources/SuperNotesSelfTest/<Module>Tests.swift and its register function.
func registerModuleTests() {
    registerStorageKitTests()
    registerNoteEngineTests()
    registerExtensionsKitTests()
    registerEditorKitTests()
    registerShellKitTests()
    registerToolsKitTests()
    registerSettingsParityTests()
    registerMenusParityTests()
    registerToolsParityTests()
    registerChromeParityTests()
    registerEditorParityTests()
    registerSettingsBehaviourTests()
    registerFindShelfTests()
    #if !APP_STORE
    registerUpdateKitTests()
    #endif
    registerUndoTests()
    registerSlotsTests()
    registerAIKitTests()
    registerReliabilityTests()
}
