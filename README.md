# LearningStudio Mobile Critiques

## App Overview

This sample application aims to highlight what is possible with the social LearningStudio RESTful APIs from a mobile device by leveraging peer to peer technology. The peer to peer features require users to be in close proximity, so the app is enriching instead of replacing an in-person experience. 

The app allows a professor to moderate student critiques by using mobile devices to pass a virtual talking stick. The talking stick is obtained by simply requesting it when available. Any member of the class can make this request, but the first device to negotiate with the moderator is given the chance to speak. A user can present their work and receive critiques from the rest of the class. Conversations are captured by the device of the speaker. Afterwards, they are shared with the entire class through LearningStudio's document sharing. A history of the critique, audio playback, and student contributions are available for review in the app. Also, a user can manage their avatar and a subset of their social profile to share sources of inspiration. These are presented through the app to other class members while the user is speaking.

These LearningStudio APIs are featured:

  * [Avatar](http://developer.pearson.com/social-learningstudio/avatar)
  * [Social Profile](http://developer.pearson.com/social-learningstudio/people)
  * [Doc Sharing](http://developer.pearson.com/apis/doc-sharing)


### Scope of Functionality

This sample app is intended for demonstration purposes. It has been tested with iOS9 devices in a controlled environment. Issues may exist if those circumstances change. There are also many features that could be added to make it more useful. You are encouraged to contribute back fixes or features with a pull request. 

These social LearningStudio APIs could be used to add additional functionality:
  
  * [Presence](http://developer.pearson.com/social-learningstudio/presence)
  * [Remarks](http://developer.pearson.com/social-learningstudio/remarks)

## Prerequisites

### Build Environment 

  * XCode 7.0.1 or greater is required.
  * Swift 2.0 is required

### Server Environment

  * None.

## Installation

### Application Configuration

#### LearningStudio API and Environment Setup

  1. [Get Application Credentials and Sandbox](http://developer.pearson.com/learningstudio/get-learningstudio-api-key-and-sandbox)

#### Application Setup

  1. Configure Application and Environment Identifier

**LSCritique/LearningStudio.plist**

~~~~~~~~~~~~~~~~~~~~~
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>app_id</key>
	<string>{Application Id}</string>
	<key>client_string</key>
	<string>{Client/Environment Identifier}</string>
</dict>
</plist>
~~~~~~~~~~~~~~~~~~~~~

Note: The application only uses OAuth2 with the user's credentials, so the secret required for other authentication methods is not needed.

### Deployment

The application can be run through the simulator from XCode. It's a universal app, so any device should work. We've tested with iPhone 6.

Note: The simulator was very unreliable for the peer to peer functionality after upgrading to Xcode7. Best results were achieved with actual devices on the same wifi network and bluetooth disabled. 

## License

Copyright (c) 2015 Pearson Education, Inc.
Created by Pearson Developer Services

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Portions of this work are reproduced from work created and 
shared by Apple and used according to the terms described in 
the License. Apple is not otherwise affiliated with the 
development of this work.
