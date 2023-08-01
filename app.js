#!/usr/bin/env node
const express = require('express')
const exec = require('node:child_process');
const app = express()
const port = 3000

app.use(express.json())
app.use(express.urlencoded({
    extended: true
}))

app.post('/', (req, res) => {
    console.log(req.body)
    exec("echo '" + JSON.stringify(config) + "' | ./nixobolus/build.sh -o webui/test", (error, stdout, stderr) => {
        if (error) {
            console.error(`exec error: ${error}`);
            return;
        }
        console.log(`stdout: ${stdout}`);
        console.error(`stderr: ${stderr}`);
        res.send('<a href="/test/' + host.name + '/initrd">initrd</a> </br> <a href="test/' + host.name + '/bzImage">bzImage</a> </br> <a href="test/' + host.name + '/kexec-boot">kexec-boot</a>');
    });
})

app.use(express.static('webui'))

app.listen(port)
