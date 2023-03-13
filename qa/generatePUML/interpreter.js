class Interpreter {
    constructor(visitor) {
        this.visitor = visitor
    }
    interpret(nodes) {
        return this.visitor.run(nodes)
    }
}
module.exports = Interpreter