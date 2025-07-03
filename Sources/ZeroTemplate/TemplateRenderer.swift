import Foundation
import ZeroErrors

public typealias TemplateContext = [String: Any]

public final class TemplateRenderer {
    private let viewsDirectory: URL
    private var cache: [String: String] = [:]

    public init(viewsDirectory: URL) {
        self.viewsDirectory = viewsDirectory
        print("View Directory is: \(viewsDirectory)")
    }

    public func render(filename: String, context: TemplateContext) throws -> String {
        guard let templateData = TemplateData(context) else { throw TemplateError.invalidContext }
        
        let templateString = ""
        do {
            let templateString = try self.loadTemplate(named: filename)
        }catch{
            return try self.render(template: renderingError, with: TemplateData(["error": ["filename" : "\(filename)"]])!)
        }
        
        return try self.render(template: templateString, with: templateData)
        
    }

    private func loadTemplate(named filename: String) throws -> String {
        if let cached = cache[filename] { return cached }
        let fileURL = viewsDirectory.appendingPathComponent(filename)
        print("FileURL: \(fileURL)")
        let content = try String(contentsOf: fileURL)
        cache[filename] = content
        return content
    }

    private func render(template: String, with context: TemplateData) throws -> String {
        var output = template
        // Reihenfolge ist wichtig: Zuerst die spezifischeren Schleifen.
        output = try renderEachLoop(in: output, with: context)
        output = try renderForLoop(in: output, with: context)
        // Dann die einfachen Variablen.
        output = try renderVariables(in: output, with: context)
        return output
    }
    
    // Rendert die `#each`-Schleife für Arrays von Objekten
    private func renderEachLoop(in template: String, with context: TemplateData) throws -> String {
        let pattern = "\\{\\{\\#each (.*?)\\}\\}(.*?)\\{\\{\\#end_each\\}\\}"
        let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        var result = template
        let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count))

        for match in matches.reversed() {
            let keyPath = (result as NSString).substring(with: match.range(at: 1))
            let innerTemplate = (result as NSString).substring(with: match.range(at: 2))
            var renderedContent = ""
            
            if let arrayData = context.value(for: keyPath)?.arrayValue {
                for item in arrayData {
                    // Rendere den Block mit dem jeweiligen Objekt als Kontext
                    renderedContent += try renderVariables(in: innerTemplate, with: item)
                }
            }
            result.replaceSubrange(Range(match.range, in: result)!, with: renderedContent)
        }
        return result
    }
    
    // Rendert die `#for`-Schleife für einfache Arrays UND Zahlenbereiche
    private func renderForLoop(in template: String, with context: TemplateData) throws -> String {
        let pattern = "\\{\\{\\#for (.*?)\\}\\}(.*?)\\{\\{\\#end_for\\}\\}"
        let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        var result = template
        let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count))

        for match in matches.reversed() {
            let loopTarget = (result as NSString).substring(with: match.range(at: 1))
            let innerTemplate = (result as NSString).substring(with: match.range(at: 2))
            var renderedContent = ""
            
            // Prüfen, ob es sich um einen Zahlenbereich handelt (z.B. 1...5)
            var isRange = false
            var start: Int = 0
            var end: Int = 0
            if #available(macOS 13.0, *) {
                let rangeParts = loopTarget.split(separator: "...").map(String.init)
                if rangeParts.count == 2, let s = Int(rangeParts[0]), let e = Int(rangeParts[1]) {
                    isRange = true
                    start = s
                    end = e
                }
            } else {
                let rangeParts = loopTarget.components(separatedBy: "...")
                if rangeParts.count == 2, let s = Int(rangeParts[0]), let e = Int(rangeParts[1]) {
                    isRange = true
                    start = s
                    end = e
                }
            }
            if isRange {
                // Iteriere über den Zahlenbereich
                for i in start...end {
                    // Ersetze {{ index }} durch die aktuelle Zahl
                    renderedContent += innerTemplate.replacingOccurrences(of: "{{ index }}", with: String(i))
                }
            } else if let arrayData = context.value(for: loopTarget)?.arrayValue {
                // Ansonsten als Key-Path für ein Array behandeln
                for item in arrayData {
                    if let stringValue = item.stringValue {
                        // Ersetze {{ item }} durch den String-Wert
                        renderedContent += innerTemplate.replacingOccurrences(of: "{{ item }}", with: stringValue)
                    }
                }
            }
            
            result.replaceSubrange(Range(match.range, in: result)!, with: renderedContent)
        }
        return result
    }

    private func renderVariables(in template: String, with context: TemplateData) throws -> String {
        let regex = try NSRegularExpression(pattern: "\\{\\{\\s*(?!#)(.*?)\\s*\\}\\}") // Negative Lookahead `(?!#)` to ignore loop tags
        var result = template
        let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count))

        for match in matches.reversed() {
            let keyPath = (result as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            if let value = context.value(for: keyPath)?.stringValue {
                result.replaceSubrange(Range(match.range, in: result)!, with: value)
            }
        }
        return result
    }
}

