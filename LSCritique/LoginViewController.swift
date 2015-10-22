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

class LoginViewController: UIViewController {

    @IBOutlet weak var usernameTextfield: UITextField!
    @IBOutlet weak var passwordTextfield: UITextField!
    
    // http://stackoverflow.com/questions/29912852/how-to-show-activity-indicator-while-tableview-loads
    var activityIndicator: UIActivityIndicatorView?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        passwordTextfield.secureTextEntry=true
        
        let backgroundImageView = UIImageView(image: UIImage(named: "spotlight"))
        backgroundImageView.frame = self.view.frame
        self.view.addSubview(backgroundImageView)
        self.view.sendSubviewToBack(backgroundImageView)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.view.hidden = true
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if LearningStudio.api.restoreCredentials() {
            self.performSegueWithIdentifier("mainAppSegue", sender: self)
        }
        else {
            self.view.hidden = false
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - Navigation


    @IBAction func loginButtonPressed(sender: UIButton) {
        sender.enabled=false // prevent double taps
        self.usernameTextfield.enabled = false
        self.passwordTextfield.enabled = false
        
        if activityIndicator == nil {
            activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .White)
            activityIndicator!.center = self.view.center
            self.view.addSubview(activityIndicator!)
        }
        activityIndicator!.startAnimating()
        
        // trim username and password
        var usernameText = usernameTextfield.text.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        var passwordText = passwordTextfield.text.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        
        // check if credentials provided
        if usernameText == "" || passwordText == "" {
            let alertController = UIAlertController(title: "Invalid Login", message:
                "Enter your credentials.", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "Got it", style: UIAlertActionStyle.Default,handler: nil))
            self.presentViewController(alertController, animated: true, completion: nil)
            sender.enabled=true
            return
        }
        
        // set credentials
        LearningStudio.api.setCredentials(username: usernameText, password: passwordText)
        // verify user with credentials
        LearningStudio.api.getMe({ (data, error) -> Void in
            
            dispatch_async(dispatch_get_main_queue()) {
                if error == nil {
                    LearningStudio.api.saveCredentials()
                    self.performSegueWithIdentifier("mainAppSegue", sender: self)
                    self.passwordTextfield.text = ""
                    self.usernameTextfield.text = ""
                }
                else {
                    let alertController = UIAlertController(title: "Invalid Login", message:
                        "Enter your credentials again.", preferredStyle: UIAlertControllerStyle.Alert)
                    alertController.addAction(UIAlertAction(title: "Got it", style: UIAlertActionStyle.Default,handler: nil))
                    self.presentViewController(alertController, animated: true, completion: nil)
                }
                
                sender.enabled=true
                self.usernameTextfield.enabled = true
                self.passwordTextfield.enabled = true
                
                self.activityIndicator!.stopAnimating()
                self.activityIndicator = nil
            }
        })
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {

    }
}
