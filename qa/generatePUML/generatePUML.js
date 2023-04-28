#!/usr/bin/node

const acorn = require('acorn')
const fs = require('fs')
const path = require('path');
const { fileURLToPath } = require('url');
const util = require('util');

const Interpreter = require("./interpreter.js")
const Visitor = require("./visitor.js")

var buffer = ""

// Define the directory path as a command line argument
const directoryPath = process.argv[2];
console.log("Path: "+directoryPath);

function filter(filePath) {
    // TODO: This must be fixed by filtering multiple versions of the same class
    return !filePath.includes("Metaverse/1.0.0")
}

// Collect all js files
function searchDirectoryForJsFiles(directoryPath) {
    files = fs.readdirSync(directoryPath);

    // Iterate over each file or directory in the current directory
    files.forEach(file => {
        const filePath = path.join(directoryPath, file);

        // Check if the current file is a directory
        if (fs.statSync(filePath).isDirectory()) {
            // If it is a directory, recursively search for .js files inside it
            searchDirectoryForJsFiles(filePath);
        } else if (path.extname(filePath) === '.js') {
            // If it is a .js file, print its name to the console
            if (filter(filePath)) {
                console.log(filePath)
                str = fs.readFileSync(filePath).toString();
                // replace some line which cause error in acorn
                // TODO: needs to be fixed in acorn
                str = str.replace('static transientMode =', '//static transientMode =')
                buffer += str;
            }
        }
    });
}

// Start the search in the specified directory
searchDirectoryForJsFiles(directoryPath);

// Write buffer into _test.js
console.log("buffer len : " + buffer.length.toString())
fs.writeFile("_test.js", buffer, function(err) {
    if (err) {
        console.log(err);
    }
});

// Parse js
const body = acorn.parse(buffer, {ecmaVersion: 2020}).body

// Write json tree
fs.writeFile("_test.json", JSON.stringify(body, null, 4), function(err) {
    if (err) {
        console.log(err);
    }
});

// log to PUML file
var log_file = fs.createWriteStream(__dirname + '/_test.puml', {flags : 'w'});
var log_stdout = process.stdout;
console.log = function(d) { //
  log_file.write(util.format(d) + '\n');
  //log_stdout.write(util.format(d) + '\n');
}
console.log("@startuml")
const jsInterpreter = new Interpreter(new Visitor(console.log))
jsInterpreter.interpret(body)
console.log("@enduml")
