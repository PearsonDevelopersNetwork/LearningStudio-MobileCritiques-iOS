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

// List the courses available to a user
class CourseTableViewController: UITableViewController {
    
    var courses: [[String : AnyObject]]?
    
    private let courseCellIdentifier = "courseItemCell"
    // http://stackoverflow.com/questions/29912852/how-to-show-activity-indicator-while-tableview-loads
    private var activityIndicator: UIActivityIndicatorView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.refreshControl?.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.backgroundView = UIImageView(image: UIImage(named: "spotlight"))
        self.tableView.backgroundView?.layer.zPosition -= 1; // otherwise, we hide the refresh control
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if courses == nil {
            tableView.reloadData()
            loadData()
        }
    }
    
    private func loadData() {
        LearningStudio.api.getCourses { (data, error) -> Void in
            if error == nil {
                self.courses = data
            }
            else {
                self.courses = nil
            }
            dispatch_async(dispatch_get_main_queue()) {
                self.reloadScreenData()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
        if !(self.isViewLoaded()  && self.view.window != nil) {
            courses = nil
        }
    }
    
    // MARK: - Table view data source
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if courses == nil {
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
        
        return courses!.count
    }
    
    override func tableView(tableView:UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier(courseCellIdentifier, forIndexPath: indexPath) 
        cell.textLabel!.text = courses![indexPath.row]["title"] as? String
        
        cell.backgroundColor = UIColor(white: 1.0, alpha: 0.2) // iPad won't respect IB cell color
        
        return cell
    }
    
    // MARK: - Data load helper methods
    
    func reloadScreenData() {
        self.refreshControl?.endRefreshing()
        
        // failure to load courses is sign of a serious issue. Maybe student not enrolled anymore or wifi disabled
        if courses == nil {
            let alertController = UIAlertController(title: "Try again", message:
                "Failed to load courses.", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "Logout", style: UIAlertActionStyle.Default, handler: {_ in
                LearningStudio.api.clearCredentials()
                self.dismissViewControllerAnimated(true, completion: nil)
            }))
            self.presentViewController(alertController, animated: true, completion: nil)
        }
        else {
            tableView.reloadData()
        }
    }

    func refresh(sender:AnyObject) {
        self.loadData()
    }

    // MARK: - Segue handling
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {

        let indexPath = tableView.indexPathForCell(sender as! UITableViewCell)
        let critiqueController = segue.destinationViewController as! CritiqueTableViewController
        
        var course = courses![indexPath!.row]
        let courseId = course["id"] as! Int
        critiqueController.courseId = courseId
        
    }
}