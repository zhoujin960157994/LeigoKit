import Foundation
import Yaml

struct RuleParser {
    static func parseRuleManager(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> RuleManager {
        guard let ruleConfigs = config.array else {
            throw ConfigurationParserError.noRuleDefined
        }
        
        var rules: [Rule] = []
        
        for ruleConfig in ruleConfigs {
            rules.append(try parseRule(ruleConfig, adapterFactoryManager: adapterFactoryManager))
        }
        return RuleManager(fromRules: rules, appendDirect: true)
    }
    
    static func parseRule(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> Rule {
        guard let type = config["type"].string?.lowercased() else {
            throw ConfigurationParserError.ruleTypeMissing
        }
        
        switch type {
        case "country":
            return try parseCountryRule(config, adapterFactoryManager: adapterFactoryManager)
        case "all":
            return try parseAllRule(config, adapterFactoryManager: adapterFactoryManager)
        case "list", "domainlist":
            return try parseDomainListRule(config, adapterFactoryManager: adapterFactoryManager)
        case "iplist":
            return try parseIPRangeListRule(config, adapterFactoryManager: adapterFactoryManager)
        case "dnsfail":
            return try parseDNSFailRule(config, adapterFactoryManager: adapterFactoryManager)
        default:
            throw ConfigurationParserError.unknownRuleType
        }
    }
    
    static func parseCountryRule(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> CountryRule {
        guard let country = config["country"].string else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Country code (country) is required for country rule.")
        }
        
        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }
        
        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Unknown adapter id.")
        }
        
        guard let match = config["match"].bool else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "You have to specify whether to apply this rule to ip match the given country or not with \"match\".")
        }
        
        return CountryRule(countryCode: country, match: match, adapterFactory: adapter)
    }
    
    static func parseAllRule(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> AllRule {
        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }
        
        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Unknown adapter id.")
        }
        
        return AllRule(adapterFactory: adapter)
    }
    
    static func parseDomainListRule(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> DomainListRule {
        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }
        
        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Unknown adapter id.")
        }
        
        //        guard var filepath = config["file"].stringOrIntString else {
        //            throw ConfigurationParserError.ruleParsingError(errorInfo: "Must provide a file (file) containing domain rules in list.")
        //        }
        //
        //        filepath = (filepath as NSString).expandingTildeInPath
        
        do {
            var criteria: [DomainListRule.MatchCriterion] = []
            if var filepath = config["file"].stringOrIntString {
                filepath = (filepath as NSString).expandingTildeInPath
                let content = try String(contentsOfFile: filepath)
                let regexs = content.components(separatedBy: CharacterSet.newlines)
                for regex in regexs {
                    if !regex.isEmpty {
                        if let re = try? NSRegularExpression(pattern: regex, options: .caseInsensitive){
                            criteria.append(DomainListRule.MatchCriterion.regex(re))
                        }
                    }
                }
            }else {
                for dom in config["criteria"].array!{
                    let raw_dom = dom.string!
                    let index = raw_dom.index(raw_dom.startIndex, offsetBy: 1)
                    let index2 = raw_dom.index(raw_dom.startIndex, offsetBy: 2)
                    let typeStr = raw_dom.substring(to: index)
                    let url = raw_dom.substring(from: index2)
                    
                    if typeStr == "s"{
                        criteria.append(DomainListRule.MatchCriterion.suffix(url))
                    }else if typeStr == "k"{
                        criteria.append(DomainListRule.MatchCriterion.keyword(url))
                    }else if typeStr == "p"{
                        criteria.append(DomainListRule.MatchCriterion.prefix(url))
                    }else if typeStr == "r"{
                        
                        if let regex = try? NSRegularExpression(pattern:url, options: .caseInsensitive){
                            criteria.append(DomainListRule.MatchCriterion.regex(regex))
                        }
                        
                        
                    }
                    
                }
            }
            
            return DomainListRule(adapterFactory: adapter, criteria: criteria)
        } catch let error {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Encounter error when parse rule list file. \(error)")
        }
    }
    
    static func parseIPRangeListRule(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> IPRangeListRule {
        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }
        
        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Unknown adapter id.")
        }
        
        //        guard var filepath = config["file"].stringOrIntString else {
        //            throw ConfigurationParserError.ruleParsingError(errorInfo: "Must provide a file (file) containing IP range rules in list.")
        //        }
        //
        //        filepath = (filepath as NSString).expandingTildeInPath
        
        do {
            var ranges:[String] = []
            if var filepath = config["file"].stringOrIntString {
                filepath = (filepath as NSString).expandingTildeInPath
                let content = try String(contentsOfFile: filepath)
                var ranges = content.components(separatedBy: CharacterSet.newlines)
                ranges = ranges.filter {
                    !$0.isEmpty
                }
            }else {
                ranges = config["criteria"].array!.map{$0.string!}
            }
            return try IPRangeListRule(adapterFactory: adapter, ranges: ranges)
        } catch let error {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Encounter error when parse IP range rule list file. \(error)")
        }
    }
    
    static func parseDNSFailRule(_ config: Yaml, adapterFactoryManager: AdapterFactoryManager) throws -> DNSFailRule {
        guard let adapter_id = config["adapter"].stringOrIntString else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "An adapter id (adapter_id) is required.")
        }
        
        guard let adapter = adapterFactoryManager[adapter_id] else {
            throw ConfigurationParserError.ruleParsingError(errorInfo: "Unknown adapter id.")
        }
        
        return DNSFailRule(adapterFactory: adapter)
    }
}

