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
import CoreBluetooth

class ConfigureTableViewController: UITableViewController, CBPeripheralManagerDelegate {
    
    var courseId: Int?
    var docSharingCategoryId: Int?
    
    private var optionConfig: [String : Bool] = [:]
    private let configureCellIdentifier = "configureItemCell"
    private var bluetoothManager: CBPeripheralManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.backgroundView = UIImageView(image: UIImage(named: "spotlight"))
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
       bluetoothManager = CBPeripheralManager(delegate: self, queue: dispatch_get_main_queue(), options: nil)
        UIApplication.sharedApplication().idleTimerDisabled = false
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
    }
    
    // MARK: - Alert about configuration
    
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager!) {
        if peripheral.state == CBPeripheralManagerState.PoweredOn {
            dispatch_async(dispatch_get_main_queue()) {
                let alertController = UIAlertController(title: "Bluetooth", message:
                    "Disable bluetooth for best results.", preferredStyle: UIAlertControllerStyle.Alert)
                alertController.addAction(UIAlertAction(title: "Got it", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(alertController, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Table view data source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection: Int) -> String? {
        return "Personal Preferences"
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return 2
    }
    
    override func tableView(tableView:UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        
        var cell = tableView.dequeueReusableCellWithIdentifier(configureCellIdentifier, forIndexPath: indexPath) as! UITableViewCell
        
        switch indexPath.row {
        case 0:
            cell.textLabel!.text = "Save Audio"
        case 1:
            cell.textLabel!.text = "Show Timer"
        default:
            cell.textLabel!.text = "?"
        }
        
        if getOptionValue(indexPath.row) {
            cell.accessoryType = UITableViewCellAccessoryType.Checkmark
        }
        else {
            cell.accessoryType = UITableViewCellAccessoryType.None
        }
        
        cell.backgroundColor = UIColor(white: 1.0, alpha: 0.2) // iPad won't respect IB cell color
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        var optionName = getOptionName(indexPath.row)
        if let optionFlag = optionConfig[optionName] {
            optionConfig[optionName] = !optionFlag
        }
        else {
            optionConfig[optionName] = false
        }
        tableView.reloadData()
    }
    
    private func getOptionName(row:Int) -> String {
        var optionName = ""
        
        switch row {
        case 0:
            optionName = "SaveAudio"
        case 1:
            optionName = "ShowTimer"
        default:
            optionName = "Unknown"
        }
        
        return optionName
    }
    
    private func getOptionValue(row:Int) -> Bool {
        var optionName = getOptionName(row)
        if let optionFlag = optionConfig[optionName] {
            return optionFlag
        }
        else {
            return true
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        // load the stage with critique identifiers
        let tabBarController = segue.destinationViewController as! StageTabBarController
        tabBarController.courseId = courseId
        tabBarController.docSharingCategoryId = docSharingCategoryId
        
        var stageConfig = StageConfig(recordAudio: getOptionValue(0),
                                        showTimer: getOptionValue(1))
        tabBarController.stageConfig = stageConfig
    }
    
}
