//
//  Feedvc.swift
//  Kite Loop
//
//  Created by Patrick Monahan on 7/21/16.
//  Copyright © 2016 makadaapp. All rights reserved.
//

import UIKit
import Firebase
import Alamofire
import AWSS3
import DrawerController

class Feedvc: UIViewController, UITableViewDelegate, UITableViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIScrollViewDelegate {

    
    //weather info box outlets
    @IBOutlet weak var spotLabel: UILabel!
    @IBOutlet weak var windSpeedLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var waveSizeLabel: UILabel!
    @IBOutlet weak var timeAndDateLabel: UILabel!
    
    
    //social feed outlets
    @IBOutlet weak var postTextField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var selectImage: UIImageView!
    @IBOutlet weak var spotInfoVIew: SpotInfoView!
    @IBOutlet weak var msView: MagicSeaweedView!
    @IBOutlet weak var scrollView: UIScrollView!
    
    
    
    
    
    var imagePicker: UIImagePickerController!
    
    static var imageCache = NSCache()
    var posts = [Post]()
    var spot: Spot!
    var imageSelected = false
    var S3BucketName: String = ""
   
   
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        
        //Amazon config
        S3BucketName = "pm29-spot-me-app-bucket"
        let CognitoPoolID = "eu-west-1:0968c37c-5841-4c09-94cb-6e5e2b3bc93e"
        let region = AWSRegionType.EUWest1
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:region,
                                                                identityPoolId:CognitoPoolID)
        let configuration = AWSServiceConfiguration(region:region, credentialsProvider:credentialsProvider)
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = configuration
        
        
        
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.estimatedRowHeight = 300
        
        imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        
        
        //Stuff for the magic seaweed view
//        let localfilePath = NSBundle.mainBundle().URLForResource("MagicSeaweed", withExtension: "html");
//        let myRequest = NSURLRequest(URL: localfilePath!);
//        
//        self.msView.widgetView.loadRequest(myRequest);
//        
        
        
        DataService.ds.REF_POSTS.queryOrderedByChild("spot").queryEqualToValue(self.spot.spotName).observeEventType(.Value, withBlock: { snapshot in
            print(snapshot.value)
            self.posts.removeAll()
            if let snapshots = snapshot.children.allObjects as? [FDataSnapshot]{
                for snap in snapshots {
                    print("SNAP: \(snap)")
                    
                    if let postDict = snap.value as? Dictionary<String, AnyObject>{
                        let key = snap.key
                        let post = Post(postKey: key, dictionary:postDict)
                        self.posts.append(post)
                        
                    }
                }
            }
            
            self.tableView.reloadData()
        })
    
    }
    
    override func viewDidAppear(animated: Bool) {
        //self.spotInfoVIew.configureSpotInfo(self.spot)
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let post = posts[indexPath.row]
        print(post.postDescription)
        
        if let cell = tableView.dequeueReusableCellWithIdentifier("PostCell") as? PostCell{
            cell.request?.cancel()
            
            var img: UIImage?
            
            if let url = post.imageUrl {
                img = Feedvc.imageCache.objectForKey(url) as? UIImage
            }
            
            cell.configureCell(post, image: img)
            return cell
        }else{
            return PostCell()
        }
        
        
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        
        let post = posts[indexPath.row]
        if(post.imageUrl == nil){
            return 200;
        }else{
            return tableView.estimatedRowHeight
        }
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        
    
        imageSelected = true
        imagePicker.dismissViewControllerAnimated(true, completion: nil)
        selectImage.image = image
    }
    
   
    @IBAction func makePost(sender: AnyObject) {
        if let text = postTextField.text where text != "" {
            //uplaod to the text to firebase and create a post
            postToFireBase()
           
//            let imageData = UIImageJPEGRepresentation(selectImage.image!, 0.2)!
            
            //convert uiimage to
            let documentsURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
            if let image = UIImage(data: UIImagePNGRepresentation(selectImage.image!)!) {
                let fileURL = documentsURL.URLByAppendingPathComponent("temp.png")
                if let pngImageData = UIImagePNGRepresentation(image) {
                    pngImageData.writeToURL(fileURL, atomically: false)
                }
                let uploadRequest = AWSS3TransferManagerUploadRequest()
                uploadRequest.body = fileURL
                uploadRequest.key = NSProcessInfo.processInfo().globallyUniqueString + ".png"
                uploadRequest.bucket = S3BucketName
                uploadRequest.contentType = "image/png"
            
            
                let transferManager = AWSS3TransferManager.defaultS3TransferManager()
                transferManager.upload(uploadRequest).continueWithBlock { (task) -> AnyObject! in
                    if let error = task.error {
                        print("Upload failed ❌ (\(error))")
                    }
                    if let exception = task.exception {
                        print("Upload failed ❌ (\(exception))")
                    }
                    if task.result != nil {
                        let s3URL = NSURL(string: "http://s3.amazonaws.com/\(self.S3BucketName)/\(uploadRequest.key!)")!
                        print("Uploaded to:\n\(s3URL)")
                    }
                    else {
                        print("Unexpected empty result.")
                    }
                    return nil
                }
            }
            
            
            
            
            
//            if let image = selectImage.image {
//                let urlStr = "amazon url"
//                let url = NSURL(string: urlStr)!
//                let imgData = UIImageJPEGRepresentation(image, 0.2)!
//                let keyData = "AMAZON KEY".dataUsingEncoding(NSUTF8StringEncoding)!
//                //sending a request with alamo fire we need to convert everything to NSDATA
//                let keyJSON = "json".dataUsingEncoding(NSUTF8StringEncoding)!
//                
//                Alamofire.upload(.POST,url, multipartFormData: { multipartFormData in
//                    
//                    multipartFormData.appendBodyPart(data: imgData, name: "fileUpload", fileName: "image", mimeType:"image/jpg")
//                    multipartFormData.appendBodyPart(data: keyData, name: "key")
//                    multipartFormData.appendBodyPart(data: keyJSON, name: "format")
//                    
//                
//                }) { encodingResult in
//                    switch encodingResult {
//                        case .Success(let upload, _, _):
//                            
//                            upload.responseJSON( completionHandler: { response in
//                                print(response)
//                              
//                            })
//                        case .Failure(let error):
//                            print(error)
//                        
//                    }
//                    
//                }
//            }
        }
    }
    
    @IBAction func takePicture(sender: AnyObject) {
        
        presentViewController(imagePicker, animated:true, completion: nil)
    }
    
    @IBAction func leftSideButtonTapped(sender: AnyObject){
       
        
    }
    
    @IBAction func showMagicWidget(sender: AnyObject){
        self.performSegueWithIdentifier("ShowMagicWidget", sender:nil)

    }
    
    
    @IBAction func LeftMenuButtonPressed(sender: UIButton) {
   
    sharedDelegate.centerContainer?.toggleDrawerSide(DrawerSide.Left, animated: true, completion: nil)
    }
    
    /*
     private var _postDescription: String!
     private var _imageUrl: String?
     //    private var _likes: Int!
     private var _username: String!
     private var _postKey: String!
     private var _spot: String!
     private var _profileImage: String!
     */

    
    
    //upload function to post to firebase
    func postToFireBase(){
        let user = NSUserDefaults.standardUserDefaults().objectForKey("user") as? Dictionary<String, AnyObject>
        
        let post: Dictionary<String, AnyObject> = [
            "description" : postTextField.text!,
            "username": user!["firstName"]!,
            "spot" : self.spot.spotName,
            "profileImage": user!["picURL"]!,
            "timeStamp": String(NSDate().timeIntervalSince1970)
        ]
        
    
        let fireBasePost = DataService.ds.REF_POSTS.childByAutoId()
        fireBasePost.setValue(post)
        
        postTextField.text = ""
//        selectImage.image = UIImage(named : "images.png")
//        imageSelected = false
        tableView.reloadData()
    }
}
