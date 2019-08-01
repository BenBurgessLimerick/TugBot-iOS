//
//  CompressedImageMessage.swift
//
//  Created by Ben Burgess-Limerick on 15/5/19.
//

import UIKit
import ObjectMapper
//import RBSManager

public class CompressedImageMessage: RBSMessage {
    public var header: HeaderMessage?
    public var format: String?
    public var data: [UInt8]?
    
    public override init() {
        super.init()
        format = ""
        header = HeaderMessage()
        data = [UInt8]()
    }
    public required init?(map: Map) {
        super.init(map: map)
    }
    
    
    public override func mapping(map: Map) {
//        print (map["data"].value()!)
        header <- map["header"]
        format <- map["format"]
//        let dataString = map["data"].value()
        print ("Here")
        do {
            try print( (map.value("data") is String) as Any)
        }catch {
            print("err")
            
        }
        print("Now here")
        
//        data = Data(base64Encoded: (map["data"].value()!))!
        //data <- map["data"]
    }
}
