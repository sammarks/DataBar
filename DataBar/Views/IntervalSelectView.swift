//
//  IntervalSelectView.swift
//  DataBar
//
//  Created by Sam Marks on 1/24/23.
//

import SwiftUI

struct IntervalSelectView: View {
  @AppStorage("intervalSeconds") private var interval: Int = 30
  
  var body: some View {
    Picker("Refresh Interval", selection: $interval) {
      Text("30 seconds").tag(30)
      Text("1 minute").tag(60)
      Text("2 minutes").tag(120)
      Text("5 minutes").tag(60 * 5)
      Text("10 minutes").tag(600)
      Text("20 minutes").tag(1200)
      Text("30 minutes").tag(60 * 30)
    }
  }
}
