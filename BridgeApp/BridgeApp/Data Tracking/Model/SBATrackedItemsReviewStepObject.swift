//
//  SBATrackedItemsReviewStepObject.swift
//  BridgeApp
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

import Foundation

/// `SBATrackedItemsReviewStepObject` is intended for use in reviewing a list of selected tracked items and
/// adding details if necessary.
///
/// - seealso: `SBAMedicationTrackingStepNavigator`
open class SBATrackedItemsReviewStepObject : SBATrackedSelectionStepObject {
    
    private enum CodingKeys : String, CodingKey {
        case addDetailsTitle, addDetailsSubtitle, reviewTitle, reviewSubtitle
    }
    
    /// The title text to display when the details about each tracked item are not all filled in.
    public var addDetailsTitle: String?
    
    /// The text to display as the subtitle when the details about each tracked item are not all filled in.
    public var addDetailsSubtitle: String?
    
    /// The title text to display as the title when all the details have been added.
    public var reviewTitle: String?
    
    /// The text to display as the subtitle when all the details have been added.
    public var reviewSubtitle: String?
    
    /// Override the title to return the appropriate string given the current review state.
    open override var title: String? {
        get {
            return super.title ?? (self.hasRequiredValues ? reviewTitle : addDetailsTitle)
        }
        set {
            super.title = newValue
        }
    }
    
    /// Override the `detail` property to return the appropriate string given the current review state.
    open override var detail: String? {
        get {
            return super.detail ?? (self.hasRequiredValues ? reviewSubtitle : addDetailsSubtitle)
        }
        set {
            super.detail = newValue
        }
    }
    
    /// Override to replace the "Submit" button with default ("Next") if this step does not have the required
    /// items.
    open override func action(for actionType: RSDUIActionType, on step: RSDStep) -> RSDUIAction? {
        guard let action = super.action(for: actionType, on: step) else { return nil }
        if actionType == .navigation(.goForward) && !self.hasRequiredValues {
            return nil
        }
        return action
    }
    
    /// Decode from the given decoder, replacing values on self with those from the decoder
    /// if the properties are mutable.
    override open func decode(from decoder: Decoder, for deviceType: RSDDeviceType?) throws {
        try super.decode(from: decoder, for: deviceType)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.addDetailsTitle = try container.decodeIfPresent(String.self, forKey: .addDetailsTitle) ?? self.addDetailsTitle
        self.addDetailsSubtitle = try container.decodeIfPresent(String.self, forKey: .addDetailsSubtitle) ?? self.addDetailsSubtitle
        self.reviewTitle = try container.decodeIfPresent(String.self, forKey: .reviewTitle) ?? self.reviewTitle
        self.reviewSubtitle = try container.decodeIfPresent(String.self, forKey: .reviewSubtitle) ?? self.reviewSubtitle
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? SBATrackedItemsReviewStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.addDetailsTitle = self.addDetailsTitle
        subclassCopy.addDetailsSubtitle = self.addDetailsSubtitle
        subclassCopy.reviewTitle = self.reviewTitle
        subclassCopy.reviewSubtitle = self.reviewSubtitle
    }
}
