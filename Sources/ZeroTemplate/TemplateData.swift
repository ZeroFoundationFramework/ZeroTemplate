//
//  TemplateData.swift
//  zero_proj
//
//  Created by Philipp Kotte on 30.06.25.
//


import Foundation

public enum TemplateData {
    case string(String)
    case array([TemplateData])
    case dictionary([String: TemplateData])

    public init?(_ value: Any) {
        if let str = value as? String { self = .string(str) }
        else if let arr = value as? [Any] { self = .array(arr.compactMap { TemplateData($0) }) }
        else if let dict = value as? [String: Any] { self = .dictionary(dict.compactMapValues { TemplateData($0) }) }
        else { return nil }
    }

    func value(for keyPath: String) -> TemplateData? {
        var current: TemplateData? = self
        for part in keyPath.split(separator: ".") {
            guard let dict = current?.dictionaryValue else { return nil }
            current = dict[String(part)]
        }
        return current
    }

    var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    var arrayValue: [TemplateData]? { if case .array(let a) = self { return a }; return nil }
    var dictionaryValue: [String: TemplateData]? { if case .dictionary(let d) = self { return d }; return nil }
}
