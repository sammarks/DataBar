//
//  Account.swift
//  DataBar
//
//  Created by Sam Marks on 1/22/23.
//

import Foundation

struct Account: Decodable {
  let name: String
  let displayName: String
}

struct AccountsResponse: Decodable {
  let accounts: [Account]
}
