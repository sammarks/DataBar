//
//  Property.swift
//  DataBar
//
//  Created by Sam Marks on 1/22/23.
//

import Foundation

struct Property: Decodable, Identifiable {
  let name: String
  let displayName: String
  let parent: String
  let account: String
  let deleteTime: String?
  
  var id: String { name }
  let accountObj: Account?
  
  init(from: Property, withAccount: Account) {
    self.name = from.name
    self.displayName = from.displayName
    self.parent = from.parent
    self.account = from.account
    self.deleteTime = from.deleteTime
    self.accountObj = withAccount
  }
}

struct PropertiesResponse: Decodable {
  let properties: [Property]
}

/**
 {
   "name": string,
   "propertyType": enum (PropertyType),
   "createTime": string,
   "updateTime": string,
   "parent": string,
   "displayName": string,
   "industryCategory": enum (IndustryCategory),
   "timeZone": string,
   "currencyCode": string,
   "serviceLevel": enum (ServiceLevel),
   "deleteTime": string,
   "expireTime": string,
   "account": string
 }
 */
