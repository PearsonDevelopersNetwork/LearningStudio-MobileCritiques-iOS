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

import UIKit
import AVFoundation

// Stage for critique
class StageViewController: UIViewController, AVAudioRecorderDelegate, CritiqueDelegateProtocol {
    
    var critiqueManager:CritiqueManager?
    
    // data for user and speaker - used for display and file names
    private var userProfile: [String:AnyObject]?
    private var speakerProfileForCritiquePersonaId: String?
    private var speakerProfile: [String:AnyObject]?
    private var isModerator: Bool?
    
    // utility related
    private var audioRecording = false
    private var audioRecorder: AVAudioRecorder?
    private var soundFilePath: String? // TODO - rethink this
    private var timer: NSTimer?


    @IBOutlet weak var audioToggleButton: UIButton!
    @IBOutlet weak var factoidLabel: UILabel!
    @IBOutlet weak var timerLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        initAudio()
        
        self.audioToggleButton.enabled = false
        
        // prepare the screen based on the user's role
        
        let personaId = LearningStudio.api.getPersonaId()
        
        LearningStudio.api.isModerator(getCourseId(), callback: { (data, error) in
            if error == nil {
                self.isModerator = data!
                let critiqueInfo = CritiqueInfo(personaId: personaId, isModerator: data!, courseId: self.getCourseId(), critiqueId: self.getDocSharingCategoryId())
                self.critiqueManager = CritiqueManager(critiqueInfo: critiqueInfo)
                self.critiqueManager?.delegate = self
                
                LearningStudio.api.getSocialProfileByPersona(personaId, callback: { (data, error) in
                    if error == nil {
                        self.userProfile = data!
                        self.critiqueManager?.startCritique()
                    }
                    else {
                        dispatch_async(dispatch_get_main_queue()) {
                            self.userProfile = nil
                            let alertController = UIAlertController(title: "Try again", message:
                                "Failed to load user profile.", preferredStyle: UIAlertControllerStyle.Alert)
                            alertController.addAction(UIAlertAction(title: "Got it", style: UIAlertActionStyle.Default, handler: {_ in
                                dispatch_async(dispatch_get_main_queue()) {
                                    self.dismissViewControllerAnimated(true, completion: nil)
                                }
                            }))
                            self.presentViewController(alertController, animated: true, completion: nil)
                        }
                    }
                })
            }
            else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.userProfile = nil
                    let alertController = UIAlertController(title: "Try again", message:
                        "Failed to load user profile.", preferredStyle: UIAlertControllerStyle.Alert)
                    alertController.addAction(UIAlertAction(title: "Got it", style: UIAlertActionStyle.Default, handler: {_ in
                        dispatch_async(dispatch_get_main_queue()) {
                            self.dismissViewControllerAnimated(true, completion: nil)
                        }
                    }))
                    self.presentViewController(alertController, animated: true, completion: nil)
                }
            }
        })
        
        // make the button round
        audioToggleButton.layer.cornerRadius = audioToggleButton.bounds.width / 2
        audioToggleButton.layer.masksToBounds = true
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Pause, target: self, action: "closeStage:")
        
        // keep the screen from going to sleep
        UIApplication.sharedApplication().idleTimerDisabled = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // exit the stage
    func closeStage(sender: UIBarButtonItem) {
        audioRecorder = nil
        soundFilePath = nil
        self.critiqueManager = nil
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // moderator can end critiques
    func releaseStage(sender: UIBarButtonItem) {
        dispatch_async(dispatch_get_main_queue()) {
            self.navigationItem.rightBarButtonItem = nil
        }
        critiqueManager?.releaseStage()
    }

    // MARK:- Audio Recording
    
    // These tutorials were helpful
    // http://www.appcoda.com/ios-avfoundation-framework-tutorial/
    // http://www.techotopia.com/index.php/Recording_Audio_on_iOS_8_with_AVAudioRecorder_in_Swift
    
    // where to save audio files
    private func getDocsDir() -> String {
        let dirPaths =
        NSSearchPathForDirectoriesInDomains(.DocumentDirectory,
            .UserDomainMask, true)
        return dirPaths[0] 
    }
    
    // prepare for audio recording
    private func initAudio() {
        
        if !shouldRecordCritique() {
            return
        }

        let docsDir = NSURL(fileURLWithPath: getDocsDir())
        soundFilePath =
        docsDir.URLByAppendingPathComponent("critique.m4a").path
        
        var error: NSError?
        
        if NSFileManager.defaultManager().fileExistsAtPath(soundFilePath!) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(soundFilePath!)
            } catch let error1 as NSError {
                error = error1
            }
        }
        
        if let err = error {
            print("audioSession error: \(err.localizedDescription)")
        }
        
        let soundFileURL = NSURL(fileURLWithPath: soundFilePath!)
        let recordSettings: [String : AnyObject] = [
            AVNumberOfChannelsKey: NSNumber(int:2),
            AVSampleRateKey: NSNumber(double: 44100.0),
            AVFormatIDKey:  NSNumber(int: Int32(kAudioFormatMPEG4AAC))
        ]
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
        } catch let error1 as NSError {
            error = error1
        }
        
        if let err = error {
            print("audioSession error: \(err.localizedDescription)")
        }
        
        do {
            audioRecorder = try AVAudioRecorder(URL: soundFileURL,
                settings: recordSettings)
        } catch let error1 as NSError {
            error = error1
            audioRecorder = nil
        }
        
        if let err = error {
            print("audioSession error: \(err.localizedDescription)")
        } else {
            audioRecorder?.prepareToRecord()
        }
    }
    
    // keep a timer while user is speaking
    var timeSpent = 0
    func updateTimer() {
        
        timeSpent++
        
        let minutes = Int(timeSpent / 60)
        let seconds = timeSpent % 60
        var timeString = ""
        if minutes < 10 {
            timeString += "0"
        }
        timeString += String(minutes)
        timeString += ":"
        if seconds < 10 {
            timeString += "0"
        }
        timeString += String(seconds)
        
        self.timerLabel.text = timeString
    }
    
    // start a timer when enabled
    private func startTimer() {
        if !shouldShowTimer() {
            return
        }
        
        if timer == nil {
            dispatch_async(dispatch_get_main_queue()) {
                self.timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector:"updateTimer", userInfo: nil, repeats: true)
            }
        }
    }
    
    // reset the timer when enabled
    private func resetTimer() {
        if !shouldShowTimer() {
            return
        }
        
        timer?.invalidate()
        timer = nil
        timeSpent = 0
        
        dispatch_async(dispatch_get_main_queue()) {
            self.timerLabel.text = ""
        }
    }
    
    // record audio when enabled
    private func recordAudio() {
        
        if !shouldRecordCritique() {
            return
        }
        
        if audioRecorder?.recording == false {
            audioRecorder?.delegate = self
            audioRecorder?.record()
        }
    }
    
    // stop audio when enabled. Otherise, simulate audio stopping
    private func stopAudio() {
        
        resetTimer()
        
        if !shouldRecordCritique() {
            
            self.critiqueManager!.droppingHand() // begin dropping hand
            
            animateWhileWaiting()
            
            dispatch_after( // delay for 3 seconds
                dispatch_time(DISPATCH_TIME_NOW,Int64(3 * Double(NSEC_PER_SEC))), // # seconds
                dispatch_get_main_queue()) {
                    self.enableUIAfterRecording()
            }
            return
        }
        
        if audioRecorder?.recording == true {
            audioRecorder?.stop()
        }
    }
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer!, successfully flag: Bool) {
    }
    
    func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer!, error: NSError!) {
    }
    
    // save audio when recording finished
    func audioRecorderDidFinishRecording(recorder: AVAudioRecorder, successfully flag: Bool) {
        
        animateWhileWaiting()
        
        let docsDir = NSURL(fileURLWithPath: getDocsDir())
        
        // name of speaker
        let userProfileId =  userProfile!["id"] as! String
        let userProfileName = userProfile!["name"] as! [String:String]
        let userFirstName = userProfileName["givenName"] as String?
        let userLastName = userProfileName["familyName"] as String?
        let userDisplayName = userFirstName == "" && userLastName == "" ? userProfileId : "\(userFirstName!) \(userLastName!)"
        
        // cleanse the filename
        let charactersToAllow = NSMutableCharacterSet.alphanumericCharacterSet() // start with broad range of chars to allow
        charactersToAllow.addCharactersInString("_") // add the other characters
        let charactersToRemove = charactersToAllow.invertedSet // invert to remove everything else
        let userFileName = userDisplayName.componentsSeparatedByCharactersInSet(charactersToRemove).joinWithSeparator("")
        
        
        var fileDescription = "\(userDisplayName) presents"
        var newFileName = "\(userFileName)_presents.m4a"
        
        // 2 filenames - presenter and critiques
        // "{PresenterName}_presents.m4a" or "{CritiquerName}_critique-for_{PresenterName}.m4a"
        
        if self.speakerProfileForCritiquePersonaId != nil { // change the filename if this is a critique not a presentation
            let speakerProfileId = self.speakerProfileForCritiquePersonaId!
            var speakerDisplayName = speakerProfileId
            if speakerProfile != nil {
                let speakerProfileName = speakerProfile!["name"] as! [String:String]
                let speakerFirstName = speakerProfileName["givenName"] as String?
                let speakerLastName = speakerProfileName["familyName"] as String?
            
                speakerDisplayName = speakerFirstName == "" && speakerLastName == "" ? speakerProfileId : "\(speakerFirstName!) \(speakerLastName!)"
            }
            let speakerFileName = speakerDisplayName.componentsSeparatedByCharactersInSet(charactersToRemove).joinWithSeparator("")
            
            fileDescription = "\(userDisplayName) critique for  \(speakerDisplayName)"
            newFileName = "\(userFileName)_critique-for_\(speakerFileName).m4a"
        }
        
        let newFilePath = docsDir.URLByAppendingPathComponent(newFileName).path!
        
        var fileError:NSError?
        
        // attempt cleanup if needed
        if NSFileManager.defaultManager().fileExistsAtPath(newFilePath) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(newFilePath)
            } catch let error as NSError {
                fileError = error
            }
        }
        
        if fileError != nil {
            print("Failed to delete file: \(fileError!.localizedDescription)")
            // TODO - what to do?
            enableUIAfterRecording()
            return
        }
        
        do {
            try NSFileManager.defaultManager().moveItemAtPath(soundFilePath!, toPath: newFilePath)
        } catch let error as NSError {
            fileError = error
        }
        
        if fileError != nil {
            print("Failed to move file: \(fileError!.localizedDescription)")
            // TODO - what to do?
            enableUIAfterRecording()
            return
        }
        
        uploadAudio(newFilePath, newFileName: fileDescription)
    }
    
    // upload audio to doc sharing
    func uploadAudio(newFilePath: String, newFileName: String) {
        
        self.critiqueManager!.droppingHand() // begin dropping hand when uploading audio
        
        var fileError:NSError?
        LearningStudio.api.uploadAudioToDocSharing(getCourseId(), docSharingCategoryId: getDocSharingCategoryId(), pathToFile: newFilePath, nameForFile: newFileName, callback: { (error) -> Void  in
            // TODO - handle error and delete file on success
            if error == nil {
                do {
                    try NSFileManager.defaultManager().removeItemAtPath(newFilePath)
                } catch let error as NSError {
                    fileError = error
                } catch {
                    fatalError()
                }
                
                if fileError != nil {
                    print("Failed to delete file: \(fileError!.localizedDescription)")
                    // TODO - what to do?
                }
                
                self.enableUIAfterRecording()
            }
            else {
                // TODO - try again?
                dispatch_async(dispatch_get_main_queue()) {
                    let alertController = UIAlertController(title: "Ooopps", message:
                        "Your file was not uploaded.", preferredStyle: UIAlertControllerStyle.Alert)
                    alertController.addAction(UIAlertAction(title: "Retry", style: UIAlertActionStyle.Default,handler: {_ in
                        self.uploadAudio(newFilePath, newFileName: newFileName)
                    }))
                    alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: {_ in
                        do {
                            try NSFileManager.defaultManager().removeItemAtPath(newFilePath)
                        } catch let error as NSError {
                            fileError = error
                        } catch {
                            fatalError()
                        }
                        self.enableUIAfterRecording()
                    }))
                    self.presentViewController(alertController, animated: true, completion: nil)
                }
            }
        })
    }
    
    func audioRecorderEncodeErrorDidOccur(recorder: AVAudioRecorder, error: NSError?) {
    }
    
    // prevent leaving screen while speaking without stopping first
    private func disableUIDuringRecording() {
        
        startTimer()
        
        dispatch_async(dispatch_get_main_queue()) {
            self.navigationItem.leftBarButtonItem!.enabled = false
            self.tabBarController?.tabBar.userInteractionEnabled = false
            self.navigationItem.rightBarButtonItem?.enabled = false
        }
    }
    
    // enable screen once speaking ends
    private func enableUIAfterRecording() {
        
        resetTimer()
        clearFactiods()
        
        dispatch_async(dispatch_get_main_queue()) {
            self.navigationItem.leftBarButtonItem!.enabled = true
            self.tabBarController?.tabBar.userInteractionEnabled = true
            
            self.audioToggleButton.setTitle("Record", forState: .Normal)
            
            self.audioToggleButton.setBackgroundImage(nil, forState: .Normal)
            self.audioToggleButton.backgroundColor = UIColor.lightGrayColor()
            self.critiqueManager!.dropHand()
        }
    }

    // Change speaker state based on button press
    @IBAction func toggleAudio(sender: UIButton) {
    
        sender.enabled = false;
        self.animateWhileWaiting()
        
        if audioRecording {
            audioRecording = false
            stopAudio()
            dispatch_async(dispatch_get_main_queue()) {
                self.audioToggleButton.setTitle("", forState: .Normal)
            }
        }
        else {
            critiqueManager!.raiseHand({ (chosen)  -> Void in
                dispatch_async(dispatch_get_main_queue()) {
                    if chosen {
                        self.audioRecording = true
                        self.recordAudio()
                        self.audioToggleButton.setTitle("Stop", forState: .Normal)
                        self.audioToggleButton.backgroundColor = UIColor.redColor()
                        self.audioToggleButton.enabled=true
                        self.disableUIDuringRecording()
                    }
                    else {
                         self.critiqueManager!.dropHand()
                    }
                }
            })
        }
    }

    // MARK:- animation methods for button
    
    private var animationStarted = false
    private func animateWhileWaiting() {
        dispatch_async(dispatch_get_main_queue()) {
            self.keepAnimatingWhileWaiting()
        }
    }
    
    // button animates until enabled
    private func keepAnimatingWhileWaiting() {
    
        var transform: CGAffineTransform?
        if !self.animationStarted {
            self.animationStarted = true
            transform = CGAffineTransformMakeScale(0.4, 0.4)
        }
        else {
            self.animationStarted = false
            transform = CGAffineTransformMakeScale(0.8, 0.8)
        }
        
        dispatch_async(dispatch_get_main_queue()) {
            UIView.animateWithDuration(1,
                animations: {
                    self.audioToggleButton.transform = transform!
                },
                completion: { finish in
                    if !self.audioToggleButton.enabled {
                        self.keepAnimatingWhileWaiting()
                    }
                    else {
                        self.animationStarted = false
                        dispatch_async(dispatch_get_main_queue()) {
                            UIView.animateWithDuration(0.5){
                                self.audioToggleButton.transform = CGAffineTransformMakeScale(1.0, 1.0)
                            }
                        }
                    }
            })

            
        }
    }

    
    // MARK: - Critique Manager delegate 
    
    func critiqueAvailabilityChanged(critiqueInfo: CritiqueInfo, available:Bool, personaId: String?, critiqueForPersonaId: String?) {

        // can't leave audio going
        if self.audioRecording {
            toggleAudio(audioToggleButton)
            return
        }
        
        dispatch_async(dispatch_get_main_queue()) {
            self.audioToggleButton.enabled = available
        }
        
        if isModerator! { // control the fast forward based on critique status
            if critiqueForPersonaId != nil {
                dispatch_async(dispatch_get_main_queue()) {
                    if self.navigationItem.rightBarButtonItem == nil {
                        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FastForward, target: self, action: "releaseStage:")
                    }
                    
                    if personaId == nil {
                        self.navigationItem.rightBarButtonItem?.enabled = true
                    }
                    else {
                        self.navigationItem.rightBarButtonItem?.enabled = false
                    }
                }
            }
            else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.navigationItem.rightBarButtonItem = nil
                }
            }
        }
        
        let userPersonaId = LearningStudio.api.getPersonaId()
        
        // reset ui
        // start timer unless we're on stage
        if personaId == nil || (personaId != nil && personaId! != userPersonaId) {
            resetTimer()
        }
        clearFactiods()
        self.speakerProfile = nil
        self.speakerProfileForCritiquePersonaId = nil // stays nil unless user is critiquing for someone else (load that profile instead)
        
        if personaId != nil && !available &&  // load image if we are just spectating
            !(isModerator! && personaId == userPersonaId) { // moderator needs a special case (available=false when hand raised)
            // load the avatar of the speaker
            let docSharingPersonaImage = self.getDocSharingPersonaImage(personaId!)
            if docSharingPersonaImage == nil  { // load it fresh
                // load the avatar of the speaker
                LearningStudio.api.getAvatarByPersona(personaId!, thumbnail: false, callback: { (data, error) in
                    if error == nil {
                        dispatch_async(dispatch_get_main_queue()) {
                            let image = UIImage(data: data!)
                            self.audioToggleButton.setBackgroundImage(image, forState: .Normal)
                            self.setDocSharingPersonaImage(personaId!, image: image)
                        }
                    }
                    else {
                        dispatch_async(dispatch_get_main_queue()) {
                            self.audioToggleButton.setBackgroundImage(UIImage(), forState: .Normal) // TODO - default to a place holder image
                        }
                    }
                })
            }
            else { // reuse what is already loaded
                dispatch_async(dispatch_get_main_queue()) {
                    self.audioToggleButton.setBackgroundImage(docSharingPersonaImage!, forState: .Normal)
                }
            }
        }
        else {
            dispatch_async(dispatch_get_main_queue()) {
                self.audioToggleButton.setBackgroundImage(nil, forState: .Normal)
                self.factoidLabel.text = ""
            }
        }
        
        if personaId != nil || critiqueForPersonaId != nil {
            
            // load the profile of the speaker if it isn't the user of this app (that's already loaded)
            var profilePersonaId:String? = nil
            
            if personaId != nil {
                if personaId! != userPersonaId { // user is presenting
                    profilePersonaId = personaId
                }
                else if critiqueForPersonaId != nil { // someone is being critiqued
                    profilePersonaId = critiqueForPersonaId
                    if personaId! == userPersonaId { // and user is critquing
                        self.speakerProfileForCritiquePersonaId = critiqueForPersonaId
                    }
                }
            }
            
            if profilePersonaId != nil {
                LearningStudio.api.getSocialProfileByPersona(profilePersonaId!, callback: { (data, error) in
                    if error == nil {
                        self.speakerProfile = data!
                        if personaId != nil && personaId! != userPersonaId { // show factiods only if we're not presenting
                            self.showRandomFactoids()
                        }
                    }
                    else {
                        // can't provide facts without this, but that's OK
                        self.speakerProfile = nil
                    }
                })
            }
            else {
                speakerProfile = nil
            }
        }
        
        // configure button as appropriate
        dispatch_async(dispatch_get_main_queue()) {
            if available && personaId == nil {
                if critiqueForPersonaId == nil {
                    self.audioToggleButton.setTitle("Present", forState: .Normal)
                    self.audioToggleButton.backgroundColor = UIColor.greenColor()
                }
                else {
                    self.audioToggleButton.setTitle("Critique", forState: .Normal)
                    self.audioToggleButton.backgroundColor = UIColor.blueColor()
                }
                self.audioToggleButton.enabled = true
            }
            else {
                self.audioToggleButton.setTitle("", forState: .Normal)
                self.audioToggleButton.enabled = false
                self.audioToggleButton.backgroundColor = UIColor.lightGrayColor()
                self.animateWhileWaiting()
            }
        }
    }
    
    // MARK:- Factoid related methods
    
    private func clearFactiods() {
        dispatch_async(dispatch_get_main_queue()) {
            self.factoidLabel.text = ""
        }
    }
    
    // shows random facts from the speaker's profile
    private func showRandomFactoids() {
        if speakerProfile == nil {
            clearFactiods()
            return
        }
        
        var inspiredBy = ""
        
        switch arc4random_uniform(4) { // 4 options (0-3)
        case 1:
            var books = self.speakerProfile?["books"] as? [String]
            if books != nil && books!.count > 0 {
                if inspiredBy != "" {
                    inspiredBy += "\n"
                }
                inspiredBy += "Enjoyed reading "
                let randomSelection = Int(arc4random_uniform(UInt32(books!.count)))
                inspiredBy += books![randomSelection]
            }
        case 2:
            var music = self.speakerProfile?["music"] as? [String]
            if music != nil && music!.count > 0 {
                inspiredBy += "Rocks out to "
                let randomSelection = Int(arc4random_uniform(UInt32(music!.count)))
                inspiredBy +=  music![randomSelection]
            }
        case 3:
            var movies = self.speakerProfile?["movies"] as? [String]
            if movies != nil && movies!.count > 0 {
                inspiredBy += "Loved watching "
                let randomSelection = Int(arc4random_uniform(UInt32(movies!.count)))
                inspiredBy +=  movies![randomSelection]
            }
        default:
            var interests = self.speakerProfile?["interests"] as? [String]
            if interests != nil && interests!.count > 0 {
                inspiredBy += "Interested in "
                let randomSelection = Int(arc4random_uniform(UInt32(interests!.count)))
                inspiredBy +=  interests![randomSelection]
            }
        }
        
        dispatch_async(dispatch_get_main_queue()) {
            self.factoidLabel.text = inspiredBy
        }
        
        dispatch_after( // refresh inspiration in 5 seconds
            dispatch_time(DISPATCH_TIME_NOW,Int64(5 * Double(NSEC_PER_SEC))), // # seconds
            dispatch_get_main_queue()) {
                self.showRandomFactoids()
        }

    }
    
    // MARK:- Utility Methods to access logic on tabController
    
    private func getDocSharingCategoryId() -> Int {
        let tabBar = self.tabBarController as! StageTabBarController
        return tabBar.docSharingCategoryId!
    }
    
    private func getCourseId() -> Int {
        let tabBar = self.tabBarController as! StageTabBarController
        return tabBar.courseId!
    }
    
    private func getDocSharingPersonaImage(personaId: String) -> UIImage? {
        let tabBar = self.tabBarController as! StageTabBarController
        return tabBar.getDocSharingPersonaImage(personaId)
    }
    
    private func setDocSharingPersonaImage(personaId: String, image: UIImage?) {
        let tabBar = self.tabBarController as! StageTabBarController
        tabBar.setDocSharingPersonaImage(personaId, image: image)
    }
    
    private func shouldRecordCritique() -> Bool {
        let tabBar = self.tabBarController as! StageTabBarController
        
        return tabBar.stageConfig!.recordAudio
    }
    
    private func shouldShowTimer() -> Bool {
        let tabBar = self.tabBarController as? StageTabBarController
        
        if tabBar == nil { // in case we quit stage between timer events
            return false
        }
        else {
            return tabBar!.stageConfig!.showTimer
        }
    }
}
