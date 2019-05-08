//
//  ScheduleArchivingTests.swift
//  BridgeAppTests
//
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import XCTest
@testable import BridgeApp
@testable import Research

class ScheduleArchivingTests: SBAScheduleManagerTests {
    
    override func setUp() {
        super.setUp()
        
        SBABridgeConfiguration.shared.addMapping(with: mainTaskSchemaIdentifier, to: .timestamp)
        SBABridgeConfiguration.shared.addMapping(with: insertTaskSchemaIdentifier, to: .groupByDay)
        SBABridgeConfiguration.shared.addMapping(with: insertSurveySchemaIdentifier, to: .singleton)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testScheduledActivity_CompoundTask_InsertedTask() {
        let taskPath = runCompoundTask()
        guard let subtaskPath = taskPath.childPaths[insertTaskIdentifier] else {
            XCTFail("Failed to build the expected child paths.")
            return
        }
        
        // Create an associated schedule for the inserted task and the top level task
        let schedules = self.createSchedules(identifiers: [mainTaskIdentifier, insertTaskIdentifier],
                                             clientData: nil)
        guard let expectedSchedule = schedules[insertTaskIdentifier] else {
            XCTFail("Failed to build the expected schedules.")
            return
        }
        
        // The subtask will be run without a linked schedule identifier.
        let schedule = self.scheduleManager.scheduledActivity(for: subtaskPath.taskResult, scheduleIdentifier: nil)
        
        XCTAssertNotNil(schedule)
        XCTAssertEqual(schedule, expectedSchedule)
    }
    
    func testDataArchiver_CompoundTask_WithSchedules() {
        let taskPath = runCompoundTask()
        
        // Create an associated schedule for the inserted task and the top level task
        let schedules = self.createSchedules(identifiers: [mainTaskIdentifier, insertTaskIdentifier],
                                             clientData: nil)

        let topResult = taskPath.taskResult
        guard let archive = self.scheduleManager.dataArchiver(for: topResult,
                                                        scheduleIdentifier: schedules[mainTaskIdentifier]?.guid,
                                                        currentArchive: nil) as? SBAScheduledActivityArchive
            else {
                XCTFail("Failed to instantiate a top-level archive.")
                return
        }
        XCTAssertEqual(archive.schemaInfo.schemaIdentifier, mainTaskSchemaIdentifier)
        XCTAssertEqual(archive.schedule, schedules[mainTaskIdentifier])
        
        if let sectionPath = taskPath.childPaths["step2"] {
            let childArchive = self.scheduleManager.dataArchiver(for: sectionPath.taskResult,
                                                                 scheduleIdentifier: nil,
                                                                 currentArchive: archive)
            XCTAssertTrue(archive === childArchive, "Child archive did not return non-unique parent archive.")
        }
        else {
            XCTFail("Fails assumption. Could not retrieve child task path.")
        }
        
        if let subtaskPath = taskPath.childPaths[insertTaskIdentifier] {
            let childArchive = self.scheduleManager.dataArchiver(for: subtaskPath.taskResult,
                                                                 scheduleIdentifier: nil,
                                                                 currentArchive: archive)
            XCTAssertFalse(archive === childArchive, "Child archive for a subtask did not return new archive.")
            if let insertArchive = childArchive as? SBAScheduledActivityArchive {
                XCTAssertEqual(insertArchive.schemaInfo.schemaIdentifier, insertTaskSchemaIdentifier)
                XCTAssertEqual(insertArchive.schedule, schedules[insertTaskIdentifier])
            }
            else {
                XCTFail("Child archive not of expected type.")
            }
        }
        else {
            XCTFail("Fails assumption. Could not retrieve child task path.")
        }
    }
    
    func testDataArchiver_CompoundTask_NoSchedules() {
        let taskPath = runCompoundTask()
        
        let topResult = taskPath.taskResult
        guard let archive = self.scheduleManager.dataArchiver(for: topResult,
                                                              scheduleIdentifier: nil,
                                                              currentArchive: nil) as? SBAScheduledActivityArchive
            else {
                XCTFail("Failed to instantiate a top-level archive.")
                return
        }
        XCTAssertEqual(archive.schemaInfo.schemaIdentifier, mainTaskSchemaIdentifier)
        
        if let sectionPath = taskPath.childPaths["step2"] {
            let childArchive = self.scheduleManager.dataArchiver(for: sectionPath.taskResult,
                                                                 scheduleIdentifier: nil,
                                                                 currentArchive: archive)
            XCTAssertTrue(archive === childArchive, "Child archive did not return non-unique parent archive.")
        }
        else {
            XCTFail("Fails assumption. Could not retrieve child task path.")
        }
        
        if let subtaskPath = taskPath.childPaths[insertTaskIdentifier] {
            let childArchive = self.scheduleManager.dataArchiver(for: subtaskPath.taskResult,
                                                                 scheduleIdentifier: nil,
                                                                 currentArchive: archive)
            XCTAssertFalse(archive === childArchive, "Child archive for a subtask did not return new archive.")
            if let insertArchive = childArchive as? SBAScheduledActivityArchive {
                XCTAssertEqual(insertArchive.schemaInfo.schemaIdentifier, insertTaskSchemaIdentifier)
            }
            else {
                XCTFail("Child archive not of expected type.")
            }
        }
        else {
            XCTFail("Fails assumption. Could not retrieve child task path.")
        }
    }
    
    func testBuildClientData_CompoundTask() {

        let taskPath = runCompoundTask()
        guard let subtaskPath = taskPath.childPaths[insertTaskIdentifier],
            let surveyPath = taskPath.childPaths[insertSurveyIdentifier]
            else {
                XCTFail("Fails assumption. Could not retrieve child task path.")
                return
        }

        let topClientData = self.scheduleManager.buildClientData(from: taskPath.taskResult)
        XCTAssertNotNil(topClientData)
        if let dictionary = topClientData as? NSDictionary {
            XCTAssertEqual(dictionary["introduction"] as? String, "introduction moo")
            XCTAssertEqual(dictionary["step1"] as? String, "step1 moo")
            let expectedDictionary : NSDictionary = [ "stepX" : "stepX moo",
                                                          "stepY" : "stepY moo"]
            XCTAssertEqual(dictionary["step2"] as? NSDictionary, expectedDictionary)
            XCTAssertEqual(dictionary["step3"] as? NSDictionary, expectedDictionary)
        }
        else {
            XCTFail("\(String(describing: topClientData)) is not a Dictionary.")
        }
        
        let insertedClientData = self.scheduleManager.buildClientData(from: subtaskPath.taskResult)
        XCTAssertNotNil(insertedClientData)
        if let stringValue = insertedClientData as? String {
            XCTAssertEqual(stringValue, "insertStep moo")
        }
        else {
            XCTFail("\(String(describing: insertedClientData)) is not a String.")
        }
        
        let surveyClientData = self.scheduleManager.buildClientData(from: surveyPath.taskResult)
        XCTAssertNotNil(surveyClientData)
        if let dictionary = surveyClientData as? NSDictionary {
            let expectedDictionary : NSDictionary = [
                "stepA" : 0,
                "stepB" : 1,
                "stepC" : 2
            ]
            XCTAssertEqual(dictionary, expectedDictionary)
        }
        else {
            XCTFail("\(String(describing: insertedClientData)) is not a String.")
        }
    }
    
    func testBuildReports_CompoundTask() {
        let taskPath = runCompoundTask()
        let topResult = taskPath.taskResult
        guard let reports = self.scheduleManager.buildReports(from: taskPath.taskResult)
            else {
                XCTFail("Failed to build the reports for this task result")
                return
        }

        XCTAssertEqual(reports.count, 3)
        
        if let report = reports.first(where: { $0.reportKey == mainTaskIdentifier }) {
            XCTAssertEqual(report.date, topResult.endDate)
            if let dictionary = report.clientData as? NSDictionary {
                XCTAssertEqual(dictionary["introduction"] as? String, "introduction moo")
                XCTAssertEqual(dictionary["step1"] as? String, "step1 moo")
                let expectedDictionary : NSDictionary = [ "stepX" : "stepX moo",
                                                              "stepY" : "stepY moo"]
                XCTAssertEqual(dictionary["step2"] as? NSDictionary, expectedDictionary)
                XCTAssertEqual(dictionary["step3"] as? NSDictionary, expectedDictionary)
            }
            else {
                XCTFail("\(String(describing: report.clientData)) is not a Dictionary.")
            }
        }
        else {
            XCTFail("Failed to build the report")
        }
        
        if let report = reports.first(where: { $0.reportKey == insertSurveySchemaIdentifier }) {
            XCTAssertEqual(report.date, SBAReportSingletonDate)
            if let dictionary = report.clientData as? NSDictionary {
                let expectedDictionary : NSDictionary = [
                    "stepA" : 0,
                    "stepB" : 1,
                    "stepC" : 2
                ]
                XCTAssertEqual(dictionary as NSDictionary, expectedDictionary)
            }
            else {
                XCTFail("\(String(describing: report.clientData)) is not a Dictionary.")
            }
        }
        else {
            XCTFail("Failed to build the report")
        }
        
        if let report = reports.first(where: { $0.reportKey == insertTaskSchemaIdentifier }) {
            XCTAssertEqual(report.date, self.scheduleManager.nowValue.startOfDay())
            if let stringValue = report.clientData as? String {
                XCTAssertEqual(stringValue, "insertStep moo")
            }
            else {
                XCTFail("\(String(describing: report.clientData)) is not a String.")
            }
        }
        else {
            XCTFail("Failed to build the report")
        }
    }
    
    func testBuildReports_TempTask() {
        let taskPath = runTempTask()
        let mainResult = taskPath.taskResult.findResult(with: mainTaskIdentifier)
        guard let reports = self.scheduleManager.buildReports(from: taskPath.taskResult)
            else {
                XCTFail("Failed to build the reports for this task result")
                return
        }
        
        XCTAssertEqual(reports.count, 3)
        
        if let report = reports.first(where: { $0.reportKey == mainTaskIdentifier }) {
            XCTAssertEqual(report.date, mainResult?.endDate)
            if let dictionary = report.clientData as? NSDictionary {
                let expectedDictionary : NSDictionary = [
                    "introduction" : "introduction moo",
                    "step1": "step1 moo",
                    "step2": [ "stepX" : "stepX moo",
                               "stepY" : "stepY moo"],
                    "step3": [ "stepX" : "stepX moo",
                               "stepY" : "stepY moo"]
                ]
                XCTAssertEqual(dictionary as NSDictionary, expectedDictionary)
            }
            else {
                XCTFail("\(String(describing: report.clientData)) is not a Dictionary.")
            }
        }
        else {
            XCTFail("Failed to build the report")
        }
        
        if let report = reports.first(where: { $0.reportKey == insertSurveySchemaIdentifier }) {
            XCTAssertEqual(report.date, SBAReportSingletonDate)
            if let dictionary = report.clientData as? NSDictionary {
                let expectedDictionary : NSDictionary = [
                    "stepA" : 0,
                    "stepB" : 1,
                    "stepC" : 2
                ]
                XCTAssertEqual(dictionary as NSDictionary, expectedDictionary)
            }
            else {
                XCTFail("\(String(describing: report.clientData)) is not a Dictionary.")
            }
        }
        else {
            XCTFail("Failed to build the report")
        }
        
        if let report = reports.first(where: { $0.reportKey == insertTaskSchemaIdentifier }) {
            XCTAssertEqual(report.date, self.scheduleManager.nowValue.startOfDay())
            if let stringValue = report.clientData as? String {
                XCTAssertEqual(stringValue, "insertStep moo")
            }
            else {
                XCTFail("\(String(describing: report.clientData)) is not a String.")
            }
        }
        else {
            XCTFail("Failed to build the report")
        }
    }
    
    func testBuildReports_CollectionTask() {
        let taskPath = runCollectionTask()
        guard let reports = self.scheduleManager.buildReports(from: taskPath.taskResult)
            else {
                XCTFail("Failed to build the reports for this task result")
                return
        }
        
        XCTAssertEqual(reports.count, 1)
        
        if let report = reports.first(where: { $0.reportKey == mainTaskIdentifier }) {
            if let dictionary = report.clientData as? NSDictionary {
                let expectedDictionary : NSDictionary = [
                    "step2" : [
                        "stepX" : ["identifier" : "stepX", "boolean" : true],
                        "stepY" : ["identifier" : "stepY", "boolean" : true]
                    ],
                    "step3" : [
                        "stepX" : ["identifier" : "stepX", "boolean" : true],
                        "stepY" : ["identifier" : "stepY", "boolean" : true]
                    ],
                    "foo" : 3,
                    "baroo" : 5
                ]
                XCTAssertEqual(dictionary as NSDictionary, expectedDictionary)
            }
            else {
                XCTFail("\(String(describing: report.clientData)) is not a Dictionary.")
            }
        }
        else {
            XCTFail("Failed to build the report")
        }

    }
    
    func testUpdateSchedules() {
        // Before calling the readyToSave method of the task controller, the task path is copied. The copy
        // does not include pointers to objects that are used to run the task and **only** includes properties
        // used to archive the task result.
        let taskPath = runCompoundTask()
        let schedules = self.createSchedules(identifiers: [mainTaskIdentifier, insertTaskIdentifier],
                                             clientData: nil)
        guard let topSchedule = schedules[mainTaskIdentifier],
            let subtaskSchedule = schedules[insertTaskIdentifier] else {
                XCTFail("Fails assumption. Did not create expected schedules.")
                return
        }
        
        self.scheduleManager.updateSchedules(for: taskPath)
        
        XCTAssertNotNil(self.scheduleManager.sendUpdated_schedules)
        if let updatedSchedules = self.scheduleManager.sendUpdated_schedules {
            let resultSet = Set(updatedSchedules)
            let expectedSchedules = Set([topSchedule, subtaskSchedule])
            XCTAssertEqual(resultSet, expectedSchedules)
        }
        
        XCTAssertEqual(taskPath, self.scheduleManager.sendUpdated_taskPath)
        
        XCTAssertNotNil(topSchedule.finishedOn)
        XCTAssertNotNil(topSchedule.startedOn)
        
        XCTAssertNotNil(subtaskSchedule.finishedOn)
        XCTAssertNotNil(subtaskSchedule.startedOn)
    }
    
    
    // MARK: Helper methods
    
    let insertTaskIdentifier = "insertTask"
    let insertTaskSchemaIdentifier = "schemaA"
    let insertTaskSchemaRevision = 3
    
    let mainTaskIdentifier = "test"
    let mainTaskSchemaIdentifier = "test"
    let mainTaskSchemaRevision = 2
    
    let insertSurveyIdentifier = "insertSurvey"
    let insertSurveySchemaIdentifier = "schemaB"
    let insertSurveySchemaRevision = 5
    
    let tempTaskIdentifier = "tempTask"
    
    func runTempTask() -> RSDTaskViewModel {
        
        // Create a task to be inserted into the parent task.
        let insertStep = convert([TestStep(identifier: "insertStep")]).first!
        var insertTask = TestTask(identifier: insertTaskIdentifier, stepNavigator: TestConditionalNavigator(steps: [insertStep]))
        insertTask.schemaInfo = RSDSchemaInfoObject(identifier: insertTaskSchemaIdentifier, revision: insertTaskSchemaRevision)
        
        // Create a task to be inserted into the parent task.
        var insertSurvey = TestTask(identifier: insertSurveyIdentifier, stepNavigator: TestConditionalNavigator(steps: convertWithIndex(TestStep.steps(from: ["stepA", "stepB", "stepC"]))))
        insertSurvey.schemaInfo = RSDSchemaInfoObject(identifier: insertSurveySchemaIdentifier, revision: insertSurveySchemaRevision)
        
        var steps: [RSDStep] = []
        steps.append(contentsOf: convert(TestStep.steps(from: ["introduction", "step1"])))
        steps.append(RSDSectionStepObject(identifier: "step2", steps: convert(TestStep.steps(from: ["stepX", "stepY"]))))
        steps.append(RSDSectionStepObject(identifier: "step3", steps: convert(TestStep.steps(from: ["stepX", "stepY"]))))
        
        var mainTask = TestTask(identifier: mainTaskIdentifier, stepNavigator: TestConditionalNavigator(steps: steps))
        mainTask.schemaInfo = RSDSchemaInfoObject(identifier: mainTaskSchemaIdentifier, revision: mainTaskSchemaRevision)
        
        let taskSteps: [RSDStep] = [TestSubtaskStep(task: insertTask),
                                    TestSubtaskStep(task: mainTask),
                                    TestSubtaskStep(task: insertSurvey),
                                    RSDUIStepObject(identifier: "completion")
        ]
        let task = TestTask(identifier: tempTaskIdentifier, stepNavigator: TestConditionalNavigator(steps: taskSteps))
        
        let taskController = TestTaskController()
        taskController.task = task
        let _ = taskController.test_stepTo("completion")
        
        return taskController.taskViewModel!
    }
    
    func runCompoundTask() -> RSDTaskViewModel {
        
        // Create a task to be inserted into the parent task.
        let insertStep = convert([TestStep(identifier: "insertStep")]).first!
        var insertTask = TestTask(identifier: insertTaskIdentifier, stepNavigator: TestConditionalNavigator(steps: [insertStep]))
        insertTask.schemaInfo = RSDSchemaInfoObject(identifier: insertTaskSchemaIdentifier, revision: insertTaskSchemaRevision)
        
        // Create a task to be inserted into the parent task.
        var insertSurvey = TestTask(identifier: insertSurveyIdentifier, stepNavigator: TestConditionalNavigator(steps: convertWithIndex(TestStep.steps(from: ["stepA", "stepB", "stepC"]))))
        insertSurvey.schemaInfo = RSDSchemaInfoObject(identifier: insertSurveySchemaIdentifier, revision: insertSurveySchemaRevision)

        var steps: [RSDStep] = []
        steps.append(TestSubtaskStep(task: insertTask))
        steps.append(TestSubtaskStep(task: insertSurvey))
        steps.append(contentsOf: convert(TestStep.steps(from: ["introduction", "step1"])))
        steps.append(RSDSectionStepObject(identifier: "step2", steps: convert(TestStep.steps(from: ["stepX", "stepY"]))))
        steps.append(RSDSectionStepObject(identifier: "step3", steps: convert(TestStep.steps(from: ["stepX", "stepY"]))))
        steps.append(RSDUIStepObject(identifier: "completion"))
        
        var task = TestTask(identifier: mainTaskIdentifier, stepNavigator: TestConditionalNavigator(steps: steps))
        task.schemaInfo = RSDSchemaInfoObject(identifier: mainTaskSchemaIdentifier, revision: mainTaskSchemaRevision)
        
        let taskController = TestTaskController()
        taskController.task = task
        let _ = taskController.test_stepTo("completion")
        
        return taskController.taskViewModel!
    }
    
    func runCollectionTask() -> RSDTaskViewModel {
        
        var steps: [RSDStep] = []
        steps.append(contentsOf: convertForInstruction(TestStep.steps(from: ["introduction", "step1"])))
        steps.append(RSDSectionStepObject(identifier: "step2", steps: convertForCollection(TestStep.steps(from: ["stepX", "stepY"]))))
        steps.append(RSDSectionStepObject(identifier: "step3", steps: convertForCollection(TestStep.steps(from: ["stepX", "stepY"]))))
        steps.append(contentsOf: convertForQuestion(TestStep.steps(from: ["foo", "baroo"])))
        steps.append(RSDUIStepObject(identifier: "completion"))
        
        var task = TestTask(identifier: mainTaskIdentifier, stepNavigator: TestConditionalNavigator(steps: steps))
        task.schemaInfo = RSDSchemaInfoObject(identifier: mainTaskSchemaIdentifier, revision: mainTaskSchemaRevision)
        
        let taskController = TestTaskController()
        taskController.task = task
        let _ = taskController.test_stepTo("completion")
        
        return taskController.taskViewModel!
    }
    
    func convert(_ steps: [TestStep]) -> [TestStep] {
        return steps.map { (inStep) -> TestStep in
            var step = inStep
            step.result = TestClientDataResult(identifier: step.identifier, startDate: Date(), endDate: Date())
            return step
        }
    }
    
    func convertWithIndex(_ steps: [TestStep]) -> [TestStep] {
        return steps.enumerated().map {
            var step = $1
            step.result = RSDAnswerResultObject(identifier: step.identifier, answerType: .integer, value: $0)
            return step
        }
    }
    
    func convertForInstruction(_ steps: [TestStep]) -> [TestStep] {
        return steps.map { (inStep) -> TestStep in
            var step = inStep
            step.result = RSDResultObject(identifier: step.identifier)
            return step
        }
    }
    
    func convertForCollection(_ steps: [TestStep]) -> [TestStep] {
        return steps.map { (inStep) -> TestStep in
            var step = inStep
            var collectionResult = RSDCollectionResultObject(identifier: step.identifier)
            collectionResult.appendInputResults(with: RSDAnswerResultObject(identifier: "identifier", answerType: .string, value: step.identifier))
            collectionResult.appendInputResults(with: RSDAnswerResultObject(identifier: "boolean", answerType: .boolean, value: true))
            step.result = collectionResult
            return step
        }
    }
    
    func convertForQuestion(_ steps: [TestStep]) -> [TestStep] {
        return steps.map { (inStep) -> TestStep in
            var step = inStep
            var collectionResult = RSDCollectionResultObject(identifier: step.identifier)
            collectionResult.appendInputResults(with: RSDAnswerResultObject(identifier: step.identifier, answerType: .integer, value: step.identifier.count))
            step.result = collectionResult
            return step
        }
    }
}

struct TestClientDataResult : RSDScoringResult {
    private enum CodingKeys: String, CodingKey {
        case identifier, type, startDate, endDate
    }
    
    let identifier: String
    
    let type: RSDResultType = RSDResultType(rawValue: "testClientData")
    var startDate: Date = Date()
    var endDate: Date = Date()
    
    func dataScore() throws -> RSDJSONSerializable? {
        return "\(identifier) moo"
    }
    
    func buildArchiveData(at stepPath: String?) throws -> (manifest: RSDFileManifest, data: Data)? {
        // archive isn't tested using this mock.
        fatalError("Archiving is not implemented for this test object")
    }
}
