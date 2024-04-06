import express from 'express'
import fs from 'fs'

const router = express.Router()
var writable = fs.createWriteStream('pipe')

router.get('/', (req, res) => {
  res.json({ status: 'ok' })
})

router.post('/nixosConfig', (req, res) => {
  const homestakerConfig = req.body
  const hostname = homestakerConfig.localization.hostname
  writable.write(`echo '${JSON.stringify(homestakerConfig)}' | nix run .#buidl -- -n '${hostname}' -b homestakeros\n`)
  res.json({ status: 'ok' })
})

export default router
