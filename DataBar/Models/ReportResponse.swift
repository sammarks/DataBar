//
//  ReportResponse.swift
//  DataBar
//
//  Created by Sam Marks on 1/23/23.
//

import Foundation

struct DimensionRequest: Encodable {
  let name: String
}
struct MetricRequest: Encodable {
  let name: String
}

struct ReportRequest: Encodable {
  let dimensions: [DimensionRequest]
  let metrics: [MetricRequest]
}

struct ReportResponse: Decodable {
  let dimensionHeaders: [DimensionHeader]?
  let metricHeaders: [MetricHeader]?
  let rows: [Row]?
  let rowCount: Int?
}

struct DimensionHeader: Decodable {
  let name: String
}

struct MetricHeader: Decodable {
  let name: String
  let type: String
}

struct Row: Decodable {
  let dimensionValues: [DimensionValue]?
  let metricValues: [MetricValue]
}

struct DimensionValue: Decodable {
  let value: String
}

struct MetricValue: Decodable {
  let value: String
}
