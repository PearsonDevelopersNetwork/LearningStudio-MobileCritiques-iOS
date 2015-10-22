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

class PresentedTableViewController: UITableViewController, AVAudioPlayerDelegate  {

    private let critiqueCellIdentifier = "critiqueItemCell"
    private var docSharingDocuments: [[String : AnyObject]]?
    private var audioPlayer:AVAudioPlayer?
    private var userPersonas: [String : String]?
    
    // http://stackoverflow.com/questions/29912852/how-to-show-activity-indicator-while-tableview-loads
    private var activityIndicator: UIActivityIndicatorView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.refreshControl?.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        
        self.userPersonas = [ : ]
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.docSharingDocuments == nil {
            tableView.reloadData()
            loadData()
        }
    }
    
    private func loadData() {
        LearningStudio.api.getDocSharingDocuments(getCourseId(),docSharingCategoryId: getDocSharingCategoryId()) { (data, error) -> Void in
            if error == nil {
                
                var newDocSharingDocuments: [[String : AnyObject]] = [ ]
                for doc in data! {
                    let fileName = doc["fileName"] as! String
                    
                    // only use the sound files
                    if fileName.rangeOfString(".m4a") == nil {
                        continue
                    }
                    
                    newDocSharingDocuments.append(doc)
                    
                    var submitter = doc["submitter"] as! [String:AnyObject]
                    var submitterLinks = submitter["links"] as! [[String:String]]
                    var userRoute = submitterLinks[0]["href"]!
                    
                    if self.userPersonas![userRoute] == nil {
                        LearningStudio.api.getPersonaIdByUser(self.getCourseId(), userRoute: userRoute, callback: { (personaId, error) in
                            if error == nil {
                                self.userPersonas![userRoute] = personaId!
                                
                                if self.getDocSharingPersonaImage(personaId!) == nil { // do this as little as possible
                                    LearningStudio.api.getAvatarByPersona(personaId!, thumbnail: true, callback: { (data, error) -> Void in
                                        if error == nil {
                                            self.setDocSharingPersonaImage(personaId!, image: UIImage(data: data!))
                                            dispatch_async(dispatch_get_main_queue()) {
                                                self.reloadScreenData()
                                            }
                                        }
                                    })
                                }
                                else {
                                    dispatch_async(dispatch_get_main_queue()) {
                                        self.reloadScreenData()
                                    }
                                }
                            }
                        })
                    }
                }
                
                self.docSharingDocuments = newDocSharingDocuments
            }
            else {
                self.docSharingDocuments = nil
            }
            dispatch_async(dispatch_get_main_queue()) {
                self.reloadScreenData()
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
        // detail identifiers can be released if not displayed
        if !(self.isViewLoaded()  && self.view.window != nil) {
            docSharingDocuments = nil
        }
    }
    
    deinit {
        docSharingDocuments = nil
        audioPlayer = nil
        userPersonas = nil
    }
    
    // MARK: - Table view data source
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if docSharingDocuments == nil {
            
            if activityIndicator == nil {
                activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .White)
                activityIndicator!.center = CGPointMake(self.view.center.x,self.navigationController!.navigationBar.frame.height)
                self.view.addSubview(activityIndicator!)
                activityIndicator!.startAnimating()
            }
            
            return 0
        }
        
        if activityIndicator != nil {
            activityIndicator!.stopAnimating()
            activityIndicator = nil
        }
        
        return docSharingDocuments!.count
    }
    
    override func tableView(tableView:UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var cell = tableView.dequeueReusableCellWithIdentifier(critiqueCellIdentifier, forIndexPath: indexPath) as! UITableViewCell
       
        let rowInData = docSharingDocuments!.count - indexPath.row - 1
        let doc = docSharingDocuments![rowInData]
        
        cell.textLabel!.text = doc["fileDescription"] as? String
        
        let uploadedTime = doc["uploadedTime"] as! String
        cell.detailTextLabel?.text = LearningStudio.api.convertDate(uploadedTime, humanize: true)
        
        var submitter = doc["submitter"] as! [String:AnyObject]
        var submitterLinks = submitter["links"] as! [[String:String]]
        var userRoute = submitterLinks[0]["href"]!
        let personaId = userPersonas![userRoute]
        
        if personaId != nil {
            var docSharingImage = getDocSharingPersonaImage(personaId!)
            if  docSharingImage != nil {
                cell.imageView?.image = docSharingImage!
            }
            else {
                cell.imageView?.image = UIImage() // TODO - replace with placeholder image
            }
        }
        
        cell.imageView?.layer.cornerRadius = cell.frame.height / 2
        cell.imageView?.layer.masksToBounds = true
        cell.imageView?.layer.borderColor = UIColor.blackColor().CGColor
        cell.imageView?.layer.borderWidth = 3.0
        
        cell.backgroundColor = UIColor(white: 1.0, alpha: 0.2) // iPad won't respect IB cell color
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.allowsSelection=false
        dispatch_async(dispatch_get_main_queue()) {
            self.activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .White)
            var yCoordinate = (self.tableView.rectForRowAtIndexPath(indexPath).minY + self.tableView.rectForRowAtIndexPath(indexPath).maxY ) / 2.0
            self.activityIndicator!.center = CGPointMake(self.view.center.x, yCoordinate)
            self.view.addSubview(self.activityIndicator!)
            self.activityIndicator!.startAnimating()
        }
        
        let rowInData = docSharingDocuments!.count - indexPath.row - 1
        let doc = docSharingDocuments![rowInData]
        let docId = doc["id"] as! Int
        LearningStudio.api.getDocSharingDocumentContent(getCourseId(), docSharingCategoryId: getDocSharingCategoryId(), documentId: docId) { (data, error) -> Void in
            if error == nil {
                var audioError: NSError?
                let audioSession = AVAudioSession.sharedInstance()
                audioSession.setCategory(AVAudioSessionCategoryPlayback, error: &audioError)
                
                if audioError != nil {
                    println("audioSession error: \(audioError!.localizedDescription)")
                }
                
                self.audioPlayer = AVAudioPlayer(data: data!, error: &audioError)
                
                if audioError == nil {
                    self.audioPlayer?.delegate = self
                    self.audioPlayer?.play()
                    dispatch_async(dispatch_get_main_queue()) {
                        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Stop, target: self, action: "stopPlayback:")
                    }
                }
                else {
                    self.resetScreenAfterPlayback()
                }
            }
            else {
                
                self.resetScreenAfterPlayback()
                
                dispatch_async(dispatch_get_main_queue()) {
                    let alertController = UIAlertController(title: "Try again", message:
                        "Failed to load audio.", preferredStyle: UIAlertControllerStyle.Alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: nil))
                    self.presentViewController(alertController, animated: true, completion: nil)
                }
                
                self.tableView.allowsSelection=true
            }
        }
    }
    
    func reloadScreenData() {
        self.refreshControl?.endRefreshing()
        
        if docSharingDocuments == nil {
            dispatch_async(dispatch_get_main_queue()) {
                let alertController = UIAlertController(title: "Try again", message:
                    "Failed to load critiques.", preferredStyle: UIAlertControllerStyle.Alert)
                alertController.addAction(UIAlertAction(title: "Retry", style: UIAlertActionStyle.Default,handler: {_ in
                    self.tableView.reloadData()
                    self.loadData()
                }))
                alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: nil))
                self.presentViewController(alertController, animated: true, completion: nil)
            }
        }
        else {
            tableView.reloadData()
        }
    }
    
    func refresh(sender:AnyObject) {
        self.loadData()
    }
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer!, successfully flag: Bool) {
        resetScreenAfterPlayback()
    }
    
    func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer!, error: NSError!) {
        resetScreenAfterPlayback()
    }
    
    func stopPlayback(sender: UIBarButtonItem) {
        audioPlayer?.stop()
        resetScreenAfterPlayback()
    }
    
    private func resetScreenAfterPlayback() {
        self.audioPlayer=nil
        dispatch_async(dispatch_get_main_queue()) {
            self.navigationItem.rightBarButtonItem = nil
            self.activityIndicator!.stopAnimating()
            self.activityIndicator = nil
            self.tableView.allowsSelection=true
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {

    }
    
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
        return tabBar.getDocSharingPersonaImage("\(personaId)#thumbs")
    }
    
    private func setDocSharingPersonaImage(personaId: String, image: UIImage?) {
        let tabBar = self.tabBarController as! StageTabBarController
        tabBar.setDocSharingPersonaImage("\(personaId)#thumbs", image: image)
    }
}
