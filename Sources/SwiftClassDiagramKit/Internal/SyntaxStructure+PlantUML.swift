import Foundation

extension SyntaxStructure {
    /// 命中规则的元素选项（未命中任何规则时回退全局配置）
    fileprivate func elementsOptions(fallback configuration: Configuration) -> ElementOptions {
        effectiveResolvedRule?.elements ?? configuration.elements
    }

    /// textual representation of Element in PlantUML scripting
    func plantuml(context: PlantUMLContext) -> String? {
        guard let kind = kind else { return nil }

        guard skip(element: self, basedOn: context.configuration) == false else { return nil }

        let elements = elementsOptions(fallback: context.configuration)

        var generics: String?
        if elements.showGenerics {
            generics = genericsStatement()
        }

        var textualRepresentation = ""
        // swiftlint:disable line_length
        switch kind {
        case ElementKind.class:
            textualRepresentation = "class \"\(displayName!)\" as \(context.uniqName(item: self, relationship: "inherits"))\(generics ?? "") { \(members(context: context)) \n}"
        case ElementKind.struct:
            textualRepresentation = "class \"\(displayName!)\" as \(context.uniqName(item: self, relationship: "inherits"))\(generics ?? "") { \(members(context: context)) \n}"
        case ElementKind.extension:
            textualRepresentation = "class \"\(displayName!)\" as \(context.uniqName(item: self, relationship: "ext"))\(generics ?? "") { \(members(context: context)) \n}"
        case ElementKind.enum:
            textualRepresentation = "class \"\(displayName!)\" as \(context.uniqName(item: self, relationship: ""))\(generics ?? "") { \(members(context: context)) \n}"
        case ElementKind.protocol:
            textualRepresentation = "class \"\(displayName!)\" as \(context.uniqName(item: self, relationship: "conforms to"))\(generics ?? "") { \(members(context: context)) \n}"
        default:
            Logger.shared.error("not supported")
            return nil
        }
        // swiftlint:enable line_length
        addLinking(context: context)
        return textualRepresentation
    }

    private func addLinking(context: PlantUMLContext) {
        if inheritedTypes != nil, inheritedTypes!.count > 0 {
            inheritedTypes!.forEach { parent in
                if parent.name?.contains("&") == true {
                    parent.name?
                        .components(separatedBy: "&")
                        .forEach {
                            let name = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                            context.addLinking(item: self, parent: SyntaxStructure(name: name))
                        }
                } else {
                    context.addLinking(item: self, parent: parent)
                }
            }
        }
    }

    private func members(context: PlantUMLContext) -> String {
        var members = ""

        guard let substructure = substructure, substructure.count > 0 else { return members }

        for sub in substructure {
            if let msig = member(element: sub, context: context) {
                members.appendAsNewLine(msig)
            }
        }

        return members
    }

    private func member(element: SyntaxStructure, context: PlantUMLContext) -> String? {
        guard
            element.kind == ElementKind.functionMethodInstance ||
            element.kind == ElementKind.functionMethodStatic ||
            element.kind == ElementKind.varInstance ||
            element.kind == ElementKind.varStatic ||
            element.kind == ElementKind.enumcase else { return nil }

        let actualElement: SyntaxStructure!
        if element.kind == ElementKind.enumcase {
            actualElement = element.substructure?.first!
        } else {
            actualElement = element
        }

        let elements = elementsOptions(fallback: context.configuration)

        if kind! != .extension {
            let generateMembersWithAccessLevel: [ElementAccessibility] = elements.showMembersWithAccessLevel.allowed.map { ElementAccessibility(orig: $0)! }
            if generateMembersWithAccessLevel.contains(actualElement.accessibility ?? ElementAccessibility.internal) == false {
                return nil
            }
        }

        var msig = "  "

        msig += memberName(of: actualElement)

        if let memberSuffix = actualElement.memberSuffix {
            msig += " " + memberSuffix
        }

        return msig
    }

    private func memberName(of element: SyntaxStructure) -> String {
        let kind = element.kind!
        let rawName: String
        switch kind {
        case .functionMethodInstance:
            rawName = "\(element.name!)"
        case .functionMethodStatic:
            rawName = "{static} \(element.name!)"
        case .varInstance:
            if element.typename != nil {
                rawName = "\(element.name!) : \(element.typename!)"
            } else {
                rawName = "\(element.name!)"
            }
        case .varStatic:
            if element.typename != nil {
                rawName = "{static} \(element.name!) : \(element.typename!)"
            } else {
                rawName = "{static} \(element.name!)"
            }
        case .enumelement:
            rawName = "\(element.name!)"
        default:
            rawName = ""
        }
        // 多行签名（如多行函数声明）会被 SourceKit 放入 key.name，必须折叠为单行，
        // 否则破坏 PlantUML 单行成员结构（见 String.collapsingNewlines）。
        return rawName.collapsingNewlines()
    }

    private func skip(element: SyntaxStructure, basedOn configuration: Configuration) -> Bool {
        let elements = elementsOptions(fallback: configuration)
        guard skip(element: self, basedOn: elements.exclude) == false else { return true }

        guard let elementKind = element.kind else { return true }

        if elementKind != .extension {
            let generateElementsWithAccessLevel: [ElementAccessibility] = elements.havingAccessLevel.allowed.map { ElementAccessibility(orig: $0)! }
            guard generateElementsWithAccessLevel.contains(accessibility ?? ElementAccessibility.internal) else { return true }
        }

        if elements.showExtensions == false, kind == .extension {
            return true
        }

        return false
    }

    private func skip(element: SyntaxStructure, basedOn excludeElements: [String]?) -> Bool {
        guard let elementName = element.name else { return false }
        guard let excludedElements = excludeElements else { return false }
        return !excludedElements.filter { elementName.isMatching(searchPattern: $0) }.isEmpty
    }

    private func genericsStatement() -> String? {
        guard let substructure = substructure else {
            guard let parent = inheritedTypes?.first else { return nil }
            return parent.name?.getAngleBracketsWithContent()
        }
        let params = substructure.filter { $0.kind == ElementKind.genericTypeParam }
        var genParts: [String] = []
        for param in params {
            guard let name = param.name else { continue }
            if let typeName = param.inheritedTypes?[0].name {
                genParts.append("\(name): \(typeName)")
            } else {
                genParts.append("\(name)")
            }
        }
        let genStatemnet = genParts.joined(separator: "\\n")
        guard genStatemnet.count > 0 else { return nil }
        return "<\(genStatemnet)>"
    }
}
