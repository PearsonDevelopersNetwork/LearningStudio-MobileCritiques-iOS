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

class SocialProfileTableViewController: UITableViewController,  UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    private let profileNameCellIdentifier = "profileNameCell"
    private let profileItemCellIdentifier = "profileItemCell"
    private let profileEditCellIdentifier = "profileEditCell"
    
    private var socialProfile: [String : AnyObject]?
    private var avatar: UIImage?
    private var profileEdited = false
    private var avatarEdited = false
    
    // http://stackoverflow.com/questions/29912852/how-to-show-activity-indicator-while-tableview-loads
    private var activityIndicator: UIActivityIndicatorView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if socialProfile == nil {
            tableView.reloadData()
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.navigationItem.rightBarButtonItem = nil
    }
    
    private func loadData() {
        LearningStudio.api.getSocialProfile() { (data, error) -> Void in
            if error == nil {
                self.socialProfile = data
                LearningStudio.api.getAvatar(true, callback: { (data, error) -> Void in
                    if error == nil {
                        self.avatar = UIImage(data: data!)
                    }
                    else {
                        self.avatar = UIImage() // TODO - default to a place holder image
                    }
                    dispatch_async(dispatch_get_main_queue()) {
                        self.reloadScreenData()
                    }
                })
            }
            else {
                self.socialProfile = nil
                dispatch_async(dispatch_get_main_queue()) {
                    self.reloadScreenData()
                }
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
        if !(self.isViewLoaded()  && self.view.window != nil) {
            socialProfile = nil
            avatar = nil
        }
    }
    
    // MARK: - Table view data source
    
    override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        
        if indexPath.section == 0 {
            return .None
        }
        
        if indexPath.row >= getSectionRows(indexPath.section).count {
            return .Insert
        }
        else {
            return .Delete
        }
        
    }
    
    override func setEditing(editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        if editing {
            profileEdited = false
            avatarEdited = false
        }
        else {
            if profileEdited { // avatar will updated afterwards if needed
                updateSocialProfile()
            }
            else if avatarEdited { // only avatar is updated
                updateSocialAvatar()
            }
        }
        
        tableView.reloadData()
    }
    
    private func updateSocialProfile() {
        LearningStudio.api.updateSocialProfile(socialProfile!, callback: { (data, error) in
            if error != nil {
                dispatch_async(dispatch_get_main_queue()) {
                    let alertController = UIAlertController(title: "Try again", message:
                        "Failed to save profile.", preferredStyle: UIAlertControllerStyle.Alert)
                    alertController.addAction(UIAlertAction(title: "Retry", style: UIAlertActionStyle.Default,handler: {_ in
                        self.updateSocialProfile()
                    }))
                    alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: {_ in
                        self.socialProfile = nil
                        dispatch_async(dispatch_get_main_queue()) {
                            self.tableView.reloadData()
                        }
                    }))
                    self.presentViewController(alertController, animated: true, completion: nil)
                }
            }
            else if self.avatarEdited {
                self.updateSocialAvatar()
            }
        })
    }
    
    private func updateSocialAvatar() {
        LearningStudio.api.updateAvatar(avatar!, callback: { (error) in
            if error != nil {
                dispatch_async(dispatch_get_main_queue()) {
                    let alertController = UIAlertController(title: "Try again", message:
                        "Failed to save avatar.", preferredStyle: UIAlertControllerStyle.Alert)
                    alertController.addAction(UIAlertAction(title: "Retry", style: UIAlertActionStyle.Default,handler: {_ in
                        self.updateSocialAvatar()
                    }))
                    alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: {_ in
                        self.socialProfile = nil
                        dispatch_async(dispatch_get_main_queue()) {
                            self.tableView.reloadData()
                        }
                    }))
                    self.presentViewController(alertController, animated: true, completion: nil)
                }
            }
        })
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {

        if editingStyle == .Delete {
            var rows = getSectionRows(indexPath.section)
            rows.removeAtIndex(indexPath.row)
            setSectionRows(indexPath.section, rows: rows)
            profileEdited = true
            tableView.reloadData()
        }
        else if editingStyle == .Insert {
           
            let cellContentView = tableView.cellForRowAtIndexPath(indexPath)!.contentView
            let cellTextField = cellContentView.subviews[cellContentView.subviews.count-1] as! UITextField
            var newValue = cellTextField.text
            newValue = newValue.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            if newValue != "" {
                var rows = getSectionRows(indexPath.section)
                rows.append(newValue)
                setSectionRows(indexPath.section, rows: rows)
                profileEdited = true
                tableView.reloadData()
            }
       
        }
        
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        
        if socialProfile == nil {
            if activityIndicator == nil {
                activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .White)
                //activityIndicator!.center = self.view.center
                activityIndicator!.center = CGPointMake(self.view.center.x,self.navigationController!.navigationBar.frame.height)
                self.view.addSubview(activityIndicator!)
                activityIndicator!.startAnimating()
                self.loadData()
            }
            
            return 0
        }
        
        if activityIndicator != nil {
            activityIndicator!.stopAnimating()
            activityIndicator = nil
        }
        
        return 5 // pic + name, interests, movies, music, books
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        case 0:
            return 1
        default:
            let rows = getSectionRows(section)
            if self.editing {
                return rows.count + 1
            }
            else {
                return rows.count
            }
        }
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection: Int) -> String? {
        switch titleForHeaderInSection  {
        case 1:
                return "Interests"
        case 2:
            return "Books"
        case 3:
            return "Music"
        case 4:
            return "Movies"
        default :
            return ""
        }
    }
    
    override func tableView(tableView:UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var cellName = profileItemCellIdentifier
        if indexPath.section == 0 {
            cellName = profileNameCellIdentifier
        }
        else if self.editing && indexPath.row >= getSectionRows(indexPath.section).count {
            cellName = profileEditCellIdentifier
        }
        
        var cell = tableView.dequeueReusableCellWithIdentifier(cellName, forIndexPath: indexPath) as! UITableViewCell
        
        var value = ""
        
        switch indexPath.section {
        case 0: // Person
            cell.imageView?.image = avatar
            cell.imageView?.layer.cornerRadius = cell.frame.height / 2
            cell.imageView?.layer.masksToBounds = true
            cell.imageView?.layer.borderWidth = 3.0
           
            
            var shortName = socialProfile!["nickname"] as? String
            let names = socialProfile!["name"] as! [String:String]
            cell.detailTextLabel?.text = names["givenName"]! + " " + names["familyName"]!
            if shortName == nil || shortName == "" {
                shortName = names["givenName"]!
            }
            value = shortName!
            
        default: // Interests
            let listOfStuff = getSectionRows(indexPath.section)
            if indexPath.row < listOfStuff.count { // might be the "add row"
                value = listOfStuff[indexPath.row]
            }
            else if self.editing {
                // clear text field if it already exist
                if cell.contentView.subviews[0] is UITextField {
                   let textField = cell.contentView.subviews[0] as! UITextField
                    textField.text = ""
                }
                else { // create the textfield
                    // determine the size
                    let originOffset = CGFloat(15) // hack
                    let cellBounds = cell.contentView.bounds
                    let textFieldOrigin = CGPoint(x: cellBounds.origin.x+originOffset, y: cellBounds.origin.y)
                    let textFieldSize = CGSize(width: cellBounds.size.width-originOffset, height: cellBounds.size.height)
                    let textFieldBounds = CGRect(origin: textFieldOrigin, size: textFieldSize)
                    // init the text field
                    var textField = UITextField(frame: textFieldBounds)
                    textField.autoresizingMask = .FlexibleHeight
                    textField.autoresizesSubviews = true
                    textField.borderStyle = .None
                    textField.textColor = UIColor.whiteColor()
                    cell.contentView.addSubview(textField)
                }
            }

        }
        
        cell.textLabel!.text = value
        
        // iPad won't respect IB cell color
        if indexPath.section == 0 { // person background should be black
            cell.backgroundColor = UIColor.blackColor()
        }
        else {
            cell.backgroundColor = UIColor(white: 1.0, alpha: 0.2) // Everything else should be this
        }

        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if !self.editing || indexPath.section != 0 {
            return
        }

        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.PhotoLibrary){
            
            var imagePicker = UIImagePickerController()
            
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary;
            imagePicker.allowsEditing = false
            
            self.presentViewController(imagePicker, animated: true, completion: nil)
        }
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject: AnyObject]){
        
        if let  image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            
            var scaledImage = image
            
            let maxDimension = CGFloat(200) // 2.78 inches is probably too big
            if image.size.width > maxDimension || image.size.height > maxDimension {
                var scaleBy = CGFloat(1.0)
                if image.size.width > image.size.height {
                    scaleBy = maxDimension / image.size.width
                }
                else {
                    scaleBy = maxDimension / image.size.height
                }
                // http://nshipster.com/image-resizing/
                let size = CGSizeApplyAffineTransform(image.size, CGAffineTransformMakeScale(scaleBy, scaleBy))
                let hasAlpha = false
                let scale: CGFloat = 0.0 // Automatically use scale factor of main screen
                UIGraphicsBeginImageContextWithOptions(size, !hasAlpha, scale)
                image.drawInRect(CGRect(origin: CGPointZero, size: size))
                scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
            }
            
            avatar = scaledImage
            avatarEdited = true
            tableView.reloadData()
        }
        
        self.dismissViewControllerAnimated(true, completion:nil)

    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        self.dismissViewControllerAnimated(true, completion:nil)
    }
    
    func reloadScreenData() {
        self.refreshControl?.endRefreshing()
        
        if socialProfile == nil {
            let alertController = UIAlertController(title: "Try again", message:
                "Failed to load profile.", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "Retry", style: UIAlertActionStyle.Default,handler: {_ in
                self.tableView.reloadData()
                self.loadData()
            }))
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: {_ in
                self.socialProfile=nil
                self.avatar = nil
                self.activityIndicator?.stopAnimating()
                self.activityIndicator = nil
            }))
            self.presentViewController(alertController, animated: true, completion: nil)
        }
        else {
            tableView.reloadData()
        }
    }
    
    // MARK: - manage list in sections
    
    private func getSectionRows(section: Int) -> [String] {
        var listOfStuff: [String]? = nil
        switch section {
        case 1:
            listOfStuff = socialProfile!["interests"] as? [String]
        case 2:
            listOfStuff = socialProfile!["books"] as? [String]
        case 3:
            listOfStuff = socialProfile!["music"] as? [String]
        case 4:
            listOfStuff = socialProfile!["movies"] as? [String]
        default:
            assertionFailure("Invalid section on social profile")
        }
        
        if listOfStuff == nil {
            listOfStuff = []
        }
        
        return listOfStuff!
    }
    
    private func setSectionRows(section: Int, rows: [String]) {
        var listOfStuff: [String]? = nil
        switch section {
        case 1:
            socialProfile!["interests"] = rows
        case 2:
            socialProfile!["books"] = rows
        case 3:
            socialProfile!["music"] = rows
        case 4:
            socialProfile!["movies"] = rows
        default:
            assertionFailure("Invalid section on social profile")
        }
    }

}
