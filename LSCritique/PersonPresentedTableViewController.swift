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

class PersonPresentedTableViewController: UITableViewController {
    
    private let critiqueCellIdentifier = "personItemCell"
    private var docSharingDocuments: [String : [[String : AnyObject]]]?
    private var docSharingPersonas: [String]?
    private var userPersonas: [String : String]?
    
    
    // http://stackoverflow.com/questions/29912852/how-to-show-activity-indicator-while-tableview-loads
    var activityIndicator: UIActivityIndicatorView?
    
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
                
                var newDocSharingDocuments : [String : [[String : AnyObject]]] = [:]
                
                for doc in data! {
                    let fileName = doc["fileName"] as! String
                    
                    // only use the sound files
                    if fileName.rangeOfString(".m4a") == nil {
                        continue
                    }
                    
                    var submitter = doc["submitter"] as! [String:AnyObject]
                    var submitterLinks = submitter["links"] as! [[String:String]]
                    var userRoute = submitterLinks[0]["href"]!
                    
                    if newDocSharingDocuments[userRoute] == nil {
                        newDocSharingDocuments[userRoute] = []
                    }
            
                    newDocSharingDocuments[userRoute]!.append(doc)
                    
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
            docSharingPersonas = nil
        }
    }
    
    deinit {
        docSharingDocuments = nil
        docSharingPersonas = nil
        userPersonas = nil
    }
    
    // MARK: - Table view data source
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if docSharingPersonas == nil {
            
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
        
        return docSharingPersonas!.count
    }
    
    override func tableView(tableView:UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var cell = tableView.dequeueReusableCellWithIdentifier(critiqueCellIdentifier, forIndexPath: indexPath) as! UITableViewCell
        
        let firstDoc = docSharingDocuments![docSharingPersonas![indexPath.row]]![0]
        let submitter = firstDoc["submitter"] as! [String:AnyObject]
        let personName = submitter["name"] as! String
        
        cell.textLabel!.text = personName
        cell.detailTextLabel?.text = String(docSharingDocuments![docSharingPersonas![indexPath.row]]!.count)
        
        var docSharingPersona = userPersonas![docSharingPersonas![indexPath.row]]
        if docSharingPersona != nil {
            var docSharingPersonaImage = getDocSharingPersonaImage(docSharingPersona!)
            if docSharingPersonaImage != nil {
                cell.imageView?.image = docSharingPersonaImage!
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
    
    func reloadScreenData() {
        self.refreshControl?.endRefreshing()
        
        if docSharingDocuments == nil {
            let alertController = UIAlertController(title: "Try again", message:
                "Failed to load critiques.", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "Retry", style: UIAlertActionStyle.Default,handler: {_ in
                self.tableView.reloadData()
                self.loadData()
            }))
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: nil))
            self.presentViewController(alertController, animated: true, completion: nil)
        }
        else {
            self.docSharingPersonas = Array(self.docSharingDocuments!.keys).sorted { self.userPersonas![$0] < self.userPersonas![$1] }
            tableView.reloadData()
        }
    }
    
    func refresh(sender:AnyObject) {
        self.loadData()
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
