#!/usr/bin/env node
import express from "express";
import cors from "cors";
import fs from 'fs'

const app = express();
const router = express.Router()
const writable = fs.createWriteStream('pipe')

app.use(express.json());
app.use(cors());
app.use("/api", apiRouter);

router.get('/', (req, res) => {
  res.json({ status: 'ok' })
})

router.post('/nixosConfig', (req, res) => {
  const homestakerConfig = req.body
  const hostname = homestakerConfig.localization.hostname
  writable.write(`echo '${JSON.stringify(homestakerConfig)}' | nix run .#buidl -- -n '${hostname}' -b homestakeros\n`)
  res.json({ status: 'ok' })
})

app.listen(8081);
