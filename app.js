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
    console.log(req.body)

    let config = {};
    let host = {
        services: {
            ethereum: {
                clients: {},
            },
        },
    };

    host.name = req.body.hostname;
    host.user = "core"
    host.shell = "bash"
    host.timezone = "Europe/Helsinki"

    let home_manager = {}
    home_manager.enable = true
    home_manager.version = "23.05"
    home_manager.programs = ["vim", "git"]
    host.home_manager = home_manager

    let openssh = {}
    openssh.enable = true
    openssh.permit_root_login = false
    openssh.password_auth = false
    openssh.public_keys = [req.body.ssh]
    host.services.ssh = openssh

    let erigon = {};
    erigon.enable = true
    erigon.data_dir = ""
    erigon.infra_ip = ""
    erigon.authrpc_hosts = []
    erigon.authrpc_addr = ""

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
