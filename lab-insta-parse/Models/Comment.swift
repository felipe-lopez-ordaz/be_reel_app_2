//
//  Comment.swift
//  lab-insta-parse
//
//  Created by Felipe Lopez on 3/1/26.
//

import Foundation
import ParseSwift

struct Comment:  ParseObject{
    
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?
    
    var text: String?
    var user: User?
    var post: Post?
    
}
