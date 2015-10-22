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

// Provides access to API and loaded data
class LearningStudio {
    
    // Singleton allow access to variables from anywhere in the app.
    class var api: LearningStudio {
        struct Static {
            static var token: dispatch_once_t = 0
            static var instance: LearningStudio!
        }
        dispatch_once(&Static.token) {
            Static.instance = LearningStudio()
        }
        return Static.instance
    }
    
    // MARK: - Constants
    
    // reusable api related constants
    private let apiDomain = "https://api.learningstudio.com"
    private let defaultTimeZone = "UTC"
    private let shortDateFormat = "MM/dd/yyyy"
    private let normalDateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    private let longDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    
    // user defaults keys
    private let defaultUsernameKey = "username"     // String - username for last login
    
    // error related constants
    private let errorDomainName = "LearningStudio"  // Custom error domain name
    private let errorNoDataCode = 122   // Failed due to no data when expected
    private let errorNoTokenCode = 123  // Failed due to missing token. Should never happen
    private let errorUnknownDataType = 124 // Failed due recognize input data type for API call
    private let errorUnexpectedApiResponse = 125 // detecting 500 errors from API
    
    // MARK: - private variables
    
    // user credentials for session management
    private var username: String = ""
    private var password: String = ""
    
    // token data for session management
    private var tokens: AnyObject?
    private var tokenExpireDate: NSDate?
    
    // config for api access
    private let config: Dictionary<String,String>   // configuration for accessing api
    
    // keychain services
    private let keychainWrapper = KeychainItemWrapper(identifier: "com.pearson.developer.LSCritique", accessGroup: nil)
    
    // MARK: - Constructors
    
    init() {
        // load config for API access
        if let lsPropsPath = NSBundle.mainBundle().pathForResource("LearningStudio", ofType: "plist") {
            config = NSDictionary(contentsOfFile: lsPropsPath) as! Dictionary<String, String>
        }
        else {
            config = [:]
        }
    }
    
    // MARK: - Credential Management Methods
    
    // allows credentials to be changed on login screen
    func setCredentials(username newUsername: String, password newPassword: String) {
        self.username = newUsername
        self.password = newPassword
    }
    
    // save user credentials for future app launches
    func saveCredentials() {
        NSUserDefaults.standardUserDefaults().setValue(username, forKey: defaultUsernameKey)
        keychainWrapper.setObject(password, forKey:kSecValueData)
    }
    
    // checks for saved credentials. restores them if possible
    func restoreCredentials() -> Bool {
        
        // credentials can be reloaded if tokens missing
        if tokens == nil {
            if let savedUsername = NSUserDefaults.standardUserDefaults().objectForKey(defaultUsernameKey) as? String{
                // keychain password is stored as v_Data by wrapper
                if let savedPassword = keychainWrapper.objectForKey("v_Data") as? String {
                    username = savedUsername
                    password = savedPassword
                }
            }
        }
        
        // just want to know if they are set
        return username != "" && password != ""
    }
    
    // clears credentials and all associated data
    func clearCredentials() {
        // clear all variables
        username = ""
        password = ""
        tokens = nil
        tokenExpireDate=nil
        
        // clear saved credentials and data archive
        NSUserDefaults.standardUserDefaults().removeObjectForKey(defaultUsernameKey)
        keychainWrapper.resetKeychainItem()
    }
    
    // MARK: - Generic Request Methods
    
    // retrieves token for API calls
    private func authenticate(callback:(accessToken: String?, error: NSError?) -> Void) {
        
        // a valid token might already exist
        if tokens != nil {
            if let accessToken = tokens!["access_token"] as? String {
                if(tokenExpireDate!.compare(NSDate()) == NSComparisonResult.OrderedDescending) {
                    callback(accessToken:accessToken, error:nil)
                    return
                }
            }
        }
        
        // If not, we'll need to get one
        let session = NSURLSession.sharedSession()
        
        // Only the app's id and client string are required
        // This only allows OAuth2 with the user's credentials
        // OAuth1 is not appropriate for a mobile app.
        let appId = config["app_id"]!
        let clientString = config["client_string"]!
        
        // post to the token url
        let tokenUrl = NSURL(string: apiDomain + "/token")
        let tokenRequest = NSMutableURLRequest(URL: tokenUrl!)
        tokenRequest.HTTPMethod = "POST"
        
        // with the app id, username, and password
        let fullUsername = clientString + "\\" + username
        let postString = "grant_type=password&client_id=\(appId)&username=\(fullUsername)&password=\(password)"
        tokenRequest.HTTPBody = postString.dataUsingEncoding(NSUTF8StringEncoding)
        
        let requestDate = NSDate()
        let tokenTask = session.dataTaskWithRequest(tokenRequest, completionHandler: { (tokenData, tokenResponse, tokenError) -> Void in
            
            // return on error
            if tokenError != nil {
                callback(accessToken:nil, error:tokenError)
                return
            }
            
            let httpResponse = tokenResponse as! NSHTTPURLResponse
            // anything other than a 200 is error so just abort.
            if httpResponse.statusCode != 200 {
                callback(accessToken: nil,
                    error: NSError(domain: self.errorDomainName, code: self.errorUnexpectedApiResponse, userInfo: nil))
                return
            }
            
            // parse the json
            var tokenErr: NSError?
            var tokenJson: [String : AnyObject]?
            do {
                tokenJson = try NSJSONSerialization.JSONObjectWithData(tokenData!, options: NSJSONReadingOptions.MutableContainers) as? [String : AnyObject]
            }
            catch let error as NSError {
                tokenErr = error
            }
            
            if tokenErr != nil {
                // return if there is an error parsing JSON
                callback(accessToken:nil, error: tokenErr)
                return
            }
            
            // extract the token
            if let accessToken = tokenJson!["access_token"] as? String {
                // store the token and expriation date
                let expiresIn = tokenJson!["expires_in"] as! Double
                self.tokenExpireDate = requestDate.dateByAddingTimeInterval(expiresIn)
                self.tokens=tokenJson! // save the token for later
                callback(accessToken:accessToken, error:nil)
            }
            else {
                // return if the token is missing
                callback(accessToken:nil, error: NSError(domain: self.errorDomainName, code: self.errorNoTokenCode, userInfo: nil))
            }
        })
        tokenTask.resume()
    }
    
    // Asynchronously performs REST operation with JSON input and output
    private func doOperation(httpMethod: String, path: String, dataType: String, data: AnyObject?, callback: (data:AnyObject?, error:NSError?) -> Void) {
        authenticate({ (accessToken, error) -> Void in
            
            // return if token not obtained
            if error != nil {
                callback(data:nil, error:error)
                return
            }
            
            // otherwise, perform the operation
            let session = NSURLSession.sharedSession()
            
            // the path may already be a full path if following a link from response, so only prepend the domain when needed.
            let dataUrl = path.rangeOfString(self.apiDomain) == nil ?  NSURL(string: self.apiDomain + path) : NSURL(string: path)
            let dataRequest = NSMutableURLRequest(URL: dataUrl!)
            dataRequest.HTTPMethod = httpMethod
            // include request body if applicable
            if data != nil {
                
                // we can handle json and binary input data types
                if dataType == "application/json" {
                    if let jsonData = try? NSJSONSerialization.dataWithJSONObject(data!, options: []) {
                        if let jsonString = NSString(data: jsonData, encoding: NSUTF8StringEncoding) {
                            dataRequest.HTTPBody = jsonString.dataUsingEncoding(NSUTF8StringEncoding)
                        }
                        else {
                            callback(data:nil, error: NSError(domain: self.errorDomainName, code: self.errorUnknownDataType, userInfo: nil))
                            return
                        }
                    }
                    else {
                        callback(data:nil, error: NSError(domain: self.errorDomainName, code: self.errorUnknownDataType, userInfo: nil))
                        return
                    }
                }
                // http://stackoverflow.com/questions/29623187/upload-image-with-multipart-form-data-ios-in-swift
                // http://stackoverflow.com/questions/26162616/upload-image-with-parameters-in-swift
                else if dataType == "multipart/form-data" {
                    
                    var formData: NSData?
                    var mimeType = "application/octet-stream"
                    var filename = ""
                    var fullFilename = ""
                    
                    if data is String {
                        // file details
                        let pathToFile = data as! String
                        let urlToFile = NSURL(fileURLWithPath: pathToFile)
                        
                        fullFilename = urlToFile.lastPathComponent!
                        let pathExtension = urlToFile.pathExtension!
                        let filenameRange = Range(start: fullFilename.startIndex, end: fullFilename.startIndex.advancedBy(fullFilename.characters.count-pathExtension.characters.count-1))
                        filename = fullFilename.substringWithRange(filenameRange)
                        formData = NSData(contentsOfFile: pathToFile)!
                    }
                    else if data is UIImage {
                        filename = "NewImage"
                        fullFilename = "NewImage.png"
                        mimeType = "image/png"
                        formData = UIImagePNGRepresentation(data as! UIImage)
                    }
                    else {
                        assertionFailure("Have only implemented String/filepath an UIImage for multipart/formdata")
                    }
                    
                    // create boundaries
                    let boundary:String = "Boundary-\(NSUUID().UUIDString)"
                    let startBoundary:String = "--\(boundary)\r\n"
                    let endBoundary:String = "\r\n--\(boundary)--"
                    
                    // build request data
                    let body = NSMutableString()
                    body.appendFormat(startBoundary)
                    body.appendFormat("Content-Disposition: form-data; name=\"\(filename)\"; filename=\"\(fullFilename)\"\r\n")
                    body.appendFormat("Content-Type: \(mimeType)\r\n\r\n")
                    let myRequestData:NSMutableData = NSMutableData()
                    myRequestData.appendData(body.dataUsingEncoding(NSUTF8StringEncoding)!)
                    myRequestData.appendData(formData!)
                    myRequestData.appendData(endBoundary.dataUsingEncoding(NSUTF8StringEncoding)!)
                    
                    // populate request
                    let contentType = "multipart/form-data; boundary=\(boundary)"
                    dataRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
                    dataRequest.setValue("\(myRequestData.length)", forHTTPHeaderField: "Content-Length")
                    dataRequest.HTTPBody = myRequestData
                }
                else {
                     callback(data:nil, error: NSError(domain: self.errorDomainName, code: self.errorUnknownDataType, userInfo: nil))
                    return
                }
            }
            // include token in header
            dataRequest.addValue("Access_Token access_token=\(accessToken!)", forHTTPHeaderField: "X-Authorization")
            
            // perform the operation
            let dataTask = session.dataTaskWithRequest(dataRequest, completionHandler: { (data, response, error) -> Void in
                
                // return error when present
                if error != nil {
                    callback(data:nil, error:error)
                    return
                }
             
                let httpResponse = response as! NSHTTPURLResponse
                // trap 400 and 500 errors. 500 just happens sometimes. Not expecting any 400s
                if httpResponse.statusCode >= 400 {
                    print("RECEIVED ERROR CODE \(httpResponse.statusCode)")
                    callback(data: nil,
                        error: NSError(domain: self.errorDomainName, code: self.errorUnexpectedApiResponse, userInfo: nil))
                    return
                }
                
                // return data if available
                if data != nil && data!.length != 0 {
                    let contentType = httpResponse.allHeaderFields["content-type"] as! String
                    if contentType.hasPrefix("application/json") {
                        // parse the json
                        var err: NSError?
                        var json: AnyObject?
                        do {
                            json = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)
                        } catch let error as NSError {
                            err = error
                            json = nil
                        } catch {
                            fatalError()
                        }
                        if err != nil {
                            callback(data:nil, error:err)
                            return
                        }
                        callback(data: json, error: nil)
                    }
                    else {
                        callback(data: data, error: nil)
                    }
                }
                else {
                    callback(data: nil, error: nil)
                }
            })
            dataTask.resume()
        })
    }
    
    // Asynchronously performs GET operation that returns JSON
    private func getJson(path: String, callback: (data:AnyObject?, error:NSError?) -> Void) {
        doOperation("GET",path: path, dataType: "application/json", data: nil,callback: callback)
    }
    
    
    // Asynchronously performs GET operation that returns file
    private func getFile(path: String, callback: (data:NSData?, error:NSError?) -> Void) {
        doOperation("GET",path: path, dataType: "multipart/form-data", data: nil,callback: { (data: AnyObject?, error:NSError?) -> Void in
            callback(data: data as? NSData, error: error)
        })
    }
    
    // Asynchronously performs POST operation that returns JSON
    private func postJson(path: String, json: AnyObject, callback: (data:AnyObject?, error:NSError?) -> Void) {
        doOperation("POST",path: path,dataType: "application/json", data: json,callback: callback)
    }
    
    // Asynchronously performs POST operation that returns JSON
    private func putJson(path: String, json: AnyObject, callback: (data:AnyObject?, error:NSError?) -> Void) {
        doOperation("PUT",path: path,dataType: "application/json", data: json,callback: callback)
    }
    
    // Asynchronously performs multipart POST operation that returns JSON
    private func postFile(path: String, pathToFile: String, callback: (data:AnyObject?, error:NSError?) -> Void) {
        doOperation("POST",path: path,dataType: "multipart/form-data", data: pathToFile,callback: callback)
    }
    
    // Asynchronously performs multipart PUT operation that returns JSON
    private func putImage(path: String, image: UIImage, callback: (data:AnyObject?, error:NSError?) -> Void) {
        doOperation("PUT",path: path,dataType: "multipart/form-data", data: image,callback: callback)
    }
    
    
    // MARK: - API Route Wrappers
    
    // Retrieves user/me info
    func getMe(callback: (data: [String:AnyObject]?, error:NSError?) -> Void) {
        getJson("/me", callback: { (data, error) -> Void in
            
            if error == nil {
                callback(data: data!["me"] as? [String:AnyObject], error: nil)
            }
            else {
                callback(data: nil, error: error)
            }
        })
    }
    
    // Retrieves courses in active terms
    func getCourses(callback: (data:[[String:AnyObject]]?, error:NSError?) -> Void) {
        getJson("/me/terms", callback: { (data, error) -> Void in
            if error == nil {
                
                let dateFormatter = NSDateFormatter()
                dateFormatter.timeZone = NSTimeZone(name: self.defaultTimeZone)
                dateFormatter.dateFormat = self.normalDateFormat
                var currentDate = dateFormatter.stringFromDate(NSDate())
                
                // find the earliest start and latest end
                var startDate: String?
                var endDate: String?
                
                let terms = data!["terms"] as! [[String:AnyObject]]
                for term in terms {
                    
                    let termStartDate = term["startDateTime"] as! String
                    let termEndDate = term["endDateTime"] as! String
                    // skip terms without startDate < currentDate < endDate
                    if currentDate.compare(termStartDate) == NSComparisonResult.OrderedAscending ||
                        currentDate.compare(termEndDate) == NSComparisonResult.OrderedDescending {
                            continue // not a current term
                    }
                    
                    // keep the earliest start date
                    if startDate == nil {
                        startDate = termStartDate
                    }
                    else if startDate!.compare(termStartDate) == NSComparisonResult.OrderedDescending {
                        startDate = termStartDate
                    }
                    
                    // keep the latest end date
                    if endDate == nil {
                        endDate = termEndDate
                    }
                    else if endDate!.compare(termEndDate) == NSComparisonResult.OrderedAscending {
                        endDate = termEndDate
                    }
                }
                
                // return error if no terms apply to the current date
                if startDate == nil || endDate == nil {
                    callback(data:nil, error: NSError(domain: self.errorDomainName, code: self.errorNoDataCode, userInfo: nil))
                    return
                }
                
                // convert to dates
                let start = dateFormatter.dateFromString(startDate!)
                let end = dateFormatter.dateFromString(endDate!)
                let current = dateFormatter.dateFromString(currentDate)
                
                // convert the date format
                dateFormatter.dateFormat = self.shortDateFormat
                startDate = dateFormatter.stringFromDate(start!)
                endDate = dateFormatter.stringFromDate(end!)
                currentDate = dateFormatter.stringFromDate(current!)
                
                // format the date ranges
                let startRange = "\(startDate!),\(currentDate)"
                let endRange = "\(currentDate),\(endDate!)"
                
                self.getJson("/me/courses?expand=course&startDatesBetween=\(startRange)&endDatesBetween=\(endRange)", callback: { (data, error) -> Void in
                    
                    if error == nil {
                        // remove unnecessary nesting in data
                        var newCourses: [[String:AnyObject]] = []
                        let courses = data!["courses"] as! [AnyObject]
                        for course in courses {
                            var courseLinks = course["links"] as! [[String:AnyObject]]
                            let courseLinksCourse = courseLinks[0]["course"] as! [String:AnyObject]
                            newCourses.append(courseLinksCourse)
                        }
                        
                        callback(data: newCourses, error: error)
                    }
                    else {
                        callback(data: nil, error: error)
                    }
                })
            }
            else {
                callback(data:nil, error: error)
            }
        })
    }
    
    
    // Retrieves doc sharing categories in course
    func getDocSharingCategories(courseId:Int, callback: (data: [[String:AnyObject]]?, error:NSError?) -> Void) {
        getJson("/courses/\(courseId)/docSharingCategories", callback: { (data, error) -> Void in
            
            if error == nil {
                let docSharingData = data!["docSharingCategories"] as! [[String:AnyObject]]
                var critiques: [[String:AnyObject]] = []
                for docSharing in docSharingData {
                    // the course has it's own category. exclude it and any groups
                    if (docSharing["id"] as! Int) != courseId && docSharing["assignedGroup"] == nil {
                        critiques.append(docSharing)
                    }
                }
                callback(data: critiques, error: nil)
            }
            else {
                callback(data: nil, error: error)
            }
        })
    }
    
    // Retrieves documents froms a doc sharing category in course
    func getDocSharingDocuments(courseId:Int, docSharingCategoryId:Int, callback: (data: [[String:AnyObject]]?, error:NSError?) -> Void) {
        getJson("/courses/\(courseId)/docSharingCategories/\(docSharingCategoryId)/docSharingDocuments", callback: { (data, error) -> Void in
            
            if error == nil {
                callback(data: data!["docSharingDocuments"] as? [[String:AnyObject]], error: nil)
            }
            else {
                callback(data: nil, error: error)
            }
        })
    }
    
    // Retrieves documents froms a doc sharing category in course
    func getDocSharingDocumentContent(courseId:Int, docSharingCategoryId:Int,documentId:Int, callback: (data: NSData?, error:NSError?) -> Void) {
        getFile("/courses/\(courseId)/docSharingCategories/\(docSharingCategoryId)/docSharingDocuments/\(documentId)/content", callback: { (data, error) -> Void in
            
            if error == nil {
                callback(data: data, error: nil)
            }
            else {
                callback(data: nil, error: error)
            }
        })
    }
    
    
    
    // upload audio file to temp files and doc sharing
    func uploadAudioToDocSharing(courseId:Int, docSharingCategoryId:Int, pathToFile:String, nameForFile: String, callback: (error:NSError?) -> Void) {
        postFile("/tempfiles", pathToFile: pathToFile, callback: { (data, error) -> Void in
            
            if error == nil {
                var tempFiles = data!["tempFiles"] as! [[String:AnyObject]]
                var tempFile = tempFiles[0] // should be only one
                // create json for doc sharing
                let docSharingData = [
                    "docSharingDocuments" : [
                        [
                            "fileDescription" : nameForFile,
                            "isSharedWithInstructorOnly": false,
                            "content" : [
                                "links" : [
                                    [
                                        "href" : tempFile["fileLocation"] as! String,
                                        "rel" : "related"
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
                // post json to doc sharing
                self.postJson("/courses/\(courseId)/docsharingcategories/\(docSharingCategoryId)/docsharingdocuments", json: docSharingData, callback: {  (data, error) -> Void in
                    if error == nil {
                        callback(error: nil)
                    }
                    else {
                        callback(error: error)
                    }
                    
                })
 
            }
            else {
                callback(error: error)
            }
        })
    }
    
    // Retrieves user's social profile
    func getSocialProfileByPersona(personaId: String, callback: (data: [String:AnyObject]?, error:NSError?) -> Void) {
        getJson("/social/v1/people/\(personaId)", callback: { (data, error) -> Void in
            
            if error == nil {
                callback(data: data as? [String:AnyObject], error: nil)
            }
            else {
                callback(data: nil, error: error)
            }
        })
    }
    
    // Convenience method for retrieving logged in user's profile
    func getSocialProfile(callback: (data: [String:AnyObject]?, error:NSError?) -> Void) {
        getSocialProfileByPersona(getPersonaId(), callback: callback)
    }
    
    // Updates user's social profile
    func updateSocialProfileByPersona(personaId: String, data: [String:AnyObject], callback: (data: [String:AnyObject]?, error:NSError?) -> Void) {
        putJson("/social/v1/people/\(personaId)", json: data, callback: { (data, error) -> Void in
            
            if error == nil {
                callback(data: data as? [String:AnyObject], error: nil)
            }
            else {
                callback(data: nil, error: error)
            }
        })
    }
    
    // Convenience method for updating logged in user's profile
    func updateSocialProfile(data: [String:AnyObject], callback: (data: [String:AnyObject]?, error:NSError?) -> Void) {
        updateSocialProfileByPersona(getPersonaId(), data: data, callback: callback)
    }
    
    // Retrieves user's personaId by the the user route found in links of other responses
    func getPersonaIdByUser(courseId: Int, userRoute: String, callback: (personaId: String?, error:NSError?) -> Void) {
        // prevent 403
        // can't call /users/{userId} on other users as student because of 403
        // can't use /me/classmates/{userId} because student can't retrieve teacher
        // using /courses/{courseId}/roster/{userId} instead.
        let userRouteMod = userRoute.stringByReplacingOccurrencesOfString("/users/", withString: "/courses/\(courseId)/roster/")
        getJson(userRouteMod, callback: { (data, error) in
            if error == nil {
                var rosterMember = data!["rosterMember"] as! [String:AnyObject]
                let personaId = rosterMember["personaId"] as! String
                callback(personaId: personaId, error: nil)
            }
            else {
                callback(personaId: nil, error: error)
            }
        })
    }
    
    // Retrieves user's social profile avatar
    func getAvatarByPersona(personaId: String, thumbnail: Bool, callback: (data: NSData?, error:NSError?) -> Void) {
        var route = "/social/v1/avatar/\(personaId)"
        if thumbnail {
            route += "/thumbnail"
        }
        getFile(route, callback: { (data, error) -> Void in
            
            if error == nil {
                callback(data: data, error: nil)
            }
            else {
                callback(data: nil, error: error)
            }
        })
    }
    
    // Convenience method for retrieving logged in user's avatar
    func getAvatar(thumbnail: Bool, callback: (data: NSData?, error:NSError?) -> Void) {
        getAvatarByPersona(getPersonaId(), thumbnail: thumbnail, callback: callback)
    }
    
    // update a user's avatar
    func updateAvatarByPersona(personaId: String, image: UIImage, callback: (error:NSError?) -> Void) {
        putImage("/social/v1/avatar/\(personaId)", image: image, callback: { (data, error) in
            callback(error: error)
        })
    }
    
    // Convenience method for updating the logged in user's avatar
    func updateAvatar(image: UIImage, callback: (error:NSError?) -> Void) {
        updateAvatarByPersona(getPersonaId(), image: image, callback: callback)
    }
    
    // Determine if user is moderator a course
    func isModerator(courseId: Int, callback: (data: Bool?, error:NSError?) -> Void) {
        getJson("/me/courses/\(courseId)/role", callback: { (data, error) -> Void in
            if error == nil {
                var role = data!["role"] as! [String:AnyObject]
                let isTeacher = (role["type"] as! String) == "PROF"
                callback(data: isTeacher, error: nil)
            }
            else {
                callback(data: nil, error: error)
            }
        })
    }
    
    // Convenience method that assembles personaId from known pattern
    func getPersonaId() -> String {
        let clientString = config["client_string"]!
        return "\(clientString)_\(username)"
    }
    
    // Converts a UTC/default time for timezone to device's timezone
    func convertDate(dateString: String, humanize: Bool = false) -> String {
        
        // convert from default timezone
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = normalDateFormat
        dateFormatter.timeZone = NSTimeZone(name: defaultTimeZone)
        
        // covert string to date
        var date = dateFormatter.dateFromString(dateString)
        
        // might have been long format if it failed
        if date == nil {
            dateFormatter.dateFormat = longDateFormat
            date = dateFormatter.dateFromString(dateString)
            
            // give up this failed too
            if date == nil {
                return ""
            }
            
            dateFormatter.dateFormat = normalDateFormat
        }
        
        // humanize the output if requested
        if humanize {
            dateFormatter.dateFormat = "yyyy-MM-dd hh:mm a"
        }
        
        // convert to local timezone
        dateFormatter.timeZone = NSTimeZone.localTimeZone()
        
        return dateFormatter.stringFromDate(date!)
    }
        
}
