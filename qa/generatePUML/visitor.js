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
        const callee = this.visitIdentifier(node.callee)
        const _arguments = this.evalArgs(node.arguments)
        if (callee == "print")
            l(..._arguments)
    }
    visitNodes(nodes) {
        for (const node of nodes) {
            this.visitNode(node)
        }
    }
    visitClassDeclaration(node) {
        if (node.superClass.name == "Interface")
            this.l("interface " + node.id.name);
        else if ([ "DefaultView", "UcpView", "UcpComponent"].includes(node.superClass.name))
            this.l("class " + node.id.name + "(" + node.superClass.name + ")");
        else {
            this.l("class " + node.id.name);
            this.l(node.id.name + " -> " + node.superClass.name)
        }
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
        }
    }
    run(nodes) {
        return this.visitNodes(nodes)
    }
}
module.exports = Visitor