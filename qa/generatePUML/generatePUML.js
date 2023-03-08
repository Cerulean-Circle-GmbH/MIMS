#!/usr/bin/node

//console.log("Hello, world!");

//let acorn = require("acorn");
//console.log(acorn.parse("console.log('Hello, world!')", {ecmaVersion: 2020}));

// src/index.js
const l = console.log
const acorn = require('acorn')
const Interpreter = require("./interpreter.js")
const Visitor = require("./visitor.js")
const fs = require('fs')
const path = require('path');
buffer = ""

// Define the directory path as a command line argument
const directoryPath = process.argv[2];
console.log("Path: "+directoryPath);

function searchDirectoryForJsFiles(directoryPath) {
    fs.readdir(directoryPath, (err, files) => {
      if (err) {
        console.log(`An error occurred while reading the directory: ${err}`);
        return;
      }
  
      // Iterate over each file or directory in the current directory
      files.forEach(file => {
        const filePath = path.join(directoryPath, file);
  
        // Check if the current file is a directory
        if (fs.statSync(filePath).isDirectory()) {
          // If it is a directory, recursively search for .js files inside it
          searchDirectoryForJsFiles(filePath);
        } else if (path.extname(filePath) === '.js') {
          // If it is a .js file, print its name to the console
          buffer += fs.readFileSync(filePath).toString();
          console.log(buffer.length.toString() + ":" + filePath);
        }
      });
    });
  }

// Start the search in the specified directory
searchDirectoryForJsFiles(directoryPath);

// Nicht 5 sekunden warten, sondern auf das ergebnisse der Suche
setTimeout(function() {
    console.log("buffer len : " + buffer.length.toString())
    fs.writeFile("_test.js", buffer, function(err) {
        if (err) {
            console.log(err);
        }
    });
}, 1000);

setTimeout(function() {
    const jsInterpreter = new Interpreter(new Visitor())
    const body = acorn.parse(buffer, {ecmaVersion: 2020}).body
    //l(body)
    fs.writeFile("_test.json", JSON.stringify(body, null, 4), function(err) {
        if (err) {
            console.log(err);
        }
    });
    console.log("@startuml")
    jsInterpreter.interpret(body)
    console.log("@enduml")
}, 2000);