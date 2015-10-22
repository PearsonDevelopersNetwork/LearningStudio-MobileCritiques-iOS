/*
* LearningStudio Mobile Critiques for iOS
*
* Need Help or Have Questions?
* Please use the PDN Developer Community at https://community.pdn.pearson.com
*
* @category   LearningStudio Sample Application - Mobile
* @author     Wes Williams <wes.williams@pearson.com>
* @author     Pearson Developer Services Team <apisupport@pearson.com>
* @copyright  2015 Pearson Education, Inc.
* @license    http://www.apache.org/licenses/LICENSE-2.0  Apache 2.0
* @version    1.0
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* Portions of this work are reproduced from work created and
* shared by Apple and used according to the terms described in
* the License. Apple is not otherwise affiliated with the
* development of this work.
*/

import Foundation
import MultipeerConnectivity

// http://www.ralfebert.de/tutorials/ios-swift-multipeer-connectivity/

class CritiqueManager : NSObject, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate {

    private let serviceType = "lscritique"
    private let serviceTimeout = 5.0
    
    // the connected user has these properties
    private var isModerator: Bool = false
    private var peerId: MCPeerID!
    private var session: MCSession!
    
    private var managedCourseId: Int!
    private var managedCritiqueId: Int!
    private var managedPersonaId:String!
    private var connectedPeer: MCPeerID?
    
    // every user is advertising and browsing, but the moderator is doing the opposite of users.
    private var serviceAdvertiser : MCNearbyServiceAdvertiser!
    private var serviceBrowser : MCNearbyServiceBrowser!
    private var lastConnectTime: Int64 = 0
    
    // Keeping status of the stage locally
    private var stageAvailability:Bool = false {
        
        // changing the status notifies the UI and affects the browsing and advertising as needed.
        willSet(newStageAvailability) {
            
            let hasAvailabilityChanged = newStageAvailability != stageAvailability // is the change new
            let hasTakenStage = presentingPersonaId != nil && presentingPersonaId == managedPersonaId // students do this to take control
            let hasPeerConnected =  connectedPeer != nil && session.connectedPeers.count > 0 // moderaters do this to take control
            let hasPeerConnecting = presentingPersonaId != nil
            let hasModeratorLeftStage =  isModerator && connectedPeer != nil && connectedPeer == peerId // hack
            
            // moderator restarts services when stage is newly available
            if isModerator && (hasModeratorLeftStage || (!hasPeerConnected && newStageAvailability)) && hasAvailabilityChanged {
                        
                if hasPeerConnecting || hasModeratorLeftStage { // clear the stage
                    presentingPersonaId = nil
                    connectedPeer = nil
                }
                
                restartModeratorServices()
            }
            else // students readies for leaving stage
            if !isModerator && hasTakenStage && !newStageAvailability && hasAvailabilityChanged {
                
                presentingPersonaId = nil
                connectedPeer = nil
                serviceAdvertiser.stopAdvertisingPeer()
                serviceBrowser.stopBrowsingForPeers()
                session.disconnect()
                
                dispatch_after( // don't start accepting request immediately
                    dispatch_time(DISPATCH_TIME_NOW,Int64(serviceTimeout * Double(NSEC_PER_SEC))), // # seconds
                    dispatch_get_main_queue()) {
                        self.serviceBrowser.startBrowsingForPeers()
                }
            }
            else // moderator saves stage for new student or himself
            if isModerator && (hasTakenStage || hasPeerConnected) && !newStageAvailability {
                        
                serviceBrowser.stopBrowsingForPeers()
                serviceAdvertiser.stopAdvertisingPeer()
            
                dispatch_after( // don't start advertising immediately
                    dispatch_time(DISPATCH_TIME_NOW,Int64(serviceTimeout * 2 * Double(NSEC_PER_SEC))), // # seconds
                    dispatch_get_main_queue()) {
                        self.serviceAdvertiser = self.newServiceAdvertiser()
                        self.serviceAdvertiser.startAdvertisingPeer()
                }
            }
            else // student prepares for someone else takiing the stage
            if !isModerator && newStageAvailability && hasAvailabilityChanged && hasPeerConnecting {
                
                if !hasTakenStage {
                    presentingPersonaId = nil
                    connectedPeer = nil
                    serviceAdvertiser.stopAdvertisingPeer()
                }
                serviceBrowser.stopBrowsingForPeers()
                if !hasTakenStage {
                    session.disconnect()
                }
                
                dispatch_after( // don't start accepting request immediately
                    dispatch_time(DISPATCH_TIME_NOW,Int64(serviceTimeout * Double(NSEC_PER_SEC))), // # seconds
                    dispatch_get_main_queue()) {
                        self.serviceBrowser.startBrowsingForPeers()
                }
            }
       

            
            // let the ui when the stage changes, so it can update itself
            stageAvailabilityChange(newStageAvailability, presenterPersonaId: presentingPersonaId, critiqueForPersonaId: self.critiqueForPersonaId)
        }
    }
    
    var delegate: CritiqueDelegateProtocol?
    
    // callbacks for the ui
    private var raisedHandResponse: ((chosen:Bool) -> Void)?    // did we get the stage when requested?
    // info about the presenting user
    private var presentingPersonaId: String! {
        willSet(newPersonaId) {
            if isModerator && newPersonaId == nil && presentingPersonaId != nil && presentingPersonaId != managedPersonaId && critiqueForPersonaId == nil {
                self.critiqueForPersonaId = self.presentingPersonaId
            }
        }
    }
    private var pendingPresentingPersonaId: String?
    private var critiqueForPersonaId: String!
    
    // is initialized with flag for moderator vs non-moderator mode
    init(critiqueInfo: CritiqueInfo) {
        
        super.init()
        self.managedPersonaId = critiqueInfo.personaId
        self.isModerator = critiqueInfo.isModerator
        self.managedCourseId = critiqueInfo.courseId
        self.managedCritiqueId = critiqueInfo.critiqueId
        
        // initialize the device's identity
        self.peerId = MCPeerID(displayName: UIDevice.currentDevice().name)
        self.session = MCSession(peer: peerId)
        self.session.delegate = self
    }
    
    // intialization after delegate set
    func startCritique() {
        
        // advertiser is initialized
        self.serviceAdvertiser = newServiceAdvertiser()
        
        // browser is initialized
        self.serviceBrowser = newServiceBrowser()
        
        if self.isModerator { // moderators start with a stage on
            stageAvailability = true
        }
        else { // other users
            self.serviceBrowser.startBrowsingForPeers() // look for status of stage
        }
    }
    
    
    // tear everything down when done
    deinit {

        if serviceAdvertiser != nil {
            self.serviceAdvertiser.stopAdvertisingPeer()
        }
        
        if serviceBrowser != nil {
            self.serviceBrowser.stopBrowsingForPeers()
        }
        self.session.disconnect()
        
        self.serviceAdvertiser = nil
        self.serviceBrowser = nil
        self.session = nil
        self.peerId = nil

    }
    
    private func restartModeratorServices() {
        serviceAdvertiser.stopAdvertisingPeer()
        serviceBrowser.stopBrowsingForPeers()
        session.disconnect()
        
        dispatch_after( // don't start accepting request immediately
            dispatch_time(DISPATCH_TIME_NOW,Int64(serviceTimeout * Double(NSEC_PER_SEC))), // # seconds
            dispatch_get_main_queue()) {
                self.serviceAdvertiser = self.newServiceAdvertiser()
                self.serviceAdvertiser.startAdvertisingPeer() // tell everyone the stage is open
                if self.stageAvailability { // just in case it changes during the delay
                    self.serviceBrowser.startBrowsingForPeers()
                }
        }
    }
    
    private func newTimestamp() -> Int64 {
        return Int64((NSDate().timeIntervalSinceReferenceDate))
    }
    
    // create or reuse advertiser as appropriate
    private func newServiceAdvertiser() -> MCNearbyServiceAdvertiser {
        
        // start with the base service type
        var advertiseServiceType = serviceType
        
        // set the service type extensions as appropriate for moderator mode
        if isModerator {
            advertiseServiceType += "-stat" // status
        }
        else {
            advertiseServiceType += "-hand" // hands
        }
        
        var critiqueSessionInfo: [NSObject:AnyObject] = [
            "courseId" : String(managedCourseId),
            "critiqueId" : String(managedCritiqueId),
            "timeStamp" : String(self.newTimestamp())
        ]
        
        if isModerator {
            if self.presentingPersonaId != nil {
                critiqueSessionInfo["personaId"]  = self.presentingPersonaId
            }
            
            if self.critiqueForPersonaId != nil {
                critiqueSessionInfo["critiquePersonaId"] = self.critiqueForPersonaId
            }
        }
        else {
            critiqueSessionInfo["personaId"] = managedPersonaId
        }
        
        // advertiser is initialized
        var advertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: critiqueSessionInfo, serviceType: advertiseServiceType)
        advertiser.delegate = self
        
        return advertiser
    }
    
    // create or reuse browser as appropriate
    private func newServiceBrowser() -> MCNearbyServiceBrowser {
        
        // keep the same one if it exists
        if serviceBrowser != nil {
            return serviceBrowser
        }
        
        // start with the base service type
        var browseServiceType = serviceType
        
        // set the service type extensions as appropriate for moderator mode
        if isModerator {
            browseServiceType += "-hand"    // hands
        }
        else {

            browseServiceType += "-stat"    // status
        }
        
        // browser is initialized
        var browser = MCNearbyServiceBrowser(peer: peerId, serviceType: browseServiceType)
        browser.delegate = self
        
        return browser
    }
    
    
    // advertising - Moderators advertise status. Students advertise interests.

    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didNotStartAdvertisingPeer error: NSError!) {
    }
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didReceiveInvitationFromPeer peerID: MCPeerID!, withContext context: NSData!, invitationHandler: ((Bool, MCSession!) -> Void)!) {
        
        if isModerator {
            
            // The advertisement is the status of the stage. No reason to accept these
            invitationHandler(false, nil)
        }
        else {
            
            // check context to be sure it's what we expect (courseId, docSharingCategoryId)
            
            if context == nil { // not something we trust
                invitationHandler(false, nil)
                return
            }
            
            var contextString = NSString(data: context, encoding:NSUTF8StringEncoding)
            var peerCourseId, peerCritiqueId, peerPersonaId: String?
            if contextString != nil {
                // Need to validate the first two parts of this string
                var contextStringParts = contextString!.componentsSeparatedByString(":")
                if contextStringParts.count == 3 {
                    peerCourseId = contextStringParts[0] as? String
                    peerCritiqueId = contextStringParts[1] as? String
                    peerPersonaId = contextStringParts[2] as? String
                }
            }
            // verify the contextString is present and matches
            if  peerCourseId == nil || peerCritiqueId == nil || peerPersonaId == nil
                || peerCourseId! != String(managedCourseId)
                || peerCritiqueId! != String(managedCritiqueId)  {
                // not our critique
                invitationHandler(false, nil)
                return
            }
            
            // The advertisement was your interest in taking the stage. Accept any invitation
            if raisedHandResponse != nil {
                invitationHandler(true, self.session)
            }
            else { // not sure why this would happen.. TODO - consider removing
                invitationHandler(true, self.session)
            }
        }
    }
    
    
    // browsing (student with raised hand)

    func browser(browser: MCNearbyServiceBrowser!, didNotStartBrowsingForPeers error: NSError!) {
    }
    
    func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
        
        if info == nil { // not something we trust
            return
        }
        
        var courseId:AnyObject? = info["courseId"]
        var critiqueId:AnyObject? = info["critiqueId"]
        var personaId:AnyObject? = info["personaId"]
        var critiquePersonaId:AnyObject? = info["critiquePersonaId"]
        var timestamp:AnyObject? = info["timeStamp"]
        
        var validCourseId = courseId != nil && courseId! is String && (courseId as! String) == String(managedCourseId)
        var validCritiqueId = critiqueId != nil && courseId! is String && (critiqueId as! String) == String(managedCritiqueId)
        var validPersonaId = personaId == nil || personaId! is String
        if personaId == nil && isModerator { // students should advertise their personaId
            validPersonaId = false
        }
        var validCritiquePersonaId = critiquePersonaId == nil || critiquePersonaId! is String
        var validTimestamp = isModerator || (timestamp != nil && timestamp! is String)
        
        if !validCourseId || !validCritiqueId || !validPersonaId || !validCritiquePersonaId || !validTimestamp { // not our critique
            return
        }
        
        if !isModerator {
            var thisTimestamp: Int64? = (timestamp as! NSString).longLongValue
            
            if lastConnectTime > 0 { // not the first connection
                
                if thisTimestamp == lastConnectTime && connectedPeer == peerID { // we've already processed it...
                    return
                }
                
                var isPhantomRequest = thisTimestamp! < lastConnectTime // it's older than last request
                
                if (thisTimestamp!+10) < newTimestamp() {  // it's more than 10 seconds old
                    lastConnectTime = 0 // prevent endless loops
                    isPhantomRequest = true
                }
                
                if isPhantomRequest  {
               
                    serviceBrowser.stopBrowsingForPeers()
                    dispatch_after( // don't start accepting request immediately
                        dispatch_time(DISPATCH_TIME_NOW,Int64(serviceTimeout * Double(NSEC_PER_SEC))), // # seconds
                        dispatch_get_main_queue()) {
                            self.serviceBrowser.startBrowsingForPeers()
                    }
                    return
                }
            }

            lastConnectTime = thisTimestamp!
        }
        
        var personaIdString = info["personaId"] as? String
        var critiquePersonaIdString = critiquePersonaId as? String
        
        if personaIdString == nil && critiquePersonaIdString != nil {
            personaIdString = critiquePersonaIdString
        }

        if isModerator {
            // Looking for interest in taking the stage. Accept the first one
            if stageAvailability && connectedPeer == nil {
                self.pendingPresentingPersonaId = personaIdString
                self.stageAvailability = false
                self.connectedPeer = peerID
                
                var contextData = "\(managedCourseId):\(managedCritiqueId):\(managedPersonaId)".dataUsingEncoding(NSUTF8StringEncoding)
                browser.invitePeer(connectedPeer, toSession: self.session, withContext: contextData, timeout: serviceTimeout)
                serviceAdvertiser.stopAdvertisingPeer()
                dispatch_after( // don't let this hang forever
                    dispatch_time(DISPATCH_TIME_NOW,Int64(serviceTimeout * 2 * Double(NSEC_PER_SEC))), // # seconds
                    dispatch_get_main_queue()) {
                        let isPeerStillConnecting = self.connectedPeer == nil || (self.connectedPeer == peerID && self.session.connectedPeers.count == 0)
                        
                        if isPeerStillConnecting && !self.stageAvailability && self.pendingPresentingPersonaId != nil && self.pendingPresentingPersonaId == (personaId as! String) {
                            self.pendingPresentingPersonaId = nil
                            self.stageAvailability = true
                        }
                }
            }
        }
        else if presentingPersonaId == nil || presentingPersonaId != managedPersonaId || (presentingPersonaId == managedPersonaId && !stageAvailability) {
            
            if critiqueForPersonaId == nil {
                if personaIdString == nil || personaIdString != managedPersonaId {
                    if (connectedPeer == peerID && personaIdString == nil && presentingPersonaId == nil) ||
                        (connectedPeer == peerID && presentingPersonaId == personaIdString ) {
                        // moderator is reconnecting before the connection is lost/reset...
                        return
                    }
                }
                else {
                    if presentingPersonaId != nil && presentingPersonaId == managedPersonaId {
                        // same as losing
                        self.presentingPersonaId = nil
                        stageAvailability = false
                    }
                }
            }
            
            connectedPeer = peerID
            
            if personaIdString == nil {
                // Stage is available. Enable UI
                presentingPersonaId = nil
                critiqueForPersonaId = nil
                stageAvailability = true
            }
            else {
                if critiquePersonaIdString != nil && critiquePersonaIdString == personaIdString && personaIdString != managedPersonaId {
                    presentingPersonaId = nil
                    critiqueForPersonaId = personaIdString
                    stageAvailability = true
                }
                else  {
                    presentingPersonaId = personaIdString
                    critiqueForPersonaId = nil
                    stageAvailability = false
                }
            }
        }
    }

    func browser(browser: MCNearbyServiceBrowser!, lostPeer peerID: MCPeerID!) {

        if isModerator {
            // Release the stage when the peer disappears
            if peerID == connectedPeer {
                stageAvailability = true
                connectedPeer = nil // ensure it
            }
        }
        else { // not currently connected
            // Stage is not available. Disable UI
            if peerID == connectedPeer {
                presentingPersonaId = nil
                critiqueForPersonaId = nil
                stageAvailability = false
                connectedPeer = nil  // just in case
            }
            
            // a lostPeer while waiting for the stage means you didn't win the stage
            if raisedHandResponse != nil {
                stageAvailability = false
                raisedHandResponse!(chosen: false)
                raisedHandResponse = nil
            }
        }
    }
    
    // session (both)
    
    func session(session: MCSession!, peer peerID: MCPeerID!, didChangeState state: MCSessionState) {
        
        var stateString = ""
        switch(state) {
        case .NotConnected: stateString = "NotConnected"
        case .Connecting: stateString = "Connecting"
        case .Connected: stateString = "Connected"
        default: stateString = "Unknown"
        }

        if isModerator {
            // Confirm or Release stage for connected student
            if peerID == connectedPeer {

                if state == .Connected {
                    self.presentingPersonaId = self.pendingPresentingPersonaId
                    self.pendingPresentingPersonaId = nil
                    stageAvailability = false
                }
                else if state == .NotConnected {
                    presentingPersonaId = nil
                    connectedPeer = nil
                    stageAvailability = true
                    self.pendingPresentingPersonaId = nil
                }
            }
        }
        else {
            // Take or give up the stage based on connection status
            if raisedHandResponse != nil {
                if state == .Connected { // won the stage
                    self.presentingPersonaId = managedPersonaId
                    stageAvailability = true
                    raisedHandResponse!(chosen: true)
                    raisedHandResponse = nil
                }
                else if state == .NotConnected { // lost the stage
                    self.presentingPersonaId = nil
                    stageAvailability = false
                    raisedHandResponse!(chosen: false)
                    raisedHandResponse = nil
                }
            }
            else {
                if state == .NotConnected {
                    if self.presentingPersonaId != nil { // same as losing
                        self.presentingPersonaId = nil
                        stageAvailability = false
                    }
                    else {
                        stageAvailability = true
                    }
                }
            }
        }
    }
    
    func session(session: MCSession!, didReceiveData data: NSData!, fromPeer peerID: MCPeerID!) {
    }
    
    func session(session: MCSession!, didReceiveStream stream: NSInputStream!, withName streamName: String!, fromPeer peerID: MCPeerID!) {
    }
    
    func session(session: MCSession!, didFinishReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, atURL localURL: NSURL!, withError error: NSError!) {
    }
    
    func session(session: MCSession!, didStartReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, withProgress progress: NSProgress!) {
    }

    
    // interact with ui
    
    func raiseHand(callback: (chosen:Bool) -> Void) {
        if stageAvailability {
            presentingPersonaId = managedPersonaId
            
            stageAvailability = false
            
            if isModerator { // moderator just takes the stage if it's available
                callback(chosen: true)
                restartModeratorServices()
            }
            else { // user has to ask the moderator and wait for response
                self.raisedHandResponse = callback
                self.serviceAdvertiser = self.newServiceAdvertiser()
                self.serviceAdvertiser.startAdvertisingPeer()
                dispatch_after( // don't let this hang forever
                    dispatch_time(DISPATCH_TIME_NOW,Int64(serviceTimeout * 2 * Double(NSEC_PER_SEC))), // # seconds
                    dispatch_get_main_queue()) {
                        if self.raisedHandResponse != nil {
                            self.raisedHandResponse!(chosen: false)
                            self.raisedHandResponse = nil
                            self.stageAvailability = self.connectedPeer == nil ? false : true // in case stage never changes
                        }
                }
            }
        }
        else { // just say no if the stage is taken. should never occur if UI is responsive
            callback(chosen: false)
        }
    }
    
    // signal a speaker is completely done with his turn
    func dropHand() {
        
        self.serviceAdvertiser.stopAdvertisingPeer() // should already be stopped unless a timeout occurred
        
        if isModerator {
            connectedPeer = peerId // tricks the stage into refreshing
            self.stageAvailability = true
        }
        else {
            self.stageAvailability = false // let it discover the status again
            
            self.serviceBrowser.startBrowsingForPeers() // should be going already
        }
    }
    
    // signal a speaker is done talking but is doing cleanup.. Will call dropHand when done.
    func droppingHand() {
        
        // just stop all services to give network time to notice he's gone.
        serviceAdvertiser.stopAdvertisingPeer()
        serviceBrowser.stopBrowsingForPeers()
        session.disconnect()
    }
    
    func releaseStage() {
        if isModerator {
            self.stageAvailability = false
            self.critiqueForPersonaId = nil
            self.presentingPersonaId = nil
            self.connectedPeer = nil
            self.stageAvailability = true
        }
    }
    
    private func stageAvailabilityChange(available:Bool, presenterPersonaId: String?, critiqueForPersonaId: String?) {
        
        if delegate != nil {
            var critiqueInfo = CritiqueInfo(personaId: managedPersonaId, isModerator: isModerator, courseId: managedCourseId, critiqueId: managedCritiqueId)
        
            delegate!.critiqueAvailabilityChanged(critiqueInfo , available: available, personaId: presenterPersonaId, critiqueForPersonaId: critiqueForPersonaId)
        }
    }


}

