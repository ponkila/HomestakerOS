const express = require('express')
const {
    exec
} = require('node:child_process');
const app = express()
const port = 3000

app.use(express.json())
app.use(express.urlencoded({
    extended: true
}))

app.post('/', (req, res) => {
    console.log(req)
    console.log(req.body)

    let config = {};

    let host = {};
    host.name = req.body.hostname;

    config.hosts = [host];

    exec('./nixobolus/echo.sh', (error, stdout, stderr) => {
        if (error) {
            console.error(`exec error: ${error}`);
            return;
        }
        console.log(`stdout: ${stdout}`);
        console.error(`stderr: ${stderr}`);
    });

    res.json(config);
})

app.use(express.static('webui'))

app.listen(port)
