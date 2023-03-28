const ops = {
    ADD: '+',
    SUB: '-',
    MUL: '*',
    DIV: '/'
}
let globalScope = new Map()
class Visitor {
    constructor(l) {
        this.l = l
        this.staticState = true
        this.methodMap = new Map()
    }
    visitVariableDeclaration(node) {
        const nodeKind = node.kind
        return this.visitNodes(node.declarations)
    }
    visitVariableDeclarator(node) {
        const id = this.visitNode(node.id)
        const init = this.visitNode(node.init)
        globalScope.set(id, init)
        return init
    }
    visitIdentifier(node) {
        const name = node.name
        if (globalScope.get(name))
            return globalScope.get(name)
        else
            return name
    }
    visitLiteral(node) {
        return node.raw
    }
    visitBinaryExpression(node) {
        const leftNode = this.visitNode(node.left)
        const operator = node.operator
        const rightNode = this.visitNode(node.right)
        switch (operator) {
            case ops.ADD:
                return leftNode + rightNode
            case ops.SUB:
                return leftNode - rightNode
            case ops.DIV:
                return leftNode / rightNode
            case ops.MUL:
                return leftNode * rightNode
        }
    }
    evalArgs(nodeArgs) {
        let g = []
        for (const nodeArg of nodeArgs) {
            g.push(this.visitNode(nodeArg))
        }
        return g
    }
    visitCallExpression(node) {
        this.l("package " + node.arguments[0].value + " {");
        const callee = this.visitIdentifier(node.callee)
        const _arguments = this.evalArgs(node.arguments)
        if (callee == "print")
            l(..._arguments)
        this.l("}");
    }
    visitNodes(nodes) {
        for (const node of nodes) {
            this.visitNode(node)
        }
    }
    visitClassDeclaration(node) {
        let name = node.id.name
        if (this.methodMap.get(name))
            name = name + "_DUPLICATE"
        this.methodMap.set(name,true)
        if (node.superClass.name == "Interface")
            this.l("interface " + name + " {");
        else if ([ "DefaultView", "UcpView", "UcpComponent"].includes(node.superClass.name)) {
            this.l("class " + name + " {");
            this.l("... is a " + node.superClass.name);
        } else {
            this.l(name + " -> " + node.superClass.name)
            this.l("class " + name + " {");
        }
        this.staticState = true
        this.evalArgs(node.body.body)
        this.l("}");
    }
    visitMethodDefinition(node) {
        let st = ""
        if (node.static) {
            if (!this.staticState) {
                this.staticState = true
                this.l("==");
            }
            st = " (static)"
        } else {
            if (this.staticState) {
                this.staticState = false
                this.l("==");
            }
        }
        let gs = ""
        if (node.kind == "get" || node.kind == "set")
            gs = node.kind + " "
        this.l("+" + gs + node.key.name + "() " + st);
        return node.raw
    }
    visitNode(node) {
        switch (node.type) {
            case 'ClassExpression':
                return this.visitClassDeclaration(node)
            case 'VariableDeclaration':
                return this.visitVariableDeclaration(node)
            case 'VariableDeclarator':
                return this.visitVariableDeclarator(node)
            case 'Literal':
                return this.visitLiteral(node)
            case 'Identifier':
                return this.visitIdentifier(node)
            case 'BinaryExpression':
                return this.visitBinaryExpression(node)
            case "CallExpression":
                return this.visitCallExpression(node)
            case "MethodDefinition":
                return this.visitMethodDefinition(node)
        }
    }
    run(nodes) {
        return this.visitNodes(nodes)
    }
}
module.exports = Visitor