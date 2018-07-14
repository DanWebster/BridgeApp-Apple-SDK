//
//  SBAMedicationRemindersViewController.swift
//  mPower2
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

import UIKit

open class SBAMedicationRemindersViewController: RSDTableStepViewController {
    
    public var reminderStep: SBAMedicationRemindersStepObject? {
        return self.step as? SBAMedicationRemindersStepObject
    }
    
    override open var isForwardEnabled: Bool {
        return true
    }

    override open func registerReuseIdentifierIfNeeded(_ reuseIdentifier: String) {
        guard !_registeredIdentifiers.contains(reuseIdentifier) else { return }
        _registeredIdentifiers.insert(reuseIdentifier)
        
        let reuseId = RSDFormUIHint(rawValue: reuseIdentifier)
        switch reuseId {
        case .modalButton:
            tableView.register(SBATrackedModalButtonCell.nib, forCellReuseIdentifier: reuseIdentifier)
            break
        default:
            super.registerReuseIdentifierIfNeeded(reuseIdentifier)
            break
        }
    }
    private var _registeredIdentifiers = Set<String>()

    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // Get the cell from super and update the label with the cancatenation of our current reminder intervals
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        let labelString: String = {
            if let intervals = intervals(from: taskController.taskPath), intervals.count > 0 {
                return String(format: Localization.localizedString("MEDICATION_REMINDER_CHOICES_%@"), Localization.localizedAndJoin(intervals.compactMap { return String($0) }))
            }
            else {
                return Localization.localizedString("MEDICATION_REMINDER_CHOICES_NONE_SET")
            }
        }()
        if let modalCell = cell as? SBATrackedModalButtonCell {
            modalCell.delegate = self
            modalCell.promptLabel.text = Localization.localizedString("MEDICATION_REMINDER_ADD")
            modalCell.actionButton.setTitle(labelString, for: .normal)
        }
        return cell
    }
    
    override open func didTapButton(on cell: RSDButtonCell) {
        self.showReminderDetailsTask()
    }
    
    func intervals(from taskPath: RSDTaskPath) -> [Int]? {
        guard taskPath.result.stepHistory.count > 0,
            let collectionResult = taskPath.result.stepHistory.last as? RSDCollectionResultObject else {
                return nil
        }

        var intervalsSelected = [Int]()
        for intervalResult in collectionResult.inputResults {
            if let intervalAnswerResult = intervalResult as? RSDAnswerResultObject,
                let intervalValueArray = intervalAnswerResult.value as? [Int] {
                for intervalInt in intervalValueArray {
                    intervalsSelected.append(intervalInt)
                }
            }
        }
        return intervalsSelected
    }
    
    func showReminderDetailsTask() {

        guard let reminderChoicesStep = self.reminderStep?.reminderChoicesStep() else { return }
        
        // Instantiate and create the reminder details task
        var navigator = RSDConditionalStepNavigatorObject(with: [reminderChoicesStep])
        navigator.progressMarkers = []
        let task = RSDTaskObject(identifier: step.identifier, stepNavigator: navigator)
        let taskPath = RSDTaskPath(task: task)

        // See if we currently have any reminder intervals saved and, if so, add them to the result
        // for our new task so they are prepopulated for the user
        if let intervals = intervals(from: taskController.taskPath),
            intervals.count > 0  {
            update(taskPath: taskPath, with: intervals, for: reminderChoicesStep.identifier)
        }

        let vc = RSDTaskViewController(taskPath: taskPath)
        vc.delegate = self
        self.present(vc, animated: true, completion: nil)
    }
    
    func update(taskPath: RSDTaskPath, with intervals: [Int], for stepIdentifier: String) {
        
        var previousResult = RSDCollectionResultObject(identifier: stepIdentifier)
        var answerResult = RSDAnswerResultObject(identifier: stepIdentifier,
                                                 answerType: RSDAnswerResultType(baseType: .integer,
                                                                                 sequenceType: .array,
                                                                                 formDataType: .collection(.multipleChoice, .integer),
                                                                                 dateFormat: nil,
                                                                                 unit: nil,
                                                                                 sequenceSeparator: nil))
        answerResult.value = intervals
        previousResult.inputResults = [answerResult]
        taskPath.appendStepHistory(with: previousResult)
    }
}

extension SBAMedicationRemindersViewController: RSDTaskViewControllerDelegate {
    public func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        dismiss(animated: true, completion: nil)
    }
    
    public func taskController(_ taskController: RSDTaskController, readyToSave taskPath: RSDTaskPath) {
        if let intervals = intervals(from: taskPath) {
            // Update our current task results with the intervals selected by the user
            update(taskPath: self.taskController.taskPath, with: intervals, for: self.step.identifier)
            tableView.reloadData()
            self.answersDidChange(in: 0)
        }
    }

    public func taskController(_ taskController: RSDTaskController, asyncActionControllerFor configuration: RSDAsyncActionConfiguration) -> RSDAsyncActionController? {
        return nil
    }
}

open class SBAMedicationRemindersStepObject: RSDFormUIStepObject, RSDStepViewControllerVendor {
    
    /// Publicly accessible coding keys for the default structure for decoding items and sections.
    enum CodingKeys : String, CodingKey {
        case reminderChoices
    }
    
    public var reminderChoices: [RSDChoiceObject<Int>]?
    
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let reminderChoices = try container.decode([RSDChoiceObject<Int>].self, forKey: .reminderChoices)
        self.reminderChoices = reminderChoices
    }
    
    public required init(identifier: String, type: RSDStepType?) {
        super.init(identifier: identifier, type: type)
    }
    
    public func instantiateViewController(with taskPath: RSDTaskPath) -> (UIViewController & RSDStepController)? {
        return SBAMedicationRemindersViewController(step: self)
    }
    
    /// Returns the reminder choice step
    public func reminderChoicesStep() -> RSDStep? {
        guard let reminderChoicesUnwrapped = self.reminderChoices else { return nil }
        let identifier = String(describing: CodingKeys.reminderChoices.stringValue)
        let dataType = RSDFormDataType.collection(.multipleChoice, .integer)
        let inputField = RSDChoiceInputFieldObject(identifier: identifier, choices: reminderChoicesUnwrapped, dataType: dataType)
        let formStep = RSDFormUIStepObject(identifier: identifier, inputFields: [inputField])
        let formTitle = String(format: Localization.localizedString("MEDICATION_REMINDER_CHOICES_TITLE"))
        formStep.title = formTitle
        formStep.actions = [.navigation(.goForward) : RSDUIActionObject(buttonTitle: Localization.localizedString("BUTTON_SAVE"))]
        return formStep
    }
}

open class SBATrackedModalButtonCell : RSDButtonCell {
    
    @IBOutlet weak var promptLabel: UILabel!
    
    /// The nib to use with this cell. Default will instantiate a `SBATrackedMedicationDetailCell`.
    open class var nib: UINib {
        let bundle = Bundle(for: SBATrackedModalButtonCell.self)
        let nibName = String(describing: SBATrackedModalButtonCell.self)
        return UINib(nibName: nibName, bundle: bundle)
    }
}
