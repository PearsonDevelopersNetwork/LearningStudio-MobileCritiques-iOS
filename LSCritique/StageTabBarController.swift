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

class StageTabBarController: UITabBarController {
    var courseId: Int?
    var docSharingCategoryId: Int?
    var stageConfig: StageConfig?
    
    
    private var docSharingPersonaImages: [String : UIImage?]? = [ : ]
    private var charactersToRemove: NSCharacterSet!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        var charactersToAllow = NSMutableCharacterSet.alphanumericCharacterSet() // start with broad range of chars to allow
        charactersToAllow.addCharactersInString("_") // add the other characters
        charactersToRemove = charactersToAllow.invertedSet // invert to remove everything else
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
        docSharingPersonaImages = [ : ]
    }
    
    deinit {
        courseId = nil
        docSharingCategoryId = nil
        docSharingPersonaImages = nil
        charactersToRemove = nil
    }
    
    func getDocSharingPersonaImage(personaId: String) -> UIImage? {
        if docSharingPersonaImages![personaId] == nil {
            return nil
        }
        else {
            return docSharingPersonaImages![personaId]!
        }
    }
    
    func setDocSharingPersonaImage(personaId: String, image: UIImage?) {
        if image != nil {
            docSharingPersonaImages![personaId] = image
        }
    }
}
